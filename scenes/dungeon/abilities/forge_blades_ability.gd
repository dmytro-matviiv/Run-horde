extends EnemyAbility

## КУВАННЯ КЛИНКІВ (Володар Горна). Бос двічі б'є молотом по ковадлу — і
## з горна вилітають count розпечених мечів. hunt секунд вони повільно
## полюють на героя (ріжуть при дотику), потім встромляються в підлогу й
## ще stuck секунд печуть усе поруч — зала потроху стає тіснішою.
## Налаштування: count, hunt, stuck, speed, damage (частка за дотик).

const COLOR := Color(1.0, 0.55, 0.15)
const TOUCH := 0.8
const TOUCH_GAP := 0.8

class Blade extends Node3D:
	var hunt_left := 4.0
	var stuck_left := 5.0
	var speed := 4.2
	var hit_damage := 10.0
	var target: Node3D
	var wait := 0.0
	var _blade: Node3D
	var _lift := 0.0

	func _ready() -> void:
		_blade = Node3D.new()
		add_child(_blade)
		# Розжарений меч горна: клинок із лави, сталева гарда й руків'я.
		# Вістрям донизу (модель — вістрям уздовж -Z, повертаємо).
		var sword := BossFx.forge_blade()
		sword.rotation.x = -PI * 0.5
		sword.position.y = 0.2
		_blade.add_child(sword)
		var trail := CombatVfx.make_trail(Color(1.0, 0.6, 0.2), 0.4)
		trail.amount = 10
		_blade.add_child(trail)

	func _physics_process(delta: float) -> void:
		wait -= delta
		if hunt_left > 0.0:
			hunt_left -= delta
			_lift = minf(_lift + delta * 3.0, 1.0)
			if target != null and is_instance_valid(target):
				var to := target.global_position - global_position
				to.y = 0.0
				if to.length() > 0.1:
					global_position += to.normalized() * speed * delta
				_blade.rotation.y += delta * 9.0
			position.y = DungeonBuilder.FLOOR_TOP + 0.6 + 0.4 * _lift
			if hunt_left <= 0.0:
				# Встромляється в підлогу вістрям униз.
				_blade.rotation.y = 0.0
				position.y = DungeonBuilder.FLOOR_TOP + 0.55
				CombatVfx.impact(get_parent(), global_position, COLOR, false)
		else:
			stuck_left -= delta
			if stuck_left <= 0.0:
				queue_free()
				return
		_touch()

	func _touch() -> void:
		if wait > 0.0 or target == null or not is_instance_valid(target):
			return
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() <= TOUCH and target.take_damage(hit_damage):
			wait = TOUCH_GAP
			CombatVfx.impact(get_parent(), target.global_position + Vector3.UP, COLOR, false)

func _init() -> void:
	id = "forge_blades"
	cooldown = 13.0

func try_use(_distance: float) -> bool:
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 1.1)), Color(COLOR, 0.6), 2.0)
	return true

func resolve() -> void:
	var count := int(config.get("count", 3)) + (1 if enemy.phases != null and enemy.phases.phase >= 2 else 0)
	var forward := enemy.model_forward()
	for i in count:
		var blade := Blade.new()
		blade.hunt_left = float(config.get("hunt", 4.0)) + i * 0.3
		blade.stuck_left = float(config.get("stuck", 5.0))
		blade.speed = float(config.get("speed", 4.2))
		blade.hit_damage = damage()
		blade.target = player()
		world().add_child(blade)
		var angle := (i - (count - 1) * 0.5) * 0.9
		blade.global_position = enemy.global_position + forward.rotated(Vector3.UP, angle) * 1.6 + Vector3.UP * 0.6
	CombatVfx.shockwave(world(), enemy.global_position + forward * 1.2, 2.0, COLOR, 0.35)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.15)
