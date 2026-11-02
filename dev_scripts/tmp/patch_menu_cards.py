# -*- coding: utf-8 -*-
"""Разова правка scenes/ui/main_menu.gd: "Магазин" і "Скринька" —
кнопки-картки з відсіком під іконку (компактна картка товару)."""
p = r"D:\Claude code\idle survivor_like\scenes\ui\main_menu.gd"
s = open(p, encoding="utf-8").read()

reps = [
    ('''var _chest_button: Button
''', '''var _chest_button: Button
var _chest_hint: Label
var _chest_content: Control
'''),
    ('''	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	column.add_child(action_row)
	var shop_button := _make_menu_button("Магазин", Vector2(190, 52), 18, ArtSlots.menu_icon("shop"))
	shop_button.pressed.connect(_on_shop_pressed)
	action_row.add_child(shop_button)
	_chest_button = _make_menu_button("", Vector2(230, 52), 16, ArtSlots.menu_icon("chest"))
	_chest_button.pressed.connect(_on_chest_pressed)
	action_row.add_child(_chest_button)
''', '''	# Магазин і скринька — картками з відсіком під іконку, як товари на
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
'''),
    ('''func _update_chest_button() -> void:
	if GameState.is_chest_available():
		_chest_button.text = "Скринька (реклама)"
		_chest_button.disabled = false
	else:
		var minutes_left := GameState.get_chest_seconds_left() / 60
		_chest_button.text = "Скринька через %d хв" % minutes_left
		_chest_button.disabled = true
''', '''## Кнопка-картка: компактна рамка з відсіком (UiTheme.item_card_small_box),
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
'''),
    ('''	_chest_button.disabled = true
	AdsManager.show_rewarded_ad''', '''	_chest_button.disabled = true
	_chest_content.modulate = Color(1, 1, 1, 0.6)
	AdsManager.show_rewarded_ad'''),
    ('''	_chest_button.text = "Нагороду не отримано"''', '''	_chest_hint.text = "Нагороду не отримано"'''),
]
for a, b in reps:
    assert s.count(a) == 1, a[:90]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
