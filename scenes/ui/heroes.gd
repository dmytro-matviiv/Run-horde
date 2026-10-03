extends Control

## Зала героїв — та сама вітрина, що й зброя: гортаєш геройв іконками
## (ряд слотів), а не стрілками "вперед-назад". Обраний герой — велика
## 3D-модель посередині зі своєю зброєю в руці, нижче — опис, здібності
## й дія (обрати або купити).

const ABILITY_ICON_SCRIPT := preload("res://scenes/ui/ability_icon.gd")
const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")
const STAGE_GLOW_SCRIPT := preload("res://scenes/ui/stage_glow.gd")
const SKY_STAGE_SCRIPT := preload("res://scenes/ui/sky_stage.gd")
## Скільки плиток здібностей стоїть ліворуч від героя — решта праворуч.
const LEFT_SLOT_COUNT := 2
## Плитка здібності: ширина — під найдовшу назву ("Димова Граната") одним
## рядком, щоб усі плитки були однакові.
const TILE_SIZE := Vector2(136, 108)
const TILE_ICON := 70.0
const TILE_GAP := 8
## Відступ плиток від країв вітрини.
const TILE_MARGIN := 10
const HALL_BACKGROUND := "res://assets/ui/backgrounds/hero_hall.jpg"
## Найбільша висота списку зброї у вікні Арсеналу — далі він гортається.
const ARSENAL_MAX_HEIGHT := 320.0
## Ярлик виду прийому у вікні опису.
const KIND_TAGS := {
	&"talent": "Пасивна риса",
	&"blade": "Здібність",
	&"weapon": "Зброя героя",
}
const NAME_COLOR := Color(1.0, 0.85, 0.45)
## Кольори чисел у рядку характеристик (bbcode, тому — hex).
const HP_COLOR := "#ff8f80"
const SPEED_COLOR := "#7fe3ff"
const PENALTY_COLOR := "#ff9a6b"
const WEAPON_COLOR := "#ffd36b"

var _index := 0
var _preview: ModelPreview
var _placeholder_label: Label
var _glow: Control
var _sky: SkyStage

var _gold_badge: CurrencyBadge
var _gem_badge: CurrencyBadge
var _slot_row: HBoxContainer
var _slot_scroll: ScrollContainer
var _slot_buttons: Array[Button] = []
var _name_label: Label
var _description_label: Label
var _stats_label: RichTextLabel
var _left_slots: BoxContainer
var _right_slots: BoxContainer
var _ability_layer: Control
var _action_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.078)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	# Тло — зала зі статуями лицарів (арт гравця), обрізане під екран.
	if ResourceLoader.exists(HALL_BACKGROUND):
		var hall := TextureRect.new()
		hall.texture = load(HALL_BACKGROUND)
		hall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hall.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		hall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hall)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 28.0
	column.offset_top = 16.0
	column.offset_right = -28.0
	column.offset_bottom = -16.0
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	column.add_child(top_row)
	var title_box := OrnateBanner.new("Зала героїв", 30)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_box)
	# Валюта — навпроти полотна банера, а не його герба: відступ згори.
	var wallet := MarginContainer.new()
	wallet.add_theme_constant_override("margin_top", int(OrnateBanner.CREST_RISE))
	top_row.add_child(wallet)
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 8)
	wallet.add_child(wallet_row)
	_gold_badge = CurrencyBadge.new(&"gold", 20)
	wallet_row.add_child(_gold_badge)
	_gem_badge = CurrencyBadge.new(&"gem", 20)
	wallet_row.add_child(_gem_badge)

	# Вітрина: герой на своєму тлі посередині, а обабіч нього, на тій самій
	# вітрині, — плитки його прийомів (як спорядження в зразку мобільної гри).
	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(0, 150)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", UiTheme.panel_box())
	stage.clip_contents = true
	column.add_child(stage)
	_sky = SKY_STAGE_SCRIPT.new()
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_sky)
	_glow = STAGE_GLOW_SCRIPT.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_glow)
	_preview = MODEL_PREVIEW_SCRIPT.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_preview)
	_placeholder_label = Label.new()
	_placeholder_label.text = "Тимчасова модель — справжня буде пізніше"
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_placeholder_label.offset_top = -22.0
	_placeholder_label.add_theme_font_size_override("font_size", 13)
	_placeholder_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_placeholder_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_placeholder_label.add_theme_constant_override("outline_size", 4)
	stage.add_child(_placeholder_label)

	# Шар плиток поверх вітрини. Звичайний Control, а не контейнер: його
	# мінімальний розмір нульовий, тож плитки не розпирають вітрину (і низ
	# екрана) — лише розкладаються в тому місці, що вітрині дісталось.
	_ability_layer = Control.new()
	_ability_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_ability_layer)
	var ability_row := HBoxContainer.new()
	ability_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ability_row.offset_left = TILE_MARGIN
	ability_row.offset_top = TILE_MARGIN
	ability_row.offset_right = -TILE_MARGIN
	ability_row.offset_bottom = -TILE_MARGIN
	ability_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_layer.add_child(ability_row)
	_left_slots = _make_tile_group()
	ability_row.add_child(_left_slots)
	var hero_gap := Control.new()
	hero_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_row.add_child(hero_gap)
	_right_slots = _make_tile_group()
	ability_row.add_child(_right_slots)
	_ability_layer.resized.connect(_update_tile_layout)

	# Ряд слотів — героя гортаєш і обираєш іконками.
	var picker := UiTheme.make_picker_row()
	_slot_scroll = picker.scroll
	_slot_row = picker.row
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_slot_scroll)
	for i in HeroPool.ALL_HEROES.size():
		var def := HeroPool.ALL_HEROES[i]
		# Портрет героя на всю картку, якщо гравець його поклав; інакше —
		# щит-емблема. Колір героя — у кільці картки (style_picker_slot).
		var texture := ArtSlots.hero_portrait(def.id)
		var portrait := texture != null
		if not portrait:
			texture = UiTheme.control_icon("shield")
		var slot := UiTheme.make_picker_slot(texture, Color.WHITE, 88.0, portrait)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		_slot_row.add_child(slot)
		_slot_buttons.append(slot)

	# Опис і дії — в одному ряду: ліворуч панель опису, праворуч кнопки
	# стовпчиком. Окремий ряд кнопок під описом вилазив за низ екрана,
	# щойно опис переносився на другий рядок (вужчий екран, довший опис).
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	column.add_child(bottom)

	var info_panel := OrnatePanel.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(info_panel)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	info_panel.add_child(info)

	# Текст на темній панелі: ім'я — золоте (як різьблення рамки), опис —
	# теплий білий, а не сіро-блакитний колір героя, що зливався з тлом.
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_override("font", UiTheme.font(900))
	_name_label.add_theme_font_size_override("font_size", 26)
	_name_label.add_theme_color_override("font_color", NAME_COLOR)
	_name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.85))
	_name_label.add_theme_constant_override("outline_size", 6)
	info.add_child(_name_label)

	_description_label = Label.new()
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_override("font", UiTheme.font(700))
	_description_label.add_theme_font_size_override("font_size", 17)
	_description_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	_description_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_description_label.add_theme_constant_override("outline_size", 3)
	info.add_child(_description_label)

	# Характеристики — назва приглушена, а число своїм яскравим кольором:
	# око одразу ловить "85" і "+18%", а не читає весь рядок.
	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.fit_content = true
	_stats_label.scroll_active = false
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.add_theme_font_override("normal_font", UiTheme.font(700))
	_stats_label.add_theme_font_override("bold_font", UiTheme.font(900))
	_stats_label.add_theme_font_size_override("normal_font_size", 16)
	_stats_label.add_theme_font_size_override("bold_font_size", 16)
	_stats_label.add_theme_color_override("default_color", Color(0.8, 0.78, 0.92))
	_stats_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_stats_label.add_theme_constant_override("outline_size", 3)
	info.add_child(_stats_label)

	var actions := VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	bottom.add_child(actions)

	# Кнопки — арт гравця: зелена з золотими рунами й синя зі срібними.
	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(240, 56)
	_action_button.add_theme_font_size_override("font_size", 20)
	UiTheme.art_primary(_action_button)
	_action_button.pressed.connect(_on_action_pressed)
	actions.add_child(_action_button)

	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(240, 48)
	back.add_theme_font_size_override("font_size", 18)
	UiTheme.art_secondary(back)
	back.pressed.connect(_on_back_pressed)
	actions.add_child(back)


	_index = _find_index(GameState.selected_hero_id)
	_rebuild()
	UiTheme.scroll_to_center.call_deferred(_slot_scroll, _slot_buttons[_index])

func _find_index(hero_id: StringName) -> int:
	for i in HeroPool.ALL_HEROES.size():
		if HeroPool.ALL_HEROES[i].id == hero_id:
			return i
	return 0

func _current() -> HeroDef:
	return HeroPool.ALL_HEROES[_index]

func _on_slot_pressed(index: int) -> void:
	_index = index
	_rebuild()
	UiTheme.scroll_to_center(_slot_scroll, _slot_buttons[_index])

func _process(_delta: float) -> void:
	_glow.queue_redraw()

func _rebuild() -> void:
	var def := _current()
	_gold_badge.set_amount(GameState.gold)
	_gem_badge.set_amount(GameState.gems)
	for i in _slot_buttons.size():
		var other := HeroPool.ALL_HEROES[i]
		var unlocked := GameState.is_hero_unlocked(other.id)
		UiTheme.style_picker_slot(_slot_buttons[i], i == _index, unlocked, other.color)
		_slot_buttons[i].button_pressed = i == _index

	_glow.set("glow_color", def.color)
	_sky.set_background(ArtSlots.hero_background(def.id))
	var weapon := WeaponPool.get_def(GameState.get_equipped_weapon_id(def.id))
	_placeholder_label.visible = _preview.show_hero(def, weapon)

	_name_label.text = def.title
	_description_label.text = def.description
	var hp := int(Balance.HERO_MAX_HP + def.bonus_max_hp)
	var speed_percent := int(round(def.move_speed_percent * 100.0))
	_stats_label.text = "[center]Здоров'я [b][color=%s]%d[/color][/b]      Швидкість [b][color=%s]%+d%%[/color][/b]      Зброя: [b][color=%s]%s[/color][/b][/center]" % [
		HP_COLOR, hp, SPEED_COLOR if speed_percent >= 0 else PENALTY_COLOR, speed_percent, WEAPON_COLOR, weapon.title]

	for child in _left_slots.get_children():
		child.queue_free()
	for child in _right_slots.get_children():
		child.queue_free()
	var cards := _cards_for(def)
	for i in cards.size():
		var card: Dictionary = cards[i]
		var target := _left_slots if i < LEFT_SLOT_COUNT else _right_slots
		target.add_child(_build_ability_slot(card))

	PriceTag.clear(_action_button)
	if GameState.selected_hero_id == def.id:
		_action_button.text = "Обрано"
		_action_button.disabled = true
	elif GameState.is_hero_unlocked(def.id):
		_action_button.text = "Обрати"
		_action_button.disabled = false
	elif def.gem_cost > 0:
		_action_button.disabled = GameState.gems < def.gem_cost
		PriceTag.apply(_action_button, &"gem", def.gem_cost, "Купити")
	else:
		_action_button.disabled = GameState.gold < def.unlock_cost
		PriceTag.apply(_action_button, &"gold", def.unlock_cost, "Купити")

## Група плиток з одного боку героя. Стовпчиком чи рядком — вирішує
## _update_tile_layout за висотою вітрини.
func _make_tile_group() -> BoxContainer:
	var group := BoxContainer.new()
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.add_theme_constant_override("separation", TILE_GAP)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return group

## Дві плитки з боку — стовпчиком, якщо вітрина достатньо висока; на
## низькій (вузький екран, довгий опис героя) — поруч, рядком, щоб не
## вилазили за вітрину.
func _update_tile_layout() -> void:
	var stacked := _ability_layer.size.y >= TILE_SIZE.y * 2 + TILE_GAP + TILE_MARGIN * 2
	_left_slots.vertical = stacked
	_right_slots.vertical = stacked

## Плитка прийому на вітрині: іконка й назва на рунній рамці (арт гравця).
## Без підкладки іконку й підпис з'їдало строкате тло героя й зали.
## Натиск — вікно з описом прийому.
func _build_ability_slot(card: Dictionary) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = TILE_SIZE
	tile.tooltip_text = card.title
	tile.focus_mode = Control.FOCUS_NONE
	var tints := {"normal": Color.WHITE, "hover": Color(1.18, 1.18, 1.25), "pressed": Color(0.8, 0.8, 0.85)}
	for state: String in tints:
		tile.add_theme_stylebox_override(state, UiTheme.rune_frame_box(tints[state]))
	tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tile.pressed.connect(_on_ability_pressed.bind(card))

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6
	content.offset_top = 7
	content.offset_right = -6
	content.offset_bottom = -7
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(content)
	# Своя іконка здібності (арт гравця) — як є; немає — фігура кодом.
	var own_icon := ArtSlots.skill_icon(card.get("id", &""))
	if own_icon != null:
		var image := UiTheme.make_bare_icon(own_icon, TILE_ICON)
		image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(image)
	else:
		var drawn: Button = ABILITY_ICON_SCRIPT.new()
		drawn.setup(card.kind, card.color, card.title)
		drawn.custom_minimum_size = Vector2(TILE_ICON, TILE_ICON)
		drawn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(drawn)
	var caption := Label.new()
	caption.text = card.title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", UiTheme.font(800))
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", (card.color as Color).lerp(Color.WHITE, 0.6))
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	caption.add_theme_constant_override("outline_size", 4)
	content.add_child(caption)
	return tile

## Картки здібностей беремо з того, що герой СПРАВДІ вміє в бою
## (Skills3D), а не з окремого опису — тоді вітрина не бреше. Третьою
## йде картка про арсенал зброї.
func _cards_for(def: HeroDef) -> Array:
	var cards := []
	var equipped := WeaponPool.get_def(GameState.get_equipped_weapon_id(def.id))
	for entry: Dictionary in Skills3D.describe(def, equipped):
		cards.append({
			"kind": &"talent" if entry.kind == &"passive" else &"blade",
			"color": entry.color,
			"title": entry.title,
			"text": entry.text,
			"id": entry.id,
		})
	var weapons := WeaponPool.get_for_hero(def.id)
	var lines := []
	for weapon: WeaponDef in weapons:
		lines.append("%s — %s" % [weapon.title, weapon.description])
	# id "arsenal" — та сама картинка для всіх героїв (icons/skills/arsenal.png).
	cards.append({
		"kind": &"weapon", "color": Color(1.0, 0.85, 0.4),
		"title": "Арсенал",
		"text": "\n".join(lines),
		"id": &"arsenal",
		"hero_id": def.id,
	})
	return cards

## Опис прийому — у різьбленій рамці: іконка, назва, вид прийому, текст.
## Арсенал — не абзацом, а списком зброї з картинками: що в руках, що ще
## не куплено і за скільки.
func _on_ability_pressed(card: Dictionary) -> void:
	var is_arsenal: bool = card.has("hero_id")
	var dialog := OrnateDialog.new(card.title, ArtSlots.skill_icon(card.get("id", &"")), card.color,
		640.0 if is_arsenal else 560.0, KIND_TAGS.get(card.kind, ""))
	if is_arsenal:
		dialog.body.add_child(_arsenal_list(card.hero_id))
	else:
		dialog.add_text(card.text)
	dialog.add_button("Зрозуміло")
	add_child(dialog)

## Уся зброя героя рядками на рунній рамці. Довгий список гортається —
## вікно не вилазить за екран.
func _arsenal_list(hero_id: StringName) -> Control:
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	var equipped := GameState.get_equipped_weapon_id(hero_id)
	for weapon: WeaponDef in WeaponPool.get_for_hero(hero_id):
		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override("panel", UiTheme.rune_frame_box())
		list.add_child(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row_panel.add_child(row)
		var texture := ArtSlots.weapon_icon(weapon.id, weapon.icon)
		if texture == null:
			texture = ArtSlots.placeholder_icon(weapon.color, 64)
		row.add_child(UiTheme.make_bare_icon(texture, 50.0))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.add_theme_constant_override("separation", 1)
		row.add_child(text)
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		text.add_child(name_row)
		var name_label := Label.new()
		name_label.text = weapon.title
		name_label.add_theme_font_override("font", UiTheme.font(800))
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", OrnateDialog.TITLE_COLOR)
		name_row.add_child(name_label)
		if weapon.id == equipped:
			name_row.add_child(OrnateDialog.make_tag("У руках", Color(0.45, 0.9, 0.5)))
		elif not GameState.is_weapon_owned(weapon.id):
			var price := CurrencyBadge.new(&"gold", 14, false)
			price.set_amount(weapon.cost_gold)
			name_row.add_child(price)
		var description := Label.new()
		description.text = weapon.description
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 14)
		description.add_theme_color_override("font_color", Color(0.86, 0.84, 0.94))
		text.add_child(description)
	UiTheme.tag_scroll_pass(list)
	# Висота прокрутки — як у списку, але не більше ARSENAL_MAX_HEIGHT.
	# Висоту списку з перенесеними описами видно лише після розкладки.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, ARSENAL_MAX_HEIGHT)
	scroll.add_child(list)
	list.resized.connect(func() -> void:
		scroll.custom_minimum_size.y = minf(list.size.y, ARSENAL_MAX_HEIGHT))
	return scroll

func _on_action_pressed() -> void:
	var def := _current()
	if GameState.is_hero_unlocked(def.id):
		GameState.select_hero(def.id)
	elif def.gem_cost > 0:
		if GameState.unlock_hero_with_gems(def.id):
			AudioManager.play(&"purchase", 0.0)
			GameState.select_hero(def.id)
	elif GameState.unlock_hero(def.id):
		AudioManager.play(&"purchase", 0.0)
		GameState.select_hero(def.id)
	_rebuild()

func _on_back_pressed() -> void:
	# Назад — туди, звідки прийшли: у місто до дверей будівлі чи в меню.
	GameState.return_from_ui()
