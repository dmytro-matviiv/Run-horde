extends Control

## Головне меню: "Грати" веде в місто, "Магазин" — геми, обмін і
## стартові набори. Героя, зброю й таланти гравець обирає не тут, а в
## місті — підходить до Зали героїв, Збройні чи Храму: у цьому й сенс
## будівель. Тут же — офлайн-золото (GameState.pending_offline_gold),
## скринька за таймером і налаштування.
##
## Одна велика панель посередині, як діалог квесту в зразку Kenney:
## заголовок, підказка, хто в поході — і головна дія світлою кнопкою.
## Магазин і скринька — трохи менші кнопки поруч; графіка, FPS, автори —
## ще менший ряд знизу, як другорядні пункти в зразку.

const OFFLINE_REWARD_SCENE := preload("res://scenes/ui/offline_reward.tscn")
const CREDITS_SCRIPT := preload("res://scenes/ui/credits.gd")

const CHEST_MESSAGE_SEC := 3.0

var _gold_badge: CurrencyBadge
var _gems_badge: CurrencyBadge
var _hero_label: Label
var _chest_button: Button
var _graphics_button: Button
var _fps_button: Button

var _chest_refresh_timer := 0.0
var _chest_message_left := 0.0   # поки > 0, щосекундне оновлення не затирає повідомлення

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.078)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

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
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box())
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	var title := Label.new()
	title.text = "Rune Horde"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 50)
	title.add_theme_color_override("font_color", UiTheme.TEXT)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Готуйся в місті — і вперед, у підземелля"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	column.add_child(subtitle)

	_hero_label = Label.new()
	_hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_label.add_theme_font_size_override("font_size", 18)
	_hero_label.add_theme_color_override("font_color", UiTheme.HEADING)
	column.add_child(_hero_label)

	var play_gap := Control.new()
	play_gap.custom_minimum_size = Vector2(0, 14)
	column.add_child(play_gap)

	var play := Button.new()
	play.text = "Грати"
	play.custom_minimum_size = Vector2(0, 66)
	play.add_theme_font_size_override("font_size", 28)
	UiTheme.make_primary(play)
	play.pressed.connect(_on_play_pressed)
	column.add_child(play)

	var action_gap := Control.new()
	action_gap.custom_minimum_size = Vector2(0, 10)
	column.add_child(action_gap)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	column.add_child(action_row)

	var shop_button := Button.new()
	shop_button.text = "Магазин"
	shop_button.custom_minimum_size = Vector2(150, 54)
	shop_button.add_theme_font_size_override("font_size", 18)
	var shop_icon := ArtSlots.menu_icon("shop")
	if shop_icon != null:
		shop_button.icon = shop_icon
		shop_button.expand_icon = true
	shop_button.pressed.connect(_on_shop_pressed)
	action_row.add_child(shop_button)

	_chest_button = Button.new()
	_chest_button.custom_minimum_size = Vector2(190, 54)
	_chest_button.add_theme_font_size_override("font_size", 16)
	var chest_icon := ArtSlots.menu_icon("chest")
	if chest_icon != null:
		_chest_button.icon = chest_icon
		_chest_button.expand_icon = true
	_chest_button.pressed.connect(_on_chest_pressed)
	action_row.add_child(_chest_button)

	var divider_gap := Control.new()
	divider_gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(divider_gap)

	var settings_row := HBoxContainer.new()
	settings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_row.add_theme_constant_override("separation", 10)
	column.add_child(settings_row)

	_graphics_button = Button.new()
	_graphics_button.custom_minimum_size = Vector2(180, 42)
	_graphics_button.add_theme_font_size_override("font_size", 14)
	_graphics_button.pressed.connect(_on_graphics_pressed)
	settings_row.add_child(_graphics_button)

	_fps_button = Button.new()
	_fps_button.custom_minimum_size = Vector2(84, 42)
	_fps_button.add_theme_font_size_override("font_size", 14)
	_fps_button.pressed.connect(_on_fps_pressed)
	settings_row.add_child(_fps_button)

	var credits_button := Button.new()
	credits_button.text = "Автори"
	credits_button.custom_minimum_size = Vector2(100, 42)
	credits_button.add_theme_font_size_override("font_size", 14)
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
	_hero_label.text = "%s  •  %s" % [hero.title, weapon.title]

func _update_chest_button() -> void:
	if GameState.is_chest_available():
		_chest_button.text = "Скринька (реклама)"
		_chest_button.disabled = false
	else:
		var minutes_left := GameState.get_chest_seconds_left() / 60
		_chest_button.text = "Скринька через %d хв" % minutes_left
		_chest_button.disabled = true

func _show_offline_reward() -> void:
	var popup: Node = OFFLINE_REWARD_SCENE.instantiate()
	add_child(popup)
	popup.closed.connect(_update_gold_label)

## "Грати" веде на базу героя — звідти він сам піде в данж через портал.
func _on_play_pressed() -> void:
	SceneLoader.change_scene("res://scenes/world/base_island.tscn", "База")

func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")

func _on_chest_pressed() -> void:
	_chest_button.disabled = true
	AdsManager.show_rewarded_ad(_on_chest_ad_reward, _on_chest_ad_skipped)

func _on_chest_ad_reward() -> void:
	GameState.claim_chest_reward()
	_update_gold_label()
	_update_chest_button()

func _on_chest_ad_skipped() -> void:
	_chest_button.text = "Нагороду не отримано"
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
