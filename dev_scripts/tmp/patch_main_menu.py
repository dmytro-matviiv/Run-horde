# -*- coding: utf-8 -*-
"""Разова правка scenes/ui/main_menu.gd: меню з арту гравця."""
p = r"D:\Claude code\idle survivor_like\scenes\ui\main_menu.gd"
s = open(p, encoding="utf-8").read()

start = s.index("func _ready() -> void:")
end = s.index("\t_update_gold_label()\n\t_update_chest_button()")
NEW_READY = '''func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Тло — своє для меню (menu.jpg), поки його немає — зала героїв,
	# трохи притемнена, щоб панель меню була головною.
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

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	column.add_child(action_row)
	var shop_button := _make_menu_button("Магазин", Vector2(190, 52), 18, ArtSlots.menu_icon("shop"))
	shop_button.pressed.connect(_on_shop_pressed)
	action_row.add_child(shop_button)
	_chest_button = _make_menu_button("", Vector2(230, 52), 16, ArtSlots.menu_icon("chest"))
	_chest_button.pressed.connect(_on_chest_pressed)
	action_row.add_child(_chest_button)

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

'''
s = s[:start] + NEW_READY + s[end:]

reps = [
    ('''const CHEST_MESSAGE_SEC := 3.0
''', '''const CHEST_MESSAGE_SEC := 3.0
## Тло меню: своє (поклади assets/ui/backgrounds/menu.jpg), інакше — зала.
const MENU_BACKGROUND := "res://assets/ui/backgrounds/menu.jpg"
const HALL_BACKGROUND := "res://assets/ui/backgrounds/hero_hall.jpg"
'''),
    ('''var _hero_label: Label
''', '''var _hero_label: Label
var _weapon_label: Label
var _hero_portrait: TextureRect
'''),
    ('''	_hero_label.text = "%s  •  %s" % [hero.title, weapon.title]
''', '''	_hero_label.text = hero.title
	_weapon_label.text = "Зброя: %s" % weapon.title
	_hero_portrait.texture = ArtSlots.hero_portrait(hero.id)
	_hero_portrait.visible = _hero_portrait.texture != null
'''),
    ('''## Одна велика панель посередині, як діалог квесту в зразку Kenney:
## заголовок, підказка, хто в поході — і головна дія світлою кнопкою.
## Магазин і скринька — трохи менші кнопки поруч; графіка, FPS, автори —
## ще менший ряд знизу, як другорядні пункти в зразку.
''', '''## Посередині — банер "Rune Horde" і різьблена панель (арт гравця): хто
## й з чим піде в бій, зелена "Грати", під нею сині "Магазин" і
## "Скринька" з іконками, найменшим рядом — графіка, FPS, автори.
'''),
]
for a, b in reps:
    assert s.count(a) == 1, a[:90]
    s = s.replace(a, b)

s = s.replace('''func _update_chest_button() -> void:''', '''## Синя кнопка з арту гравця, за потреби — з іконкою зліва від напису.
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

func _update_chest_button() -> void:''', 1)
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
