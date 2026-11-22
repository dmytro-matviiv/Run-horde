extends EnemyAbility

## ВІДЛУННЯ (Володар Рун). Від героя відокремлюється тінь і біжить ЙОГО
## Ж слідом із запізненням delay секунд, time секунд поспіль. Тінь
## наздогнала (герой зупинився чи повернув назад на свій слід) — удар
## (damage) і тінь зникає. Рятує одне: не стояти й не кружляти.

const COLOR := Color(0.45, 0.2, 0.8)
const SAMPLE := 0.05
const TOUCH := 0.75

var _trail: Array = []
var _left_time := 0.0
var _sample_left := 0.0
var _shadow: Node3D
var _index := 0

func _init() -> void:
	id = "echo"
	cooldown = 16.0

func try_use(_distance: float) -> bool:
	if _left_time > 0.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.6)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_trail.clear()
	_left_time = float(config.get("time", 8.0)) + float(config.get("delay", 1.2))
	_index = 0
	_shadow = Node3D.new()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	capsule.radial_segments = 10
	capsule.rings = 3
	body.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.04, 0.22, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = COLOR
	mat.emission_energy_multiplier = 0.6
	mat.rim_enabled = true
	body.material_override = mat
	body.position = Vector3.UP * 0.85
	_shadow.add_child(body)
	var wisps := CombatVfx.make_trail(COLOR, 0.5)
	wisps.amount = 14
	_shadow.add_child(wisps)
	wisps.position = Vector3.UP * 0.9
	world().add_child(_shadow)
	_shadow.global_position = hero.global_position
	_shadow.visible = false
	CombatVfx.shockwave(world(), hero.global_position, 1.4, COLOR, 0.35)

func tick(delta: float) -> void:
	super.tick(delta)
	if _left_time <= 0.0:
		return
	_left_time -= delta
	var hero := player()
	if hero == null or not is_instance_valid(hero) or _shadow == null or not is_instance_valid(_shadow):
		_stop()
		return
	_sample_left -= delta
	if _sample_left <= 0.0:
		_sample_left = SAMPLE
		_trail.append(hero.global_position)
	var lag := int(float(config.get("delay", 1.2)) / SAMPLE)
	if _trail.size() > lag:
		_shadow.visible = true
		var spot: Vector3 = _trail[_trail.size() - 1 - lag]
		var step := spot - _shadow.global_position
		step.y = 0.0
		if step.length() > 0.01:
			_shadow.look_at(_shadow.global_position + step, Vector3.UP)
		_shadow.global_position = spot
		var offset := hero.global_position - _shadow.global_position
		offset.y = 0.0
		if offset.length() <= TOUCH and hero.take_damage(damage()):
			CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, true)
			_stop()
			return
	if _left_time <= 0.0:
		_stop()

func on_death() -> void:
	_stop()

func _stop() -> void:
	_left_time = 0.0
	if _shadow != null and is_instance_valid(_shadow):
		CombatVfx.smoke_puff(world(), _shadow.global_position + Vector3.UP, COLOR, 1.0)
		_shadow.queue_free()
	_shadow = null
	_trail.clear()
