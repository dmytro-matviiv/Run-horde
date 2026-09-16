extends Node2D

## Зброя в руках героя. Потрібна для простої, але важливої речі: коли
## гравець міняє зброю в арсеналі, він має це БАЧИТИ в бою, а не лише
## відчувати за іншими цифрами.
##
## Якщо для зброї вже намальована іконка (WeaponDef.icon) — показуємо її.
## Поки іконки немає, малюємо фігуру за архетипом кольором зброї:
## посох — довгий держак із кулею, сокира — широке лезо, кинджали —
## короткі клинки. Силует різний, тож підміну видно одразу.

const HAND_DISTANCE := 26.0    # на якій відстані від героя тримається зброя
const SWING_TIME := 0.22
const SWING_ANGLE := 1.3       # розмах замаху, радіани
const ICON_HEIGHT := 34.0

@onready var icon_sprite: Sprite2D = $Icon

var _def: WeaponDef
var _aim := Vector2.RIGHT
var _swing_left := 0.0

func show_weapon(def: WeaponDef) -> void:
	_def = def
	if def.icon != null:
		icon_sprite.texture = def.icon
		icon_sprite.scale = Vector2.ONE * (ICON_HEIGHT / float(def.icon.get_height()))
		icon_sprite.visible = true
	else:
		icon_sprite.visible = false
	queue_redraw()

## Замах у бік цілі — викликає герой на кожен удар зброї.
func swing(aim: Vector2) -> void:
	_aim = aim.normalized()
	_swing_left = SWING_TIME

func _process(delta: float) -> void:
	if _def == null:
		return
	if _swing_left > 0.0:
		_swing_left -= delta
	# Зброя дивиться туди ж, куди б'є герой, і прокручується на замаху.
	var swing_progress := 1.0 - clampf(_swing_left / SWING_TIME, 0.0, 1.0)
	var swing_offset := sin(swing_progress * PI) * SWING_ANGLE if _swing_left > 0.0 else 0.0
	rotation = _aim.angle() + swing_offset
	position = Vector2(HAND_DISTANCE, 0).rotated(rotation)
	queue_redraw()

func _draw() -> void:
	if _def == null or icon_sprite.visible:
		return
	# Проста фігура за архетипом — тимчасова заміна намальованій іконці.
	var color := _def.color
	match _def.archetype:
		"melee_arc":
			draw_colored_polygon(PackedVector2Array([Vector2(-4, -3), Vector2(14, -14), Vector2(20, 0), Vector2(14, 14), Vector2(-4, 3)]), color)
		"cone", "aoe_projectile":
			draw_line(Vector2(-10, 0), Vector2(14, 0), color, 4.0)
			draw_circle(Vector2(16, 0), 7.0, color)
		"chain":
			draw_line(Vector2(-8, 0), Vector2(6, -5), color, 3.0)
			draw_line(Vector2(6, -5), Vector2(12, 4), color, 3.0)
			draw_line(Vector2(12, 4), Vector2(20, -2), color, 3.0)
		"orbit_storm":
			draw_colored_polygon(PackedVector2Array([Vector2(-2, -6), Vector2(16, 0), Vector2(-2, 6)]), color)
		"ground_zone":
			draw_line(Vector2(-10, 0), Vector2(12, 0), color, 4.0)
			draw_colored_polygon(PackedVector2Array([Vector2(12, -7), Vector2(20, 0), Vector2(12, 7)]), color)
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -3), Vector2(16, 0), Vector2(-6, 3)]), color)
