# -*- coding: utf-8 -*-
"""Разова правка scenes/ui/heroes.gd: опис здібності — OrnateDialog,
Арсенал — список зброї з картинками; кнопки — спільні art_primary/secondary."""
p = r"D:\Claude code\idle survivor_like\scenes\ui\heroes.gd"
s = open(p, encoding="utf-8").read()

start = s.index("func _build_popup() -> void:")
end = s.index("func _find_index(")
s = s[:start] + s[end:]

reps = [
    ('''const SELECT_BUTTON := "res://assets/ui/theme/button_hero_select.png"
const SELECT_BUTTON_DISABLED := "res://assets/ui/theme/button_hero_select_disabled.png"
const BACK_BUTTON := "res://assets/ui/theme/button_hero_back.png"
''', '''## Ярлик виду прийому у вікні опису.
const KIND_TAGS := {
	&"talent": "Пасивна риса",
	&"blade": "Здібність",
	&"weapon": "Зброя героя",
}
'''),
    ('''var _popup: Control
var _popup_title: Label
var _popup_text: Label
''', ''),
    ('''	UiTheme.art_button(_action_button, SELECT_BUTTON, 27, 23, SELECT_BUTTON_DISABLED)''',
     '''	UiTheme.art_primary(_action_button)'''),
    ('''	UiTheme.art_button(back, BACK_BUTTON, 13, 10)''', '''	UiTheme.art_secondary(back)'''),
    ('''	_build_popup()

''', '''
'''),
    ('''		"title": "Арсенал",
		"text": "\\n".join(lines),
		"id": &"arsenal",
	})''', '''		"title": "Арсенал",
		"text": "\\n".join(lines),
		"id": &"arsenal",
		"hero_id": def.id,
	})'''),
    ('''func _on_ability_pressed(card: Dictionary) -> void:
	_popup_title.text = card.title
	_popup_title.add_theme_color_override("font_color", card.color)
	_popup_text.text = card.text
	_popup.visible = true
''', '''## Опис прийому — у різьбленій рамці: іконка, назва, вид прийому, текст.
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
	if list.get_child_count() <= 3:
		return list
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.add_child(list)
	return scroll
'''),
]
for a, b in reps:
    assert s.count(a) == 1, a[:90]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
