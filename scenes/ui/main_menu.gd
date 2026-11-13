extends Control

## Головне меню: "Грати" веде в місто, "Магазин" — геми, обмін і
## стартові набори. Героя, зброю й таланти гравець обирає не тут, а в
## місті — підходить до Зали героїв, Збройні чи Храму: у цьому й сенс
## будівель. Тут же — офлайн-золото (GameState.pending_offline_gold),
## скринька за таймером і налаштування.
##
## Посередині — банер "Rune Horde" і різьблена панель (арт гравця): хто
## й з чим піде в бій, зелена "Грати", під нею "Магазин" і "Скринька"
## картками з відсіком під іконку, найменшим рядом — графіка, FPS, автори.

const OFFLINE_REWARD_SCENE := preload("res://scenes/ui/offline_reward.tscn")
const CREDITS_SCRIPT := preload("res://scenes/ui/credits.gd")

const CHEST_MESSAGE_SEC := 3.0
## Тло меню: своє (поклади assets/ui/backgrounds/menu.jpg), інакше — зала.
const MENU_BACKGROUND := "res://assets/ui/backgrounds/menu.jpg"
const HALL_BACKGROUND := "res://assets/ui/backgrounds/hero_hall.jpg"

var _gold_badge: CurrencyBadge
var _gems_badge: CurrencyBadge
var _hero_label: Label
var _weapon_label: Label
var _hero_portrait: TextureRect
var _chest_button: Button
var _chest_hint: Label
var _chest_content: Control
var _graphics_button: Button
var _fps_button: Button

var _chest_refresh_timer := 0.0
var _chest_message_left := 0.0   # поки > 0, щосекундне оновлення не затирає повідомлення

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Тло — своє для меню (menu.jpg), поки його немає — зала героїв,
	# трохи притемнена, щоб панель меню була головною. Суцільний фон зі
	# сцени лягав би поверх картинки — він більше не потрібен.
	($Background as CanvasItem).visible = false
	UiTheme.add_background(self, [MENU_BACKGROUND, HALL_BACKGROUND], 0.35)

	# Золото й геми — у кутку поверх усього, як монети в грі.
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 20.0
	top_bar.offset_top = 16.0
	top_bar.offset_right = -20.0
	top_bar.add_theme_constant_override("separation", 10)
	add_child(top_bar)
	_gold_badge = CurrencyBadge.new(&"gold", 19)
	top_bar.add_child(_gold_badge)
	_gems_badge = CurrencyBadge.new(&"gem", 19)
	top_bar.add_child(_gems_badge)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(540, 0)
	stack.add_theme_constant_override("separation", 18)
	center.add_child(stack)
	stack.add_child(OrnateBanner.new("Rune Horde", 38))

	var panel := OrnatePanel.new()
	stack.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var subtitle := Label.new()
	subtitle.text = "Готуйся в місті — і вперед, у підземелля"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.86, 0.84, 0.94))
	column.add_child(subtitle)

	# Хто й з чим піде в бій — портрет героя, ім'я й зброя.
	var hero_row := HBoxContainer.new()
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_row.add_theme_constant_override("separation", 12)
	column.add_child(hero_row)
	_hero_portrait = TextureRect.new()
	_hero_portrait.custom_minimum_size = Vector2(60, 60)
	_hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero_portrait.material = UiTheme.rounded_art_material()
	hero_row.add_child(_hero_portrait)
	var hero_text := VBoxContainer.new()
	hero_text.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_text.add_theme_constant_override("separation", 0)
	hero_row.add_child(hero_text)
	_hero_label = Label.new()
	_hero_label.add_theme_font_override("font", UiTheme.font(900))
	_hero_label.add_theme_font_size_override("font_size", 21)
	_hero_label.add_theme_color_override("font_color", OrnateDialog.TITLE_COLOR)
	hero_text.add_child(_hero_label)
	_weapon_label = Label.new()
	_weapon_label.add_theme_font_size_override("font_size", 15)
	_weapon_label.add_theme_color_override("font_color", Color(0.86, 0.84, 0.94))
	hero_text.add_child(_weapon_label)

	var play := Button.new()
	play.text = "Грати"
	play.custom_minimum_size = Vector2(320, 64)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.add_theme_font_size_override("font_size", 28)
	UiTheme.art_primary(play)
	play.pressed.connect(_on_play_pressed)
	column.add_child(play)

	# Магазин і скринька — картками з відсіком під іконку, як товари на
	# Ринку: іконка в рамці, праворуч назва й підказка, що там.
	var shop_card := _make_menu_card(ArtSlots.menu_icon("shop"), "Магазин", "Геми, обмін і стартові набори")
	shop_card.button.pressed.connect(_on_shop_pressed)
	column.add_child(shop_card.button)
	var chest_card := _make_menu_card(ArtSlots.menu_icon("chest"), "Скринька", "")
	_chest_button = chest_card.button
	_chest_hint = chest_card.hint
	_chest_content = chest_card.content
	_chest_button.pressed.connect(_on_chest_pressed)
	column.add_child(_chest_button)

	var settings_row := HBoxContainer.new()
	settings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_row.add_theme_constant_override("separation", 10)
	column.add_child(settings_row)
	_graphics_button = _make_menu_button("", Vector2(190, 42), 14)
	_graphics_button.pressed.connect(_on_graphics_pressed)
	settings_row.add_child(_graphics_button)
	_fps_button = _make_menu_button("", Vector2(90, 42), 14)
	_fps_button.pressed.connect(_on_fps_pressed)
	settings_row.add_child(_fps_button)
	var credits_button := _make_menu_button("Автори", Vector2(100, 42), 14)
	credits_button.pressed.connect(_on_credits_pressed)
	settings_row.add_child(credits_button)

	_update_gold_label()
	_update_chest_button()
	_update_graphics_buttons()
	if GameState.pending_offline_gold > 0:
		_show_offline_reward()

func _process(delta: float) -> void:
	if _chest_message_left > 0.0:
		_chest_message_left -= delta
		return
	_chest_refresh_timer += delta
	if _chest_refresh_timer >= 1.0:
		_chest_refresh_timer = 0.0
		_update_chest_button()

func _update_gold_label() -> void:
	_gold_badge.set_amount(GameState.gold)
	_gems_badge.set_amount(GameState.gems)
	# Видно одразу, ким і чим підеш у бій — щоб не лізти в меню перевіряти.
	var hero := HeroPool.get_def(GameState.selected_hero_id)
	var weapon := WeaponPool.get_def(GameState.get_equipped_weapon_id(hero.id))
	_hero_label.text = hero.title
	_weapon_label.text = "Зброя: %s" % weapon.title
	_hero_portrait.texture = ArtSlots.hero_portrait(hero.id)
	_hero_portrait.visible = _hero_portrait.texture != null

## Синя кнопка з арту гравця, за потреби — з іконкою зліва від напису.
func _make_menu_button(text: String, min_size: Vector2, font_size: int, icon: Texture2D = null) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font_size)
	UiTheme.art_secondary(button)
	if icon != null:
		button.icon = icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 30)
	return button

## Кнопка-картка: компактна рамка з відсіком (UiTheme.item_card_small_box),
## іконка — у центрі відсіку, праворуч назва золотом і підказка під нею.
## Повертає {button, hint, content}: підказку меню змінює ("через 12 хв"),
## а вміст притемнює, поки кнопка вимкнена.
func _make_menu_card(icon: Texture2D, title: String, hint_text: String) -> Dictionary:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, UiTheme.ITEM_CARD_SMALL_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	var tints := {"normal": Color.WHITE, "hover": Color(1.15, 1.15, 1.22),
		"pressed": Color(0.82, 0.82, 0.86), "disabled": Color(0.62, 0.62, 0.66)}
	for state: String in tints:
		button.add_theme_stylebox_override(state, UiTheme.item_card_small_box(tints[state]))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var content := Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	if icon != null:
		var image := UiTheme.make_bare_icon(icon, UiTheme.ITEM_ICON_SMALL)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var half := UiTheme.ITEM_ICON_SMALL * 0.5
		image.position = Vector2(UiTheme.ITEM_SMALL_SLOT_CENTER - half, UiTheme.ITEM_CARD_SMALL_HEIGHT * 0.5 - half)
		image.size = Vector2.ONE * UiTheme.ITEM_ICON_SMALL
		content.add_child(image)
	var text := VBoxContainer.new()
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = UiTheme.ITEM_SMALL_TEXT_X
	text.offset_right = -18
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(text)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", UiTheme.font(900))
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", OrnateDialog.TITLE_COLOR)
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	title_label.add_theme_constant_override("outline_size", 4)
	text.add_child(title_label)
	var hint := Label.new()
	hint.text = hint_text
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.86, 0.84, 0.94))
	text.add_child(hint)
	return {"button": button, "hint": hint, "content": content}

func _update_chest_button() -> void:
	if GameState.is_chest_available():
		_chest_hint.text = "Нагорода за коротку рекламу"
		_chest_button.disabled = false
	else:
		var minutes_left := GameState.get_chest_seconds_left() / 60
		_chest_hint.text = "Знову відкриється через %d хв" % minutes_left
		_chest_button.disabled = true
	_chest_content.modulate = Color(1, 1, 1, 0.6) if _chest_button.disabled else Color.WHITE

func _show_offline_reward() -> void:
	var popup: Node = OFFLINE_REWARD_SCENE.instantiate()
	add_child(popup)
	popup.closed.connect(_update_gold_label)

## "Грати" веде на базу героя — звідти він сам піде в данж через портал.
func _on_play_pressed() -> void:
	SceneLoader.change_scene("res://scenes/world/haven/haven.tscn", "Прихисток")

func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")

func _on_chest_pressed() -> void:
	_chest_button.disabled = true
	_chest_content.modulate = Color(1, 1, 1, 0.6)
	AdsManager.show_rewarded_ad(_on_chest_ad_reward, _on_chest_ad_skipped)

func _on_chest_ad_reward() -> void:
	GameState.claim_chest_reward()
	_update_gold_label()
	_update_chest_button()

func _on_chest_ad_skipped() -> void:
	_chest_hint.text = "Нагороду не отримано"
	_chest_message_left = CHEST_MESSAGE_SEC

## Графіка по колу: Авто -> Низька -> Середня -> Висока -> Авто.
## "Авто" — гра сама підбирає якість під телефон і тримає кадри рівними.
func _on_graphics_pressed() -> void:
	if PerfSettings.auto_quality:
		PerfSettings.set_user_choice(PerfSettings.Quality.LOW)
	elif PerfSettings.quality < PerfSettings.Quality.HIGH:
		PerfSettings.set_user_choice(PerfSettings.quality + 1)
	else:
		PerfSettings.set_user_choice(-1)
	_update_graphics_buttons()

## Лічильник кадрів у кутку екрана — щоб перевірити на телефоні, як
## насправді йде гра.
func _on_fps_pressed() -> void:
	PerfSettings.set_show_fps(not PerfSettings.show_fps)
	_update_graphics_buttons()

## "Автори" — поруч із налаштуваннями. Для моделей під CC BY згадка
## автора в самій грі обов'язкова.
func _on_credits_pressed() -> void:
	add_child(CREDITS_SCRIPT.new())

func _update_graphics_buttons() -> void:
	if PerfSettings.auto_quality:
		_graphics_button.text = "Графіка: Авто (%s)" % PerfSettings.get_quality_title().to_lower()
	else:
		_graphics_button.text = "Графіка: %s" % PerfSettings.get_quality_title()
	_fps_button.text = "FPS: так" if PerfSettings.show_fps else "FPS: ні"
