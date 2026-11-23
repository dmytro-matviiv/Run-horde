extends EnemyAbility

## СФЕРИ ВІРНОСТІ (Безликий Бог). По залі розсипаються count золотих
## сфер. Герой торкнувся сфери — вона б'є Бога (hurt від його здоров'я).
## Бог підійшов до сфери — вона його лікує (heal). Що лишилося за time
## секунд — летить до Бога й лікує його. Хто швидший — той і виграв.
## Налаштування: count, near/far (м від Бога), time, hurt, heal.

const COLOR := Color(1.0, 0.85, 0.35)
const TOUCH := 0.9

var _orbs: Array = []
var _time_left := 0.0

func _init() -> void:
	id = "devotion_orbs"
	cooldown = 22.0

func try_use(_distance: float) -> bool:
	if _time_left > 0.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.8)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	_clear()
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	mesh.radial_segments = 10
	mesh.rings = 5
	var count := int(config.get("count", 4))
	var start := randf() * TAU
	for i in count:
		var angle := start + TAU * i / count + randf_range(-0.3, 0.3)
		var spot := enemy.global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(float(config.get("near", 4.0)), float(config.get("far", 7.0)))
		spot.y = DungeonBuilder.FLOOR_TOP
		var orb := MeshInstance3D.new()
		orb.mesh = mesh
		orb.material_override = CombatVfx.get_glow_material(COLOR)
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var motes := CombatVfx.make_motes(COLOR, 8, 0.3, 0.6, 0.05)
		orb.add_child(motes)
		world().add_child(orb)
		orb.global_position = spot + Vector3.UP * 0.6
		_orbs.append(orb)
	_time_left = float(config.get("time", 10.0))

func tick(delta: float) -> void:
	super.tick(delta)
	if _time_left <= 0.0:
		return
	_time_left -= delta
	var hero := player()
	for i in range(_orbs.size() - 1, -1, -1):
		var orb: MeshInstance3D = _orbs[i]
		orb.position.y += sin(Time.get_ticks_msec() * 0.004 + i) * delta * 0.3
		var flat := func(a: Vector3, b: Vector3) -> float:
			return Vector2(a.x - b.x, a.z - b.z).length()
		if hero != null and is_instance_valid(hero) and flat.call(hero.global_position, orb.global_position) <= TOUCH:
			_orbs.remove_at(i)
			CombatVfx.glow_orb(world(), orb.global_position, enemy, enemy.target_height * 0.6, COLOR, 0.35)
			CombatVfx.impact(world(), enemy.global_position + Vector3.UP * enemy.target_height * 0.6, COLOR, true)
			enemy.take_damage(enemy.max_hp * float(config.get("hurt", 0.04)), Vector3.ZERO, false, true)
			orb.queue_free()
		elif flat.call(enemy.global_position, orb.global_position) <= TOUCH + 0.8:
			_orbs.remove_at(i)
			_feed(orb)
	if _time_left <= 0.0 or _orbs.is_empty():
		for orb: MeshInstance3D in _orbs:
			_feed(orb)
		_orbs.clear()
		_time_left = 0.0

func _feed(orb: MeshInstance3D) -> void:
	CombatVfx.glow_orb(world(), orb.global_position, enemy, enemy.target_height * 0.6, COLOR.lerp(Color.WHITE, 0.4), 0.45)
	enemy.heal(enemy.max_hp * float(config.get("heal", 0.04)))
	orb.queue_free()

func remaining() -> int:
	return _orbs.size()

func on_death() -> void:
	_clear()

func _clear() -> void:
	for orb in _orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	_orbs.clear()
	_time_left = 0.0
