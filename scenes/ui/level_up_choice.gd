extends Control

## Екран вибору апгрейду при левел-апі. Гру ставить на паузу той,
## хто цю сцену створює (run.gd) — сама сцена лише показує картки
## й після кліку віддає id обраного апгрейду через сигнал.
##
## Вигляд — з арту гравця: банер "Рівень N!" з гербом, картки на рунній
## рамці з іконкою, назвою, описом і крапками рівня.

signal upgrade_chosen(id: StringName)

## Іконка здібності походу — з того арту, що вже є: таланти Храму, іконки
## прийомів героя, кнопки бою. [звідки, назва]; кого тут немає — руна.
const UPGRADE_ICONS := {
	&"hp_up": ["talent", "meta_max_hp"],
	&"regen": ["talent", "meta_max_hp"],
	&"speed": ["talent", "meta_move_speed"],
	&"damage": ["talent", "meta_damage"],
	&"crit": ["talent", "meta_luck"],
	&"dodge_cd": ["combat", "dodge"],
	&"arc": ["combat", "attack"],
	&"rage_gain": ["skill", "rage"],
	&"dash_power": ["skill", "rage_dash"],
	&"whirl_power": ["skill", "whirlwind"],
	&"pierce": ["combat", "gun"],
	&"magazine": ["combat", "gun"],
	&"reload": ["combat", "gun"],
	&"extra_bullet": ["combat", "gun"],
	&"accuracy": ["combat", "gun"],
	&"fire_rate": ["combat", "gun"],
	&"explosive": ["combat", "gun"],
	&"mark_power": ["skill", "death_mark"],
	&"smoke_power": ["skill", "smoke_veil"],
	&"cast_speed": ["combat", "staff"],
	&"spell_extra": ["combat", "staff"],
	&"spell_pierce": ["combat", "staff"],
	&"spell_power": ["combat", "staff"],
	&"ring_power": ["skill", "fire_ring"],
	&"phoenix_power": ["skill", "phoenix"],
	&"nova_power": ["skill", "rune_nova"],
	&"charge_speed": ["skill", "rune_charge"],
}
const FALLBACK_ICON := ["combat", "rune"]
const CARD_SIZE := Vector2(250, 240)
const TITLE_COLOR := Color(1.0, 0.86, 0.5)

@onready var level_label: Label = $CenterContainer/VBoxContainer/LevelLabel
@onready var cards_container: HBoxContainer = $CenterContainer/VBoxContainer/CardsContainer

var _banner: OrnateBanner

## Картки нового зразка: кожна вже знає свій рівень і межу. Саме ними
## користується данж (RunUpgrades), бо його здібності залежать від
## героя та його зброї.
func _ready() -> void:
	level_label.visible = false
	cards_container.add_theme_constant_override("separation", 18)
	($CenterContainer/VBoxContainer as VBoxContainer).add_theme_constant_override("separation", 14)

func setup_cards(new_level: int, cards: Array) -> void:
	_show_title(new_level)
	for card: Dictionary in cards:
		cards_container.add_child(_make_card(card.id, card.title, card.text, card.level, card.max))

func setup(new_level: int, choices: Array[UpgradeDef], current_levels: Dictionary) -> void:
	_show_title(new_level)
	for upgrade in choices:
		var current_level: int = current_levels.get(upgrade.id, 0)
		cards_container.add_child(_make_card(upgrade.id, upgrade.title, upgrade.description,
			current_level + 1, upgrade.max_level))

## Банер "Рівень N!" і підказка під ним — замість простого напису зі сцени.
func _show_title(new_level: int) -> void:
	var column := level_label.get_parent()
	if _banner == null:
		_banner = OrnateBanner.new("", 30)
		_banner.custom_minimum_size = Vector2(420, 0)
		_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(_banner)
		column.move_child(_banner, 0)
		var hint := Label.new()
		hint.text = "Обери, чим посилити героя"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_override("font", UiTheme.font(800))
		hint.add_theme_font_size_override("font_size", 17)
		hint.add_theme_color_override("font_color", Color(0.92, 0.9, 1.0))
		hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		hint.add_theme_constant_override("outline_size", 5)
		column.add_child(hint)
		column.move_child(hint, 1)
	for child in _banner.get_children():
		if child is Label:
			(child as Label).text = "Рівень %d!" % new_level

## Картка — кнопка на рунній рамці (арт гравця): іконка, назва золотом,
## опис і крапки рівня (повні — скільки буде після вибору). Ширина
## фіксована, довгий опис переноситься — інакше картка вилазила б за край.
func _make_card(id: StringName, title: String, text: String, level: int, max_level: int) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.focus_mode = Control.FOCUS_NONE
	var tints := {"normal": Color.WHITE, "hover": Color(1.2, 1.2, 1.28), "pressed": Color(0.8, 0.8, 0.85)}
	for state: String in tints:
		card.add_theme_stylebox_override(state, UiTheme.rune_frame_box(tints[state]))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.pressed.connect(_on_card_pressed.bind(id))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 14
	box.offset_bottom = -14
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var icon := _icon_for(id)
	if icon != null:
		var image := UiTheme.make_bare_icon(icon, 64.0)
		image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(image)
	box.add_child(_card_label(title, 21, TITLE_COLOR, 900))
	box.add_child(_card_label(text, 15, Color(0.95, 0.93, 0.98), 700))
	box.add_child(_level_pips(level, max_level))
	return card

func _icon_for(id: StringName) -> Texture2D:
	var source: Array = UPGRADE_ICONS.get(id, FALLBACK_ICON)
	match source[0]:
		"talent":
			return ArtSlots.talent_icon(StringName(source[1]))
		"skill":
			return ArtSlots.skill_icon(StringName(source[1]))
	return ArtSlots.combat_icon(source[1])

## Крапки рівня: золоті — скільки буде після вибору, порожні — що лишилось.
## Перший рівень — ярлик "Нове", бо крапка з п'яти мало що каже.
func _level_pips(level: int, max_level: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in max_level:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(12, 12)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var filled := i < level
		var style := UiTheme.make_box(UiTheme.GOLD if filled else Color(0, 0, 0, 0.35), 6, 1,
			Color(1.0, 0.92, 0.6) if filled else Color(0.75, 0.7, 0.9, 0.6))
		style.anti_aliasing = true
		pip.add_theme_stylebox_override("panel", style)
		row.add_child(pip)
	if level <= 1:
		var tag := OrnateDialog.make_tag("Нове", Color(0.45, 0.9, 0.5))
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
	return row

func _card_label(text: String, font_size: int, color: Color, weight: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UiTheme.font(weight))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("outline_size", 3)
	return label

func _on_card_pressed(id: StringName) -> void:
	upgrade_chosen.emit(id)
