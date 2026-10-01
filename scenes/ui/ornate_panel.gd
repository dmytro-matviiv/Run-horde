extends PanelContainer
class_name OrnatePanel

## Панель опису з різьбленою рамкою (золоті кути з рунами, вензель
## зверху, ромбик знизу) — арт гравця. Рамка тягнеться 9-slice, а
## центральні прикраси малюються окремо, по центру й у своєму розмірі:
## якби вони були частиною рамки, на широкій панелі їх розмазало б.
## Немає файлів — звичайна панель теми.

const FRAME_PATH := "res://assets/ui/theme/ornate_panel.png"
const TOP_PATH := "res://assets/ui/theme/ornate_panel_top.png"
const BOTTOM_PATH := "res://assets/ui/theme/ornate_panel_bottom.png"
## Кути з рунами займають ~42 px текстури — поле 9-slice трохи більше.
const FRAME_MARGIN := 46
## Вензель виступає над верхнім краєм рамки, ромбик стоїть над нижнім.
const TOP_RISE := 14.0
const BOTTOM_LIFT := 20.0

var _top: Texture2D
var _bottom: Texture2D

func _init() -> void:
	if not ResourceLoader.exists(FRAME_PATH):
		add_theme_stylebox_override("panel", UiTheme.panel_box())
		return
	var box := StyleBoxTexture.new()
	box.texture = load(FRAME_PATH)
	box.texture_margin_left = FRAME_MARGIN
	box.texture_margin_right = FRAME_MARGIN
	box.texture_margin_top = FRAME_MARGIN
	box.texture_margin_bottom = FRAME_MARGIN
	box.content_margin_left = 44
	box.content_margin_right = 44
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	add_theme_stylebox_override("panel", box)
	if ResourceLoader.exists(TOP_PATH):
		_top = load(TOP_PATH)
	if ResourceLoader.exists(BOTTOM_PATH):
		_bottom = load(BOTTOM_PATH)
	resized.connect(queue_redraw)

func _draw() -> void:
	if _top != null:
		draw_texture(_top, Vector2(roundf((size.x - _top.get_width()) * 0.5), -TOP_RISE))
	if _bottom != null:
		draw_texture(_bottom, Vector2(roundf((size.x - _bottom.get_width()) * 0.5), size.y - BOTTOM_LIFT))
