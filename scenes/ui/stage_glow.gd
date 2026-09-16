extends Control

## Підсвітка під героєм на екрані вибору: м'яке коло й тінь під ногами.
## Малюється кодом — це дешевше за картинку й автоматично підлаштовується
## під розмір сцени на будь-якому екрані.

const RINGS := 7

@export var glow_color: Color = Color(0.45, 0.55, 1.0)

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.44
	# Кілька напівпрозорих кіл дають ефект сяйва без шейдерів.
	for i in RINGS:
		var t := float(i) / float(RINGS - 1)
		var color := glow_color
		color.a = 0.05 * (1.0 - t)
		draw_circle(center, radius * (0.45 + 0.75 * t), color)
	# Тінь-еліпс під ногами, щоб герой не "висів" у порожнечі.
	draw_set_transform(center + Vector2(0, radius * 0.72), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, radius * 0.55, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
