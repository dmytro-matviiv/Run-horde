extends Control
class_name WeaponIcon

## Квадратик зброї в арсеналі — місце під картинку. Коли в описі зброї
## з'явиться намальована іконка (WeaponDef.icon), вона стане тут
## автоматично. Поки її немає, малюємо рамку й символ за архетипом:
## гравець одразу бачить, ЯК б'є зброя, навіть без арту.

const SIZE := 96.0

var _def: WeaponDef
var _owned := true

func setup(def: WeaponDef, owned: bool) -> void:
	_def = def
	_owned = owned
	custom_minimum_size = Vector2(SIZE, SIZE)
	queue_redraw()

func _draw() -> void:
	if _def == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var color := _def.color
	if not _owned:
		# Некуплена зброя — приглушена, як замок на вітрині.
		color = color.darkened(0.45)

	# Підкладка й рамка — "картка" під картинку.
	draw_rect(rect, Color(color.r, color.g, color.b, 0.12), true)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.75), false, 2.0)

	if _def.icon != null:
		var texture_size := _def.icon.get_size()
		var scale_factor := minf(size.x / texture_size.x, size.y / texture_size.y) * 0.86
		var draw_size := texture_size * scale_factor
		draw_texture_rect(_def.icon, Rect2((size - draw_size) * 0.5, draw_size), false,
			Color(1, 1, 1, 1.0 if _owned else 0.55))
		return

	_draw_archetype_symbol(size * 0.5, minf(size.x, size.y) * 0.3, color)

## Символ за тим, ЯК зброя атакує: постріл, вибух, конус, замах,
## ланцюг, вихор чи зона на землі.
func _draw_archetype_symbol(center: Vector2, radius: float, color: Color) -> void:
	match _def.archetype:
		"projectile":
			draw_line(center + Vector2(-radius, 0), center + Vector2(radius * 0.4, 0), color, 4.0)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(radius * 0.4, -radius * 0.5),
				center + Vector2(radius, 0),
				center + Vector2(radius * 0.4, radius * 0.5),
			]), color)
		"aoe_projectile":
			draw_arc(center, radius, 0.0, TAU, 28, color, 3.0)
			draw_circle(center, radius * 0.45, color)
		"cone":
			var points := PackedVector2Array([center + Vector2(-radius, 0)])
			for i in 9:
				var angle := lerpf(-0.6, 0.6, float(i) / 8.0)
				points.append(center + Vector2(-radius, 0) + Vector2(cos(angle), sin(angle)) * radius * 2.0)
			draw_colored_polygon(points, color)
		"melee_arc":
			draw_arc(center, radius, -0.9, 0.9, 20, color, 5.0)
			draw_line(center + Vector2(-radius * 0.2, 0), center + Vector2(radius * 0.8, 0), color, 3.0)
		"chain":
			draw_line(center + Vector2(-radius, radius * 0.4), center + Vector2(-radius * 0.2, -radius * 0.3), color, 3.0)
			draw_line(center + Vector2(-radius * 0.2, -radius * 0.3), center + Vector2(radius * 0.2, radius * 0.2), color, 3.0)
			draw_line(center + Vector2(radius * 0.2, radius * 0.2), center + Vector2(radius, -radius * 0.5), color, 3.0)
		"orbit_storm":
			draw_arc(center, radius, 0.0, TAU, 28, Color(color.r, color.g, color.b, 0.5), 2.0)
			for i in 3:
				var angle := TAU / 3.0 * i
				draw_circle(center + Vector2(cos(angle), sin(angle)) * radius, radius * 0.22, color)
		"ground_zone":
			draw_set_transform(center, 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.45))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, color, 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			draw_circle(center, radius * 0.6, color)
