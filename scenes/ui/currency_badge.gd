extends PanelContainer
class_name CurrencyBadge

## Валюта — іконка з арту гравця (монета з короною чи фіолетовий гем) і
## число поруч. Однакова на всіх екранах: меню, Зала героїв, Збройня,
## Храм, Ринок, місто. Сигналу про зміну золота немає — число оновлює сам
## екран через set_amount() там, де раніше писав "Золото: N" текстом.
## backing = false — без плашки (у вікні нагороди, в HUD бою).

var _label: Label

func _init(kind: StringName = &"gold", font_size: int = 18, backing: bool = true) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var accent := UiTheme.currency_color(kind)
	if backing:
		# Сливова плашка в золотому канті (kit/nine/pill).
		var box := UiTheme.nine_box("pill.png", 20, 20, 16, 4)
		box.content_margin_left = 6
		box.content_margin_right = 18
		add_theme_stylebox_override("panel", box)
	else:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var icon := TextureRect.new()
	icon.texture = ArtSlots.currency_icon(kind)
	icon.custom_minimum_size = Vector2.ONE * roundf(font_size * 1.6)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	_label = Label.new()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", UiTheme.font(800))
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.3))
	_label.add_theme_color_override("font_outline_color", UiTheme.OUTLINE)
	_label.add_theme_constant_override("outline_size", 4)
	row.add_child(_label)

func set_amount(value: int) -> void:
	_label.text = UiTheme.format_amount(value)

## Довільний напис біля іконки ("+1 234", "×1.5").
func set_text(text: String) -> void:
	_label.text = text
