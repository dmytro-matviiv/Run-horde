extends Control
class_name OrnateDialog

## Вікно поверх екрана (опис здібності, нагорода за відсутність) у
## різьбленій рамці гравця (OrnatePanel): тло притемнене, угорі іконка й
## назва з ярликом виду ("Здібність", "Пасивна риса"), під ними — золота
## риска, далі вміст (body — додавай туди що завгодно або add_text), унизу
## кнопки з арту гравця: зелена — головна дія, синя — решта.
## Натиск повз рамку закриває вікно, якщо closable.
##
##   var dialog := OrnateDialog.new("Фенікс", icon, color, 560.0, "Пасивна риса")
##   dialog.add_text("Раз за похід рятує від смерті.")
##   dialog.add_button("Зрозуміло")
##   add_child(dialog)

signal closed

const TITLE_COLOR := Color(1.0, 0.86, 0.5)
const TEXT_COLOR := Color(0.97, 0.95, 0.9)

var body: VBoxContainer
var closable := true
var _buttons: HBoxContainer

func _init(title: String, icon: Texture2D = null, accent: Color = UiTheme.GOLD, width: float = 560.0, tag: String = "") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := OrnatePanel.new()
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	if icon != null:
		header.add_child(UiTheme.make_bare_icon(icon, 72.0))
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 4)
	header.add_child(titles)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", UiTheme.font(900))
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", accent.lerp(TITLE_COLOR, 0.55))
	title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.1, 0.9))
	title_label.add_theme_constant_override("outline_size", 6)
	if icon == null:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(title_label)
	if tag != "":
		titles.add_child(make_tag(tag, accent))

	column.add_child(_make_divider())
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	column.add_child(body)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 14)
	column.add_child(_buttons)

## Абзац тексту — світлий, жирний, з легким контуром: читається на рамці.
func add_text(text: String, font_size: int = 18, color: Color = TEXT_COLOR, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", UiTheme.font(700))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("outline_size", 3)
	body.add_child(label)
	return label

## Кнопка внизу. Без on_press — просто закриває вікно.
func add_button(text: String, primary: bool = true, on_press: Callable = Callable()) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 56 if primary else 50)
	button.add_theme_font_size_override("font_size", 20 if primary else 18)
	if primary:
		UiTheme.art_primary(button)
	else:
		UiTheme.art_secondary(button)
	button.pressed.connect(on_press if on_press.is_valid() else close)
	_buttons.add_child(button)
	return button

func close() -> void:
	closed.emit()
	queue_free()

func _on_dim_input(event: InputEvent) -> void:
	if closable and event is InputEventMouseButton and event.pressed:
		close()

## Ярлик ("Пасивна риса", "У руках") — пігулка з облямівкою свого кольору.
static func make_tag(text: String, accent: Color) -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var box := UiTheme.make_box(Color(accent, 0.18), 9, 1, Color(accent, 0.75))
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 1
	box.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiTheme.font(800))
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.5))
	pill.add_child(label)
	return pill

## Тонка золота риска між заголовком і вмістом, що тане до країв.
func _make_divider() -> Control:
	var line := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(1, 0.8, 0.45, 0.0), Color(1, 0.8, 0.45, 0.75), Color(1, 0.8, 0.45, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 2
	line.texture = texture
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line
