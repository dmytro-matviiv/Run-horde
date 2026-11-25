extends EnemyAbility

## РИВОК З ТІНІ (Тіньовий Володар) — проти втечі. Герой далі за min —
## Володар розчиняється в диму, по підлозі до героя тягнеться темна смуга
## (windup), і він вилітає з тіні просто перед героєм із ударом. Тікати
## й стріляти вже не вийде: ухиляйся вбік від смуги.
## Налаштування: min, windup, damage.

const SHADOW := Color(0.08, 0.07, 0.08)

var _strip: MeshInstance3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _dir := Vector3.FORWARD
var _dash_left := -1.0
var _windup := 0.55

func _init() -> void:
	id = "shadow_dash"
	cooldown = 5.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 6.0)) or _dash_left > 0.0:
		return false
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return false
	start_cooldown()
	_windup = float(config.get("windup", 0.55))
	_from = enemy.global_position
	var to := hero.global_position - _from
	to.y = 0.0
	_dir = to.normalized()
	# Вилітає за 1.4 м до героя — по прямій, тож убік можна ухилитись.
	_to = _from + _dir * maxf(to.length() - 1.4, 0.5)
	var length := _from.distance_to(_to)
	_strip = BossFx.floor_plane(BossFx.smoke_material(), Vector2(1.1, length))
	(_strip.material_override as ShaderMaterial).set_shader_parameter(&"alpha", 0.0)
	world().add_child(_strip)
	_strip.global_position = Vector3(_from.x, DungeonBuilder.FLOOR_TOP + 0.04, _from.z) + _dir * length * 0.5
	_strip.rotation.y = atan2(_dir.x, _dir.z)
	CombatVfx.smoke_puff(world(), _from + Vector3.UP * 1.2, SHADOW, 1.6)
	enemy.face_point(hero.global_position)
	enemy.begin_special(id, _windup, Color(SHADOW, 0.0), 0.1)
	_dash_left = _windup
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	if _dash_left > 0.0:
		_dash_left -= delta
		if _strip != null and is_instance_valid(_strip):
			(_strip.material_override as ShaderMaterial).set_shader_parameter(&"alpha", clampf(1.0 - _dash_left / _windup, 0.0, 1.0))
	elif _strip != null:
		# Ривок збили (оглушення) — смуга не висить.
		_dash_left -= delta
		if _dash_left < -0.6:
			_clear()

func resolve() -> void:
	_dash_left = -1.0
	_clear()
	enemy.teleport_to(Vector3(_to.x, enemy.global_position.y, _to.z))
	CombatVfx.smoke_puff(world(), _to + Vector3.UP * 1.0, SHADOW, 1.8)
	BossFx.shadow_burst(world(), _to)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	# Удар по смузі: хто лишився на шляху ривку чи поруч із точкою виходу.
	var off := hero.global_position - _from
	off.y = 0.0
	var along := off.dot(_dir)
	var side := (off - _dir * along).length()
	var near_end := Vector2(hero.global_position.x - _to.x, hero.global_position.z - _to.z).length() < 2.0
	if (along > 0.0 and along < _from.distance_to(_to) + 1.6 and side < 1.0) or near_end:
		if hero.take_damage(damage()):
			CombatVfx.impact(world(), hero.global_position + Vector3.UP, SHADOW, true)
	enemy.face_point(hero.global_position)

func on_death() -> void:
	_clear()

func _clear() -> void:
	if _strip != null and is_instance_valid(_strip):
		_strip.queue_free()
	_strip = null
