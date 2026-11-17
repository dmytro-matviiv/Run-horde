extends HeroSkill3D

## ВІЯЛО СТРІЛ (Лучник): дев'ять стріл віялом уперед — косить натовп.

const ARROWS := 9
const SPREAD_DEG := 70.0
const DAMAGE := 0.7
const SPEED := 40.0

func _init() -> void:
	id = &"arrow_volley"
	title = "Віяло стріл"
	description = "Дев'ять стріл віялом уперед: кожна ранить ворога на своєму шляху."
	color = Color(0.95, 0.8, 0.4)
	icon_kind = "gun"
	cooldown = 7.0

func _use(player: Node) -> bool:
	var direction: Vector3 = player.facing_vector()
	var target: Node = player.get("_target")
	if is_instance_valid(target) and target is Enemy3D:
		var to: Vector3 = (target as Enemy3D).global_position - player.global_position
		to.y = 0.0
		if to.length() > 0.05:
			direction = to.normalized()
			player.face_direction(direction)
	var parent: Node = player.get_parent()
	# Стріли злітають із лука й плавно опускаються до висоти грудей на
	# відстані кількох кроків — як звичайний постріл: низьку перешкоду
	# перелітають, низьких ворогів зачіпають.
	var origin: Vector3 = player.spell_origin()
	var drop: float = (player.global_position.y + 0.8) - origin.y
	var reach := 6.0
	if is_instance_valid(target) and target is Enemy3D:
		reach = clampf((target as Enemy3D).global_position.distance_to(player.global_position), 1.5, 6.0)
	for i in ARROWS:
		var angle := deg_to_rad(lerpf(-SPREAD_DEG * 0.5, SPREAD_DEG * 0.5, float(i) / float(ARROWS - 1)))
		var arrow := PlayerProjectile.create(player, DAMAGE, color, 1.6)
		parent.add_child(arrow)
		var flat := direction.rotated(Vector3.UP, angle)
		arrow.launch(origin, (flat * reach + Vector3.UP * drop).normalized(), SPEED)
	player.play_clip("OverhandThrow")
	player.shake_camera(0.05)
	return true
