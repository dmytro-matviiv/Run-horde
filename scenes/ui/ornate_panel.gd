extends PanelContainer
class_name OrnatePanel

## Головна панель екрана («Рунічна казка»): зелене сукно в золотій рамі з
## орнаментом по кутах (UiTheme.panel_box). Ім'я класу лишилось від
## попереднього стилю — так його звуть усі екрани.

func _init() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel_box())
