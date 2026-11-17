extends HeroSkill3D

## ПРИМАРНА ЗГРАЯ (Фенрір): два примарні вовки 8 секунд кидаються на
## ворогів поруч і кусають.

const LIFE := 8.0
const BITE_GAP := 0.7
const BITE := 0.6
const SEEK := 8.0

var _wolves: Array = []
var _left := 0.0

func _init() -> void:
	id = &"spirit_pack"
	title = "Примарна зграя"
	description = "Кличеш двох примарних вовків — 8 секунд вони кидаються на ворогів поруч."
	color = Color(0.5, 0.95, 0.9)
	icon_kind = "dash"
	cooldown = 16.0

func _use(player: Node) -> bool:
	_clear()
	var parent: Node = player.get_parent()
	for side: float in [-1.0, 1.0]:
		var wolf: Node3D = player.call("_build_form_model", &"fenrir")
		wolf.scale *= 0.6
		parent.add_child(wolf)
		wolf.global_position = player.global_position + Vector3(side * 1.4, 0, 0)
		for anim: AnimationPlayer in wolf.find_children("*", "AnimationPlayer", true, false):
			if anim.has_animation("Gallop"):
				anim.play("Gallop")
		Fx.puff(parent, wolf.global_position + Vector3.UP * 0.4, color, 1.0, 0.0)
		_wolves.append([wolf, randf() * BITE_GAP])
	_left = LIFE
	return true

func _update(player: Node, delta: float) -> void:
	if _wolves.is_empty():
		return
	_left -= delta
	if _left <= 0.0:
		_clear()
		return
	for entry: Array in _wolves:
		var wolf: Node3D = entry[0]
		if not is_instance_valid(wolf):
			continue
		var target: Enemy3D = null
		var best := SEEK
		for enemy: Enemy3D in player.enemies_near(wolf.global_position, SEEK):
			var d := enemy.global_position.distance_to(wolf.global_position)
			if d < best:
				best = d
				target = enemy
		var goal: Vector3 = target.global_position if target != null else player.global_position + Vector3(1.2, 0, 1.2)
		var to := goal - wolf.global_position
		to.y = 0.0
		if to.length() > 1.1:
			wolf.global_position += to.normalized() * minf(to.length() - 1.0, 11.0 * delta)
			wolf.rotation.y = atan2(to.x, to.z)
		entry[1] = float(entry[1]) - delta
		if target != null and best < 1.8 and float(entry[1]) <= 0.0:
			entry[1] = BITE_GAP
			player.deal_damage(target, BITE, to.normalized() * 0.8, false, id)

func _clear() -> void:
	for entry: Array in _wolves:
		var wolf: Node3D = entry[0]
		if is_instance_valid(wolf):
			Fx.puff(wolf.get_parent(), wolf.global_position + Vector3.UP * 0.4, color, 0.8, 0.0)
			wolf.queue_free()
	_wolves.clear()
