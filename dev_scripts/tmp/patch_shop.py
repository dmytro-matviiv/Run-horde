# -*- coding: utf-8 -*-
"""Разова правка scenes/ui/shop.gd: тло, банери розділів, картки товару."""
p = r"D:\Claude code\idle survivor_like\scenes\ui\shop.gd"
s = open(p, encoding="utf-8").read()

OLD_ROW = '''## Рядок "іконка + назва + опис + кнопка" — картка в рамці, як предмет
## у крамниці. Повертає кнопку, щоб виклик сам задав текст і дію.
##
## Іконка — слот під майбутній арт: поклади файл
## res://assets/ui/icons/shop/<назва>.png, і він з'явиться замість
## кольорової заглушки (див. assets/ART_GUIDE.md).
func _build_row(item_title: String, description: String, icon_name: String = "", accent: Color = Color(1, 0.86, 0.4)) -> Button:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_box())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var own_icon := ArtSlots.shop_icon(icon_name)
	if own_icon != null:
		# Готовий арт — без рамки-слота, вона лише забруднює картинку.
		row.add_child(UiTheme.make_bare_icon(own_icon, 72.0))
	else:
		var fallback := UiTheme.control_icon("money" if icon_name == "exchange" else "star")
		row.add_child(UiTheme.make_slot(fallback, 48.0, accent))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = item_title
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", UiTheme.TEXT)
	info.add_child(name_label)
	var desc_label := Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	info.add_child(desc_label)
'''

NEW_ROW = '''## Рядок "іконка + назва + опис + кнопка" — картка товару (арт гравця) з
## відсіком під іконку зліва. Повертає кнопку, щоб виклик сам задав
## текст і дію.
##
## Висота картки фіксована (UiTheme.ITEM_CARD_HEIGHT): відсік — частина
## рамки, і на вищій картці він би витягнувся. Іконка — першою в ряду, і
## картка сама ставить її в центр відсіку, тож іконки всіх карток стоять
## рівно одна під одною. Іконка — файл res://assets/ui/icons/shop/<назва>.png
## (див. assets/ART_GUIDE.md); немає — біла заглушка в кольорі товару.
func _build_row(item_title: String, description: String, icon_name: String = "", accent: Color = Color(1, 0.86, 0.4)) -> Button:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.item_card_box())
	card.custom_minimum_size = Vector2(0, UiTheme.ITEM_CARD_HEIGHT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var own_icon := ArtSlots.shop_icon(icon_name)
	var icon: TextureRect
	if own_icon != null:
		icon = UiTheme.make_bare_icon(own_icon, UiTheme.ITEM_ICON)
	else:
		var fallback := UiTheme.control_icon("money" if icon_name == "exchange" else "star")
		icon = UiTheme.make_bare_icon(fallback, UiTheme.ITEM_ICON)
		icon.modulate = accent
	row.add_child(icon)
	# Текст — за відсіком, а не на ньому (separation ряду теж додається).
	var icon_gap := Control.new()
	icon_gap.custom_minimum_size = Vector2(UiTheme.ITEM_ICON_GAP - 32, 0)
	icon_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_gap)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = item_title
	name_label.add_theme_font_override("font", UiTheme.font(800))
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	info.add_child(name_label)
	var desc_label := Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.82, 0.8, 0.92))
	info.add_child(desc_label)
'''

reps = [
    ("const STATUS_SEC := 3.0\n",
     "const STATUS_SEC := 3.0\n## Тло — крамниця з полицями й скринями (арт гравця).\n"
     "const SHOP_BACKGROUND := \"res://assets/ui/backgrounds/shop.jpg\"\n"),
    ("\tbackground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n\tadd_child(background)\n",
     "\tbackground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n\tadd_child(background)\n"
     "\tif ResourceLoader.exists(SHOP_BACKGROUND):\n"
     "\t\tvar shop_art := TextureRect.new()\n"
     "\t\tshop_art.texture = load(SHOP_BACKGROUND)\n"
     "\t\tshop_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE\n"
     "\t\tshop_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED\n"
     "\t\tshop_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n"
     "\t\tshop_art.mouse_filter = Control.MOUSE_FILTER_IGNORE\n"
     "\t\tadd_child(shop_art)\n"),
    ("_rows_container.custom_minimum_size = Vector2(620, 0)",
     "_rows_container.custom_minimum_size = Vector2(680, 0)"),
    ("\t_status_label.add_theme_color_override(\"font_color\", UiTheme.HEADING)\n",
     "\t_status_label.add_theme_color_override(\"font_color\", UiTheme.HEADING)\n"
     "\t_status_label.add_theme_color_override(\"font_outline_color\", Color(0, 0, 0, 0.8))\n"
     "\t_status_label.add_theme_constant_override(\"outline_size\", 6)\n"),
    ("\t\twait.add_theme_color_override(\"font_color\", UiTheme.TEXT_DIM)\n",
     "\t\twait.add_theme_color_override(\"font_color\", UiTheme.TEXT)\n"
     "\t\twait.add_theme_color_override(\"font_outline_color\", Color(0, 0, 0, 0.8))\n"
     "\t\twait.add_theme_constant_override(\"outline_size\", 6)\n"),
    ("_build_row(STARTER_PACK_TITLES[pack_id], _get_pack_desc(pack_id))",
     "_build_row(STARTER_PACK_TITLES[pack_id], _get_pack_desc(pack_id), String(pack_id))"),
    ("Ролики за нагороду лишаються за бажанням.\")",
     "Ролики за нагороду лишаються за бажанням.\", \"remove_ads\")"),
    ("return \"%d золота (реклама вже прибрана)\" % Balance.STARTER_ADS_GOLD",
     "return \"%s золота (реклама вже прибрана)\" % UiTheme.format_amount(Balance.STARTER_ADS_GOLD)"),
    ("return \"%d золота + прибрати банер і рекламу між ранами\" % Balance.STARTER_ADS_GOLD",
     "return \"%s золота + прибрати банер і рекламу між ранами\" % UiTheme.format_amount(Balance.STARTER_ADS_GOLD)"),
    ("return \"%d золота (герой уже є — замість нього золото)\" % (Balance.STARTER_HERO_GOLD + blade_warden.unlock_cost)",
     "return \"%s золота (герой уже є — замість нього золото)\" % UiTheme.format_amount(Balance.STARTER_HERO_GOLD + blade_warden.unlock_cost)"),
    ("return \"%s + %d золота\" % [blade_warden.title, Balance.STARTER_HERO_GOLD]",
     "return \"%s + %s золота\" % [blade_warden.title, UiTheme.format_amount(Balance.STARTER_HERO_GOLD)]"),
    ("\tvar row := UiTheme.make_title(text, 20)\n",
     "\tvar row := SectionBanner.new(text, 20)\n"),
    (OLD_ROW, NEW_ROW),
]
for a, b in reps:
    assert s.count(a) == 1, a[:80]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
