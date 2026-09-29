extends Node

## Єдине оформлення всіх екранів. Тема будується кодом і вішається на
## корінь дерева сцен — звідти Godot роздає її всім вікнам і кнопкам
## автоматично, тож кожен екран не мусить знати про стилі нічого.
##
## СТИЛЬ — фентезійні рамки Kenney (Fantasy UI Borders, CC0): темні
## напівпрозорі панелі з тонкою кремовою рамкою й візерунчастими кутами,
## кнопки з квадратиками на кутах, головна дія — світла кнопка з темним
## текстом, заголовки — блідо-зелені між розділювачами з руків'ям меча.
## Текстури лежать в assets/ui/theme (їх збирає скрипт build_ui_theme.py з
## білих рамок набору). Немає файла — лишається проста плоска рамка.

# Палітра: темний сланець, кремові лінії, блідо-зелені заголовки.
const BG_DARK := Color(0.055, 0.06, 0.09)
const PANEL := Color(0.086, 0.106, 0.125)
const PANEL_LIGHT := Color(0.13, 0.155, 0.18)
const ACCENT := Color(0.98, 0.72, 0.25)
const ACCENT_DARK := Color(0.72, 0.5, 0.14)
const HEADING := Color(0.68, 0.84, 0.52)
const LINE := Color(0.91, 0.89, 0.84)
const TEXT := Color(0.94, 0.93, 0.89)
const TEXT_DIM := Color(0.64, 0.66, 0.68)
const TEXT_DARK := Color(0.1, 0.11, 0.12)
const GOLD := Color(1.0, 0.86, 0.4)
const GEM := Color(0.55, 0.9, 1.0)
const DANGER := Color(0.95, 0.4, 0.4)

const THEME_DIR := "res://assets/ui/theme/"
const CURSOR_DIR := "res://assets/ui/cursors/"

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
	var box := _texture_box("panel.png", 14, 22, 16)
	if box is StyleBoxTexture:
		(box as StyleBoxTexture).modulate_color = accent
	return box

## Слот під іконку (зброя в арсеналі, здібність) — сіре тло в рамці.
static func slot_box() -> StyleBox:
	return _texture_box("slot.png", 14, 8, 8)

## Панель поверх гри (здоров'я, золото в місті): та сама рамка, але
## тонші поля й прозоріша — щоб не затуляти бій.
static func hud_box() -> StyleBox:
	var box := _texture_box("panel.png", 14, 14, 10)
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
		button.add_theme_stylebox_override(state, _texture_box(file, 12, 13, 13))
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

## Заголовок між двома розділювачами з руків'ям меча — як "Location
## discovered" у зразку. Повертає готовий рядок для контейнера.
static func make_title(text: String, font_size: int = 26, color: Color = HEADING) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var left := _divider(true)
	if left != null:
		row.add_child(left)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(label)
	var right := _divider(false)
	if right != null:
		row.add_child(right)
	return row

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

## СЛОТ ВИБОРУ (герой, зброя, рівень данжу) — квадратна кнопка-іконка в
## рамці, як предмет в інвентарі зі зразка Kenney. Обраний слот світиться
## акцентним кільцем; некуплений/непройдений — приглушений.
##
## Кнопки в горизонтальному ScrollContainer за замовчуванням ковтають
## колесо миші й перетягування (Control.mouse_filter = STOP), і прокрутка
## працює лише в порожньому місці збоку. tag_scroll_pass() лікує це:
## робить кнопку й усе всередині "прозорими" для прокрutki, лишаючи клік.
static func make_picker_slot(texture: Texture2D, tint: Color, side: float = 84.0) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(side, side)
	button.toggle_mode = true
	button.flat = true
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var slot := PanelContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", slot_box())
	slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(slot)
	var image := TextureRect.new()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = tint
	slot.add_child(image)
	tag_scroll_pass(button)
	return button

## Підсвітка слота: акцентне кільце навколо обраного, приглушення
## некупленого/непройденого. own_color — рамка слота саме цього предмета
## (зброя героя, колір рівня), сіра — коли він ще не доступний.
static func style_picker_slot(button: Button, selected: bool, available: bool, own_color: Color) -> void:
	var slot := button.get_child(0) as PanelContainer
	var accent := own_color if available else Color(0.45, 0.45, 0.48)
	if selected:
		accent = accent.lerp(Color.WHITE, 0.4)
	var box := slot_box()
	if box is StyleBoxTexture:
		(box as StyleBoxTexture).modulate_color = accent
	slot.add_theme_stylebox_override("panel", box)
	(slot.get_child(0) as TextureRect).modulate = Color.WHITE if available else Color(1, 1, 1, 0.55)
	button.modulate = Color(1.08, 1.08, 1.08) if selected else Color(0.86, 0.86, 0.86)

## Ряд слотів, що гортається вбік (герої, зброя, рівні данжу). Повертає
## {scroll, row}: додавай слоти в row, а коли розмір відомий — гортай
## scroll_to_center(scroll, обраний_слот).
static func make_picker_row() -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 100)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	return {"scroll": scroll, "row": row}

## Прогорнути так, щоб item опинився посередині scroll. Розмір контейнера
## відомий лише після розкладки, тож клич це через call_deferred.
static func scroll_to_center(scroll: ScrollContainer, item: Control) -> void:
	scroll.scroll_horizontal = int(item.position.x - scroll.size.x * 0.5 + item.size.x * 0.5)

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

## Обгорнути вже наявний вузол екрана (заголовок, опис) розділювачами
## обабіч — не перебудовуючи сцену.
static func add_dividers(label: Control) -> HBoxContainer:
	var parent := label.get_parent()
	var index := label.get_index()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	parent.remove_child(label)
	var left := _divider(true)
	if left != null:
		row.add_child(left)
	row.add_child(label)
	var right := _divider(false)
	if right != null:
		row.add_child(right)
	parent.add_child(row)
	parent.move_child(row, index)
	return row

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

static func _divider(mirrored: bool) -> TextureRect:
	var path := THEME_DIR + "divider.png"
	if not ResourceLoader.exists(path):
		return null
	var divider := TextureRect.new()
	divider.texture = load(path)
	divider.flip_h = mirrored
	divider.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.custom_minimum_size = Vector2(96, 22)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider

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

	# --- кнопки: темні з кремовою рамкою й квадратиками на кутах ---
	new_theme.set_stylebox("normal", "Button", _texture_box("button.png", 12, 16, 8))
	new_theme.set_stylebox("hover", "Button", _texture_box("button_hover.png", 12, 16, 8))
	new_theme.set_stylebox("pressed", "Button", _texture_box("button_pressed.png", 12, 16, 8))
	new_theme.set_stylebox("disabled", "Button", _texture_box("button_disabled.png", 12, 16, 8))
	new_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	new_theme.set_color("font_color", "Button", TEXT)
	new_theme.set_color("font_hover_color", "Button", Color.WHITE)
	new_theme.set_color("font_pressed_color", "Button", LINE.darkened(0.15))
	new_theme.set_color("font_focus_color", "Button", TEXT)
	new_theme.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.2))
	new_theme.set_font_size("font_size", "Button", 18)

	# --- головна кнопка: світла, текст темний ---
	new_theme.set_type_variation(&"PrimaryButton", &"Button")
	new_theme.set_stylebox("normal", "PrimaryButton", _texture_box("button_primary.png", 12, 16, 8))
	new_theme.set_stylebox("hover", "PrimaryButton", _texture_box("button_primary_hover.png", 12, 16, 8))
	new_theme.set_stylebox("pressed", "PrimaryButton", _texture_box("button_primary_pressed.png", 12, 16, 8))
	new_theme.set_color("font_color", "PrimaryButton", TEXT_DARK)
	new_theme.set_color("font_hover_color", "PrimaryButton", Color.BLACK)
	new_theme.set_color("font_pressed_color", "PrimaryButton", TEXT_DARK)
	new_theme.set_color("font_focus_color", "PrimaryButton", TEXT_DARK)

	# --- панелі ---
	new_theme.set_stylebox("panel", "PanelContainer", panel_box())
	new_theme.set_stylebox("panel", "Panel", panel_box())

	# --- текст ---
	new_theme.set_color("font_color", "Label", TEXT)
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
