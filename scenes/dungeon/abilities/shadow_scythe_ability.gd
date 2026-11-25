extends EnemyAbility

## СЕРП ТІНІ (Тіньовий Володар, фаза 2). Кидає серп-півмісяць туди, де
## герой, і далі на reach метрів; серп крутиться й повертається до
## Володаря. Ранить і туди, і назад — після першого проходу не стій на
## лінії між ним і Володарем.
## Налаштування: reach, speed, damage.

const SHADOW := Color(0.12, 0.1, 0.1)

var _blade: Node3D
var _out := true
var _target := Vector3.ZERO
var _hit_left := 0.0

func _init() -> void:
	id = "shadow_scythe"
	cooldown = 7.0

func try_use(distance: float) -> bool:
	if _blade != null or distance < 3.0 or not enemy.sees_player():
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.5)), Color(SHADOW, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var dir := hero.global_position - enemy.global_position
	dir.y = 0.0
	dir = dir.normalized()
	_target = enemy.global_position + dir * float(config.get("reach", 11.0))
	_blade = Node3D.new()
	# Півмісяць: тор, розрізаний навпіл (половина кільця) і сплющений.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.8
	ring.rings = 16
	ring.ring_segments = 4
	var mesh := MeshInstance3D.new()
	mesh.mesh = ring
	mesh.material_override = BossFx.ghost_material(Color(1.0, 0.8, 0.45), Color(0.04, 0.03, 0.03, 0.95))
	mesh.scale = Vector3(1.0, 0.25, 1.0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade.add_child(mesh)
	var trail := CombatVfx.make_trail(SHADOW, 0.4)
	trail.amount = 14
	_blade.add_child(trail)
	world().add_child(_blade)
	_blade.global_position = enemy.global_position + Vector3.UP * 1.2
	_out = true
	_hit_left = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	if _blade == null or not is_instance_valid(_blade):
		_blade = null
		return
	_blade.rotation.y += delta * 18.0
	var goal := _target + Vector3.UP * 1.2 if _out else enemy.global_position + Vector3.UP * 1.2
	var step := float(config.get("speed", 13.0)) * delta
	var to := goal - _blade.global_position
	if to.length() <= step:
		_blade.global_position = goal
		if _out:
			_out = false
			_hit_left = 0.0
		else:
			_blade.queue_free()
			_blade = null
			return
	else:
		_blade.global_position += to.normalized() * step
	_hit_left -= delta
	var hero := player()
	if hero != null and is_instance_valid(hero) and _hit_left <= 0.0:
		if (hero.global_position + Vector3.UP * 1.0).distance_to(_blade.global_position) < 1.1:
			_hit_left = 0.8
			if hero.take_damage(damage()):
				CombatVfx.impact(world(), hero.global_position + Vector3.UP, SHADOW, true)

func on_death() -> void:
	if _blade != null and is_instance_valid(_blade):
		_blade.queue_free()
	_blade = null
