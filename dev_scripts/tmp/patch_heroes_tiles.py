# -*- coding: utf-8 -*-
"""Разова правка scenes/ui/heroes.gd: здібності — плитками в рунній рамці
всередині вітрини героя, а не стовпчиками обабіч неї."""
p = r"D:\Claude code\idle survivor_like\scenes\ui\heroes.gd"
s = open(p, encoding="utf-8").read()

reps = [
    ('''## Скільки карток здібностей лягає зліва від вітрини — решта праворуч.
const LEFT_SLOT_COUNT := 2
## Ширина стовпчика здібностей — під найдовшу назву ("Димова Граната")
## одним рядком: у два рядки картки ставали вищими й низ екрана вилазив.
const RACK_WIDTH := 132.0
''', '''## Скільки плиток здібностей стоїть ліворуч від героя — решта праворуч.
const LEFT_SLOT_COUNT := 2
## Плитка здібності: ширина — під найдовшу назву ("Димова Граната") одним
## рядком, щоб усі плитки були однакові.
const TILE_SIZE := Vector2(128, 104)
const TILE_ICON := 58.0
const TILE_GAP := 8
## Відступ плиток від країв вітрини.
const TILE_MARGIN := 10
'''),
    ('''var _left_slots: VBoxContainer
var _right_slots: VBoxContainer
''', '''var _left_slots: BoxContainer
var _right_slots: BoxContainer
var _ability_layer: Control
'''),
    ('''	# Вітрина: герой стоїть просто неба, а обабіч — картки його прийомів
	# (як спорядження в зразку мобільної гри), а не рядком під описом.
	var stage_row := HBoxContainer.new()
	stage_row.custom_minimum_size = Vector2(0, 150)
	stage_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_row.add_theme_constant_override("separation", 10)
	column.add_child(stage_row)

	_left_slots = VBoxContainer.new()
	_left_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_left_slots.add_theme_constant_override("separation", 6)
	_left_slots.custom_minimum_size = Vector2(RACK_WIDTH, 0)
	stage_row.add_child(_left_slots)

	var stage := PanelContainer.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", UiTheme.panel_box())
	stage.clip_contents = true
	stage_row.add_child(stage)
''', '''	# Вітрина: герой на своєму тлі посередині, а обабіч нього, на тій самій
	# вітрині, — плитки його прийомів (як спорядження в зразку мобільної гри).
	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(0, 150)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", UiTheme.panel_box())
	stage.clip_contents = true
	column.add_child(stage)
'''),
    ('''	stage.add_child(_placeholder_label)

	_right_slots = VBoxContainer.new()
	_right_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_right_slots.add_theme_constant_override("separation", 6)
	_right_slots.custom_minimum_size = Vector2(RACK_WIDTH, 0)
	stage_row.add_child(_right_slots)
''', '''	stage.add_child(_placeholder_label)

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
'''),
    ('''## Картка прийому обабіч вітрини — кольоровий квадратний слот (як
## спорядження в зразку), а не рядок іконок під описом; назва — під ним,
## щоб зрозуміло без наведення, що саме це за прийом.
func _build_ability_slot(card: Dictionary) -> VBoxContainer:
	var holder := VBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 2)
	# Своя іконка здібності (згенерований арт) — якщо гравець її поклав, без
	# рамки-слота (вона лише забруднює готову картинку), лише трохи більша;
	# інакше — та сама фігура кодом, що й раніше, на кольоровій підкладці.
	var own_icon := ArtSlots.skill_icon(card.get("id", &""))
	var icon: Button
	if own_icon != null:
		icon = Button.new()
		icon.custom_minimum_size = Vector2(74, 74)
		icon.icon = own_icon
		icon.expand_icon = true
		icon.flat = true
		icon.tooltip_text = card.title
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			icon.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		icon.pressed.connect(_on_ability_pressed.bind(card))
		holder.add_child(icon)
	else:
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", UiTheme.slot_box(card.color))
		slot.custom_minimum_size = Vector2(72, 72)
		slot.tooltip_text = card.title
		icon = ABILITY_ICON_SCRIPT.new()
		icon.setup(card.kind, card.color, card.title)
		icon.pressed.connect(_on_ability_pressed.bind(card))
		slot.add_child(icon)
		holder.add_child(slot)
	# Тло зали строкате — підпис на темній плашці, інакше губився на стінах.
	holder.add_child(UiTheme.make_caption(card.title, card.color))
	return holder''', '''## Група плиток з одного боку героя. Стовпчиком чи рядком — вирішує
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
	return tile'''),
]
for a, b in reps:
    assert s.count(a) == 1, a[:90]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
