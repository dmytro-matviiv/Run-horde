extends Node

## Єдине оформлення всіх екранів. Тема будується кодом і вішається на
## корінь дерева сцен — звідти Godot роздає її всім вікнам і кнопкам
## автоматично, тож кожен екран не мусить знати про стилі нічого.
##
## Чому кодом, а не .tres: стилі тут — це десяток кольорів і радіусів,
## і правити їх числом у файлі значно легше, ніж клікати в редакторі
## по вкладених ресурсах.

# Палітра: темне підземелля + бурштиновий акцент (як золото в грі).
const BG_DARK := Color(0.055, 0.06, 0.09)
const PANEL := Color(0.105, 0.115, 0.16)
const PANEL_LIGHT := Color(0.15, 0.16, 0.22)
const ACCENT := Color(0.98, 0.72, 0.25)
const ACCENT_DARK := Color(0.72, 0.5, 0.14)
const TEXT := Color(0.94, 0.95, 1.0)
const TEXT_DIM := Color(0.66, 0.69, 0.8)
const GOLD := Color(1.0, 0.86, 0.4)
const GEM := Color(0.55, 0.9, 1.0)
const DANGER := Color(0.95, 0.4, 0.4)

var theme: Theme

func _ready() -> void:
	theme = _build_theme()
	# Тема на корені вікна — успадковується всіма екранами гри.
	get_tree().root.theme = theme

## Заготовка прямокутника зі скругленням — основа всіх кнопок і панелей.
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

func _build_theme() -> Theme:
	var new_theme := Theme.new()
	new_theme.default_font_size = 18

	# --- кнопки ---
	var normal := make_box(PANEL_LIGHT, 12, 2, Color(1, 1, 1, 0.07))
	var hover := make_box(PANEL_LIGHT.lightened(0.12), 12, 2, ACCENT_DARK)
	var pressed := make_box(PANEL_LIGHT.darkened(0.2), 12, 2, ACCENT)
	var disabled := make_box(PANEL.darkened(0.15), 12, 2, Color(1, 1, 1, 0.04))
	new_theme.set_stylebox("normal", "Button", normal)
	new_theme.set_stylebox("hover", "Button", hover)
	new_theme.set_stylebox("pressed", "Button", pressed)
	new_theme.set_stylebox("disabled", "Button", disabled)
	new_theme.set_stylebox("focus", "Button", make_box(Color.TRANSPARENT, 12, 2, ACCENT))
	new_theme.set_color("font_color", "Button", TEXT)
	new_theme.set_color("font_hover_color", "Button", Color.WHITE)
	new_theme.set_color("font_pressed_color", "Button", ACCENT)
	new_theme.set_color("font_disabled_color", "Button", Color(0.55, 0.57, 0.65))
	new_theme.set_font_size("font_size", "Button", 18)

	# --- панелі ---
	new_theme.set_stylebox("panel", "PanelContainer", make_box(PANEL, 14, 2, Color(1, 1, 1, 0.06)))
	new_theme.set_stylebox("panel", "Panel", make_box(PANEL, 14, 2, Color(1, 1, 1, 0.06)))

	# --- текст ---
	new_theme.set_color("font_color", "Label", TEXT)
	new_theme.set_font_size("font_size", "Label", 18)

	# --- смуги прогресу (здоров'я, досвід, заряд уміння) ---
	new_theme.set_stylebox("background", "ProgressBar", make_box(Color(0, 0, 0, 0.45), 8))
	new_theme.set_stylebox("fill", "ProgressBar", make_box(ACCENT, 8))
	new_theme.set_color("font_color", "ProgressBar", TEXT)

	return new_theme
