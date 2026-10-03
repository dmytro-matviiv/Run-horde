extends Node

## Єдине оформлення всіх екранів. Тема будується кодом і вішається на
## корінь дерева сцен — звідти Godot роздає її всім вікнам і кнопкам
## автоматично, тож кожен екран не мусить знати про стилі нічого.
##
## СТИЛЬ — "пухкі" округлі кнопки мобільної гри: градієнт, товста темніша
## рамка, глянцевий відблиск зверху й м'яка тінь під кожною кнопкою чи
## панеллю; заголовки — на кольоровій плашці-пігулці. Текстури генерує
## tools/build_new_theme_textures.py (лежить поза репозиторієм — одноразовий
## скрипт, результат зберігається тут, у assets/ui/theme). Шрифт — Nunito
## (Google Fonts, OFL), змінної ваги: UiTheme.font(700) і важче для великих
## заголовків. Немає файла текстури — лишається проста плоска рамка.
##
## ШРИФТ МУСИТЬ МАТИ КИРИЛИЦЮ (з і, ї, є, ґ). Попередній, Baloo 2, її не
## мав — і вся українська тихо малювалась тонким запасним шрифтом Godot,
## на який ще й вага не діяла: текст губився на темних панелях.

# Палітра: глибокий індиго, лавандові лінії, зелена головна дія.
const BG_DARK := Color(0.055, 0.05, 0.11)
const PANEL := Color(0.118, 0.102, 0.227)
const PANEL_LIGHT := Color(0.19, 0.17, 0.34)
const ACCENT := Color(1.0, 0.78, 0.25)
const ACCENT_DARK := Color(0.75, 0.52, 0.12)
const HEADING := Color(0.88, 0.85, 1.0)
const LINE := Color(0.75, 0.78, 0.95)
const TEXT := Color(0.96, 0.96, 1.0)
const TEXT_DIM := Color(0.68, 0.68, 0.82)
const TEXT_DARK := Color(0.1, 0.11, 0.12)
const GOLD := Color(1.0, 0.86, 0.4)
## Фіолетовий — як гем на іконці валюти (арт гравця).
const GEM := Color(0.86, 0.58, 1.0)
const DANGER := Color(1.0, 0.35, 0.35)

const THEME_DIR := "res://assets/ui/theme/"
const CURSOR_DIR := "res://assets/ui/cursors/"
const FONT_PATH := "res://assets/ui/fonts/Nunito-Variable.ttf"

static var _font_cache: Dictionary = {}

## Розмір, під який зверстано всі екрани. На більшому екрані (телефон
## 2400×1080) інтерфейс пропорційно збільшується, а зайва ширина просто
## додає місця по боках.
const BASE_SIZE := Vector2i(1152, 648)

var theme: Theme

func _ready() -> void:
	theme = _build_theme()
	# Тема на корені вікна — успадковується всіма екранами гри. Але
	# CanvasLayer (HUD данжу й міста, вибір здібності, пауза) ланцюжок
	# теми рве: такі вузли брали стандартну тему Godot — сірі кнопки без
	# рамок. Тому ту саму тему вливаємо ще й у стандартну.
	get_tree().root.theme = theme
	ThemeDB.get_default_theme().merge_with(theme)
	_setup_scaling()
	_setup_cursors()

## Інтерфейс малюється в "логічних" пікселях BASE_SIZE і розтягується під
## екран. Без цього телефон малював би все у своїх дрібних пікселях:
## текст ледь читався, джойстик і кнопки — під ніготь, а не під палець.
## 3D від цього не залежить — його роздільність веде PerfSettings.
func _setup_scaling() -> void:
	var root := get_tree().root
	root.content_scale_size = BASE_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

## Nunito певної ваги (200-1000). Шрифт змінний (один файл, вага — вісь
## "wght"), тож важчі заголовки не тягнуть окремого файла. Результат
## кешується — FontVariation не створюємо заново на кожен виклик.
## Ключ осі — числовий тег, а не рядок "wght": рядкові ключі Godot звіряє
## зі своїми назвами ("weight"), тож {"wght": ...} мовчки ігнорувався і
## весь текст лишався найтоншим.
static func font(weight: int = 700) -> Font:
	if _font_cache.has(weight):
		return _font_cache[weight]
	var result: Font
	if ResourceLoader.exists(FONT_PATH):
		var base := load(FONT_PATH)
		var variant := FontVariation.new()
		variant.base_font = base
		var weight_tag := TextServerManager.get_primary_interface().name_to_tag("wght")
		variant.variation_opentype = {weight_tag: weight}
		result = variant
	_font_cache[weight] = result
	return result

## Заготовка прямокутника зі скругленням — для дрібних плашок (бафи,
## підкладки), де візерунчаста рамка була б завеликою.
static func make_box(color: Color, radius: int = 10, border: int = 0, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	if border > 0:
		box.border_width_left = border
		box.border_width_right = border
		box.border_width_top = border
		box.border_width_bottom = border
		box.border_color = border_color
	return box

## Панель із візерунчастою рамкою. accent — відтінок рамки (біле — як є):
## так споряджена зброя чи обраний рівень виділяються своїм кольором.
static func panel_box(accent: Color = Color.WHITE) -> StyleBox:
	var box := _texture_box("panel.png", 34, 22, 16)
	if box is StyleBoxTexture:
		(box as StyleBoxTexture).modulate_color = accent
	return box

## КАРТКА ТОВАРУ (арт гравця): темна рамка з рунами по кутах і квадратний
## відсік під іконку зліва. Текстура вже зменшена до ITEM_CARD_HEIGHT, а
## лівий край разом із відсіком у 9-slice не тягнеться — відсік лишається
## квадратним, лише поки картка саме такої висоти. Тому висоту картки
## фіксуй (custom_minimum_size.y), а іконку ITEM_ICON став першою в ряд:
## content_margin_left уже виводить її рівно в центр відсіку.
const ITEM_CARD_HEIGHT := 120.0
const ITEM_ICON := 64.0
## Від іконки до тексту — щоб текст починався за відсіком, а не на ньому.
const ITEM_ICON_GAP := 36

static func item_card_box() -> StyleBox:
	var path := THEME_DIR + "item_card.png"
	if not ResourceLoader.exists(path):
		return panel_box()
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	# Лівий край — рамка й відсік (118 px), правий — рамка з рунами.
	# Згори/знизу — по половині висоти: посередині не тягнеться нічого.
	box.texture_margin_left = 118
	box.texture_margin_right = 27
	box.texture_margin_top = 59
	box.texture_margin_bottom = 59
	# Центр відсіку — 60 px від лівого краю й посередині висоти.
	box.content_margin_left = 60 - ITEM_ICON * 0.5
	box.content_margin_right = 26
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

## Компактна картка (84 px) — та сама рамка з відсіком, менша: кнопки
## "Магазин" і "Скринька" в меню. Відсік — квадрат з центром на
## (ITEM_SMALL_SLOT_CENTER, посередині висоти); текст — від ITEM_SMALL_TEXT_X.
const ITEM_CARD_SMALL_HEIGHT := 84.0
const ITEM_ICON_SMALL := 44.0
const ITEM_SMALL_SLOT_CENTER := 42.0
const ITEM_SMALL_TEXT_X := 94.0

static func item_card_small_box(tint: Color = Color.WHITE) -> StyleBox:
	var path := THEME_DIR + "item_card_small.png"
	if not ResourceLoader.exists(path):
		return panel_box(tint)
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	box.texture_margin_left = 83
	box.texture_margin_right = 19
	box.texture_margin_top = 41
	box.texture_margin_bottom = 41
	box.modulate_color = tint
	return box

## Рунна рамка (арт гравця, та сама, що в картки товару, але без відсіку):
## темна плашка з рунами по кутах — підкладка під іконку з підписом поверх
## строкатого арту (здібності на вітрині героя). Середина тягнеться як
## завгодно. tint — для наведення/натискання кнопки.
static func rune_frame_box(tint: Color = Color.WHITE) -> StyleBox:
	var path := THEME_DIR + "rune_frame.png"
	if not ResourceLoader.exists(path):
		return panel_box(tint)
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	box.texture_margin_left = 20
	box.texture_margin_right = 20
	box.texture_margin_top = 20
	box.texture_margin_bottom = 20
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.modulate_color = tint
	return box

## Картка товару (Ринок, Храм) з іконкою у відсіку. Повертає картку; її
## єдиний нащадок — ряд (HBoxContainer), де вже стоять іконка й відступ за
## відсіком: додай туди опис і кнопку. tint — колір білої заглушки, коли
## власного арту ще немає (для готової картинки — WHITE).
static func make_item_card(icon: Texture2D, tint: Color = Color.WHITE) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", item_card_box())
	card.custom_minimum_size = Vector2(0, ITEM_CARD_HEIGHT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var image := make_bare_icon(icon, ITEM_ICON)
	image.modulate = tint
	row.add_child(image)
	# Текст — за відсіком, а не на ньому (по 16 дає й separation ряду).
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(ITEM_ICON_GAP - 32, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	return card

## Слот під іконку (зброя в арсеналі, здібність) — кольорове тло в рамці.
## accent — свій відтінок слота (колір прийому, зброї), як у зразку, де
## кожен предмет спорядження сидить у слоті свого кольору.
static func slot_box(accent: Color = Color.WHITE) -> StyleBox:
	var box := _texture_box("slot.png", 20, 8, 8)
	if box is StyleBoxTexture:
		(box as StyleBoxTexture).modulate_color = accent
	return box

## Панель поверх гри (здоров'я, золото в місті): та сама рамка, але
## тонші поля й прозоріша — щоб не затуляти бій.
static func hud_box() -> StyleBox:
	var box := _texture_box("panel.png", 34, 14, 10)
	if box is StyleBoxTexture:
		(box as StyleBoxTexture).modulate_color = Color(1, 1, 1, 0.88)
	return box

## Текст просто поверх 3D-сцени — з темним контуром, щоб читався і на
## світлій траві, і на вогні.
static func hud_text(label: Label, font_size: int = 18, color: Color = TEXT) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)

## Колір валюти — для числа поруч з іконкою й облямівки плашки.
static func currency_color(kind: StringName) -> Color:
	return GEM if kind == &"gem" else GOLD

## Число валюти розрядами: "134 056", а не "134056" — велике золото
## читається з першого погляду.
static func format_amount(value: int) -> String:
	var digits := str(absi(value))
	var groups := PackedStringArray()
	while digits.length() > 3:
		groups.insert(0, digits.right(3))
		digits = digits.left(digits.length() - 3)
	groups.insert(0, digits)
	return ("-" if value < 0 else "") + " ".join(groups)

## Квадратна кнопка з білою іконкою набору (пауза, меню). Поля рамки
## тонші, ніж у текстових кнопок, — інакше іконка не влізе.
static func make_icon_button(icon_name: String, side: float = 56.0, tooltip: String = "") -> Button:
	var button := Button.new()
	button.icon = control_icon(icon_name)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(side, side)
	button.tooltip_text = tooltip
	for state: String in ["normal", "hover", "pressed"]:
		var file := "button.png" if state == "normal" else "button_%s.png" % state
		button.add_theme_stylebox_override(state, _texture_box(file, 16, 13, 13))
	return button

## Смуга (здоров'я, досвід) у кольорі fill.
static func make_bar(fill: Color, bar_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = bar_size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_box := make_box(fill, 3)
	fill_box.content_margin_left = 0
	fill_box.content_margin_right = 0
	fill_box.content_margin_top = 0
	fill_box.content_margin_bottom = 0
	bar.add_theme_stylebox_override("fill", fill_box)
	var back := make_box(Color(0, 0, 0, 0.55), 3, 1, Color(LINE, 0.55))
	back.content_margin_left = 0
	back.content_margin_right = 0
	back.content_margin_top = 0
	back.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", back)
	return bar

## Заголовок на кольоровій плашці-пігулці — як "Hero49.Darkest Dungeon" у
## зразку. Повертає PanelContainer; сам напис — його прямий (єдиний)
## нащадок-Label, тож "for child in title.get_children(): if child is
## Label" і далі працює як раніше.
static func make_title(text: String, font_size: int = 26, color: Color = HEADING) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", _texture_box("title_pill.png", 22, 26, 8))
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", font(800))
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(label)
	return pill

## Кнопка з намальованою текстурою (арт гравця) — 9-slice: кути margin_x ×
## margin_y не тягнуться. Наведена — трохи світліша, натиснута — темніша;
## вимкнена — окрема сіра текстура (disabled_path) або та сама, притемнена.
## margin_right — інший правий край (кнопка "Меню": ліворуч ширша частина
## з рисками); -1 — як лівий. Немає файла — кнопка лишається в темі.
static func art_button(button: Button, path: String, margin_x: int, margin_y: int, disabled_path: String = "", margin_right: int = -1) -> void:
	if not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path)
	var tints := {"normal": Color.WHITE, "hover": Color(1.12, 1.12, 1.12), "pressed": Color(0.78, 0.78, 0.78)}
	for state: String in tints:
		var box := _art_box(texture, margin_x, margin_y, margin_right)
		box.modulate_color = tints[state]
		button.add_theme_stylebox_override(state, box)
	var disabled_texture := texture
	var disabled_tint := Color(0.55, 0.55, 0.58)
	if disabled_path != "" and ResourceLoader.exists(disabled_path):
		disabled_texture = load(disabled_path)
		disabled_tint = Color.WHITE
	var disabled_box := _art_box(disabled_texture, margin_x, margin_y, margin_right)
	disabled_box.modulate_color = disabled_tint
	button.add_theme_stylebox_override("disabled", disabled_box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", font(800))
	for state: String in ["font_color", "font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.72))
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	button.add_theme_constant_override("outline_size", 6)

## Кнопки з арту гравця (Зала героїв): зелена з золотими рунами — головна
## дія екрана ("Обрати", "Грати", "Забрати"), синя зі сріблом — решта
## ("Назад", "Магазин"). Зеленій нижче ~50 px кути вже не влізуть.
const ART_PRIMARY := THEME_DIR + "button_hero_select.png"
const ART_PRIMARY_DISABLED := THEME_DIR + "button_hero_select_disabled.png"
const ART_SECONDARY := THEME_DIR + "button_hero_back.png"

static func art_primary(button: Button) -> void:
	art_button(button, ART_PRIMARY, 27, 23, ART_PRIMARY_DISABLED)

static func art_secondary(button: Button) -> void:
	art_button(button, ART_SECONDARY, 13, 10)

## Тло екрана з арту гравця: перша наявна картинка зі списку (своя для
## екрана, далі запасні), обрізана під екран. dim — наскільки притемнити
## (меню на світлому тлі читається гірше). Кладе першими нащадками
## parent, щоб усе інше малювалося поверх.
static func add_background(parent: Control, paths: Array, dim: float = 0.0) -> void:
	var base := ColorRect.new()
	base.color = BG_DARK
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(base)
	parent.move_child(base, 0)
	for path: String in paths:
		if not ResourceLoader.exists(path):
			continue
		var art := TextureRect.new()
		art.texture = load(path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(art)
		parent.move_child(art, 1)
		if dim > 0.0:
			var shade := ColorRect.new()
			shade.color = Color(0.02, 0.01, 0.05, dim)
			shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(shade)
			parent.move_child(shade, 2)
		return

static func _art_box(texture: Texture2D, margin_x: int, margin_y: int, margin_right: int = -1) -> StyleBoxTexture:
	var right := margin_x if margin_right < 0 else margin_right
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = margin_x
	box.texture_margin_right = right
	box.texture_margin_top = margin_y
	box.texture_margin_bottom = margin_y
	box.content_margin_left = margin_x + 6
	box.content_margin_right = right + 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box

## Головна дія екрана — світла кнопка з темним текстом ("Грати",
## "Увійти", "Обрати").
static func make_primary(button: Button) -> void:
	button.theme_type_variation = &"PrimaryButton"

## Біла іконка з набору мобільного керування (assets/ui/controls/icon_*.png)
## — для кнопок бою й там, де своєї картинки ще немає.
static func control_icon(name: String) -> Texture2D:
	var path := "res://assets/ui/controls/icon_%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null

## Картинка в слоті з рамкою (як предмет в інвентарі). tint — колір
## білої іконки-запаски.
static func make_slot(texture: Texture2D, side: float = 52.0, tint: Color = Color.WHITE) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.add_theme_stylebox_override("panel", slot_box())
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var image := TextureRect.new()
	image.texture = texture
	image.custom_minimum_size = Vector2(side, side)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = tint
	slot.add_child(image)
	return slot

## Сама картинка, без рамки-слота: для готового арту (здібність, талант,
## товар) рамка лише забруднює малюнок — досить показати його трохи
## більшим, ніж був у слоті. Для заглушки (own_icon == null на виклику)
## і далі краще make_slot — порожня фігурка без тла губиться на екрані.
static func make_bare_icon(texture: Texture2D, side: float = 64.0) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.custom_minimum_size = Vector2(side, side)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return image

## Заокруглення кутів картинки в картці вибору — частка її сторони. Те
## саме число йде і в шейдер-маску, і в кільце, щоб краї збігались.
const PICKER_CORNER := 0.2
## Глянцеву рамку-слот прибрано: готовий арт (портрет, данж) у ній
## виглядав як фото, вклеєне в коробку. Тепер картинка сама обрізана по
## заокруглених кутах, а навколо — лише тонке кільце кольору предмета.
const ROUNDED_ART_SHADER := """
shader_type canvas_item;
uniform float corner = 0.2;
void fragment() {
	vec2 q = abs(UV - 0.5) - (0.5 - corner);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
	float aa = max(fwidth(d), 0.0001);
	COLOR.a *= 1.0 - smoothstep(-aa, aa, d);
}
"""

static var _rounded_art_material: ShaderMaterial

## Один матеріал на всі картки: шейдер компілюється раз, а не на кожну.
static func rounded_art_material() -> ShaderMaterial:
	if _rounded_art_material == null:
		var shader := Shader.new()
		shader.code = ROUNDED_ART_SHADER
		_rounded_art_material = ShaderMaterial.new()
		_rounded_art_material.shader = shader
		_rounded_art_material.set_shader_parameter("corner", PICKER_CORNER)
	return _rounded_art_material

## КАРТКА ВИБОРУ (герой, зброя, рівень данжу). full_bleed — картинка на
## всю картку (портрет зі своїм тлом); інакше — трохи всередині, на темній
## підкладці (зброя чи данж на прозорому тлі не мають "висіти в повітрі").
##
## Кнопки в горизонтальному ScrollContainer за замовчуванням ковтають
## колесо миші й перетягування (Control.mouse_filter = STOP), і прокрутка
## працює лише в порожньому місці збоку. tag_scroll_pass() лікує це:
## робить кнопку й усе всередині "прозорими" для прокрутки, лишаючи клік.
static func make_picker_slot(texture: Texture2D, tint: Color, side: float = 84.0, full_bleed: bool = false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(side, side)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.toggle_mode = true
	button.flat = true
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	var plate := Panel.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(plate)

	var image := TextureRect.new()
	image.name = "Image"
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if full_bleed:
		image.material = rounded_art_material()
	else:
		var inset := roundf(side * 0.1)
		image.offset_left = inset
		image.offset_top = inset
		image.offset_right = -inset
		image.offset_bottom = -inset
	image.set_meta(&"tint", tint)
	image.modulate = tint
	button.add_child(image)

	var ring := Panel.new()
	ring.name = "Ring"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(ring)

	var lock := TextureRect.new()
	lock.name = "Lock"
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.texture = control_icon("lock")
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var lock_half := side * 0.2
	lock.offset_left = -lock_half
	lock.offset_top = -lock_half
	lock.offset_right = lock_half
	lock.offset_bottom = lock_half
	lock.modulate = Color(1, 1, 1, 0.9)
	lock.visible = false
	button.add_child(lock)

	tag_scroll_pass(button)
	return button

## Стан картки: обрана — яскрава, з товстішим кільцем свого кольору й
## сяйвом довкола; не обрана — притемнена, кільце ледь видно; закрита
## (не куплена / не пройдена) — темна, сіре кільце й замок посередині.
static func style_picker_slot(button: Button, selected: bool, available: bool, own_color: Color) -> void:
	var side := button.custom_minimum_size.x
	var radius := int(side * PICKER_CORNER)
	var image := button.get_node("Image") as TextureRect
	var tint: Color = image.get_meta(&"tint", Color.WHITE)

	var plate_box := StyleBoxFlat.new()
	plate_box.bg_color = Color(0.09, 0.08, 0.17, 0.95)
	plate_box.set_corner_radius_all(radius)
	plate_box.anti_aliasing = true
	if selected and available:
		plate_box.shadow_color = Color(own_color, 0.6)
		plate_box.shadow_size = 10
	(button.get_node("Plate") as Panel).add_theme_stylebox_override("panel", plate_box)

	var ring_box := StyleBoxFlat.new()
	ring_box.draw_center = false
	ring_box.set_corner_radius_all(radius)
	ring_box.anti_aliasing = true
	if not available:
		ring_box.border_color = Color(0.55, 0.55, 0.6, 0.45)
		ring_box.set_border_width_all(2)
	elif selected:
		ring_box.border_color = own_color.lerp(Color.WHITE, 0.35)
		ring_box.set_border_width_all(4)
	else:
		ring_box.border_color = Color(own_color, 0.45)
		ring_box.set_border_width_all(2)
	(button.get_node("Ring") as Panel).add_theme_stylebox_override("panel", ring_box)

	if not available:
		image.modulate = tint * Color(0.32, 0.32, 0.36)
	elif selected:
		image.modulate = tint
	else:
		image.modulate = tint * Color(0.62, 0.62, 0.68)
	(button.get_node("Lock") as TextureRect).visible = not available
	button.modulate = Color.WHITE

## Ряд карток, що гортається вбік (герої, зброя, рівні данжу). Повертає
## {scroll, row}: додавай картки в row, а коли розмір відомий — гортай
## scroll_to_center(scroll, обрана_картка). Поки картки вміщаються, ряд
## стоїть посередині; відступи довкола — щоб сяйво обраної не обрізалось.
static func make_picker_row() -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 108)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(row)
	return {"scroll": scroll, "row": row}

## Прогорнути так, щоб item опинився посередині scroll. Розмір контейнера
## відомий лише після розкладки, тож клич це через call_deferred.
static func scroll_to_center(scroll: ScrollContainer, item: Control) -> void:
	var row := item.get_parent() as Control
	var x := item.position.x + row.position.x
	scroll.scroll_horizontal = int(x - scroll.size.x * 0.5 + item.size.x * 0.5)

## Позначає вузол і все під ним "прозорим" для прокрутки (PASS): клік і
## наведення далі працюють, а колесо миші й перетягування, які цей вузол
## сам не використав, ідуть далі — до ScrollContainer над ним. Без цього
## прокрутка горизонтального ряду слотів ловиться лише в порожньому
## місці збоку, а не над самими іконками.
static func tag_scroll_pass(node: Control) -> void:
	if node.mouse_filter == Control.MOUSE_FILTER_STOP:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		if child is Control:
			tag_scroll_pass(child as Control)

## Обгорнути вже наявний вузол екрана (заголовок, опис) плашкою-пігулкою
## — не перебудовуючи сцену.
static func add_dividers(label: Control) -> PanelContainer:
	var parent := label.get_parent()
	var index := label.get_index()
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", _texture_box("title_pill.png", 22, 26, 8))
	parent.remove_child(label)
	pill.add_child(label)
	parent.add_child(pill)
	parent.move_child(pill, index)
	return pill

## Покласти кілька сусідніх вузлів екрана на одну панель у рамці.
static func wrap_in_panel(nodes: Array[Control], accent: Color = Color.WHITE) -> PanelContainer:
	var parent := nodes[0].get_parent()
	var index := nodes[0].get_index()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_box(accent))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	for node in nodes:
		parent.remove_child(node)
		column.add_child(node)
	parent.add_child(panel)
	parent.move_child(panel, index)
	return panel

## Текстура з рамкою, що тягнеться лише серединою (кути лишаються як є).
static func _texture_box(file: String, margin: int, content_h: int, content_v: int) -> StyleBox:
	var path := THEME_DIR + file
	if not ResourceLoader.exists(path):
		var flat := make_box(PANEL, 6, 2, LINE)
		flat.content_margin_left = content_h
		flat.content_margin_right = content_h
		flat.content_margin_top = content_v
		flat.content_margin_bottom = content_v
		return flat
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = content_h
	box.content_margin_right = content_h
	box.content_margin_top = content_v
	box.content_margin_bottom = content_v
	return box

func _build_theme() -> Theme:
	var new_theme := Theme.new()
	new_theme.default_font_size = 18
	new_theme.default_font = font(700)

	# --- кнопки: округлі, градієнт, товста рамка, глянець і тінь ---
	new_theme.set_stylebox("normal", "Button", _texture_box("button.png", 16, 22, 12))
	new_theme.set_stylebox("hover", "Button", _texture_box("button_hover.png", 16, 22, 12))
	new_theme.set_stylebox("pressed", "Button", _texture_box("button_pressed.png", 16, 22, 12))
	new_theme.set_stylebox("disabled", "Button", _texture_box("button_disabled.png", 16, 22, 12))
	new_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	new_theme.set_color("font_color", "Button", TEXT)
	new_theme.set_color("font_hover_color", "Button", Color.WHITE)
	new_theme.set_color("font_pressed_color", "Button", TEXT_DIM)
	new_theme.set_color("font_focus_color", "Button", TEXT)
	# Вимкнена кнопка ("У руках", "Обрано") — сіра, але напис мусить читатись.
	new_theme.set_color("font_disabled_color", "Button", Color(0.86, 0.86, 0.92, 0.85))
	new_theme.set_font("font", "Button", font(800))
	new_theme.set_font_size("font_size", "Button", 18)

	# --- головна кнопка: зелена, текст білий ---
	new_theme.set_type_variation(&"PrimaryButton", &"Button")
	new_theme.set_stylebox("normal", "PrimaryButton", _texture_box("button_primary.png", 16, 22, 12))
	new_theme.set_stylebox("hover", "PrimaryButton", _texture_box("button_primary_hover.png", 16, 22, 12))
	new_theme.set_stylebox("pressed", "PrimaryButton", _texture_box("button_primary_pressed.png", 16, 22, 12))
	new_theme.set_color("font_color", "PrimaryButton", Color.WHITE)
	new_theme.set_color("font_hover_color", "PrimaryButton", Color.WHITE)
	new_theme.set_color("font_pressed_color", "PrimaryButton", Color(1, 1, 1, 0.82))
	new_theme.set_color("font_focus_color", "PrimaryButton", Color.WHITE)

	# --- панелі ---
	new_theme.set_stylebox("panel", "PanelContainer", panel_box())
	new_theme.set_stylebox("panel", "Panel", panel_box())

	# --- текст ---
	new_theme.set_color("font_color", "Label", TEXT)
	new_theme.set_font("font", "Label", font(700))
	new_theme.set_font_size("font_size", "Label", 18)

	# --- прокрутка: тонка кремова смужка замість сірої ---
	var grabber := make_box(Color(LINE, 0.55), 3)
	grabber.content_margin_left = 3
	grabber.content_margin_right = 3
	new_theme.set_stylebox("grabber", "VScrollBar", grabber)
	new_theme.set_stylebox("grabber_highlight", "VScrollBar", make_box(LINE, 3))
	new_theme.set_stylebox("grabber_pressed", "VScrollBar", make_box(Color.WHITE, 3))
	var track := make_box(Color(0, 0, 0, 0.25), 3)
	track.content_margin_left = 3
	track.content_margin_right = 3
	new_theme.set_stylebox("scroll", "VScrollBar", track)

	# --- смуги прогресу (здоров'я, досвід, заряд уміння) ---
	new_theme.set_stylebox("background", "ProgressBar", make_box(Color(0, 0, 0, 0.45), 4, 1, Color(LINE, 0.5)))
	new_theme.set_stylebox("fill", "ProgressBar", make_box(HEADING, 4))
	new_theme.set_color("font_color", "ProgressBar", TEXT)

	return new_theme

## Курсор миші на ПК — піксельне лезо, над кнопками — рука з пальцем
## (Kenney Cursor Pixel Pack). На телефоні миші немає — нічого не робимо.
func _setup_cursors() -> void:
	if OS.has_feature("mobile"):
		return
	var blade_path := CURSOR_DIR + "cursor_blade.png"
	var hand_path := CURSOR_DIR + "cursor_hand.png"
	if ResourceLoader.exists(blade_path):
		Input.set_custom_mouse_cursor(load(blade_path), Input.CURSOR_ARROW, Vector2(2, 1))
	if ResourceLoader.exists(hand_path):
		Input.set_custom_mouse_cursor(load(hand_path), Input.CURSOR_POINTING_HAND, Vector2(11, 1))
		get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
