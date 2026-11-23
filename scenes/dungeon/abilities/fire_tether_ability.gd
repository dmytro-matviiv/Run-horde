extends EnemyAbility

## ВОГНЯНИЙ ЛАНЦЮГ (Жерці Полум'я — ходять парами). Між двома жерцями
## ближче за range натягнуто ланцюг полум'я. Хто його перетинає чи стоїть
## на ньому — щоevery секунд горить. Жерці кружляють, і ланцюг мете по
## залі. Убий одного — ланцюг згасне.
## Налаштування: range, width, every, damage.

const COLOR := Color(1.0, 0.45, 0.1)

var _partner: Enemy3D
var _beam: MeshInstance3D
var _burn_left := 0.0
var _look_left := 0.0

func _init() -> void:
	id = "fire_tether"
	cooldown = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = 0.5
		_find_partner()
	if _partner == null or not is_instance_valid(_partner) or not _partner.is_alive() \
			or _partner.global_position.distance_to(enemy.global_position) > float(config.get("range", 10.0)):
		_partner = null
		_hide()
		return
	var a := enemy.global_position + Vector3.UP * 1.0
	var b := _partner.global_position + Vector3.UP * 1.0
	_show(a, b)
	_burn_left -= delta
	var hero := player()
	if hero == null or not is_instance_valid(hero) or _burn_left > 0.0:
		return
	var p := hero.global_position + Vector3.UP * 1.0
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
	var flat := p - (a + ab * t)
	flat.y = 0.0
	if flat.length() <= float(config.get("width", 0.55)):
		_burn_left = float(config.get("every", 0.4))
		if hero.take_damage(damage()):
			CombatVfx.impact(world(), p, COLOR, false)

## Пару тримає той, у кого менший id (щоб ланцюг був один).
func _find_partner() -> void:
	var best: Enemy3D = null
	var best_d := float(config.get("range", 10.0))
	for node in enemy.get_parent().get_children():
		var other := node as Enemy3D
		if other == null or other == enemy or not other.is_alive():
			continue
		var has := false
		for ability in other.abilities:
			if ability.id == id:
				has = true
				break
		if not has:
			continue
		var d := other.global_position.distance_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = other
	_partner = best if best != null and enemy.get_instance_id() < best.get_instance_id() else null

func _show(a: Vector3, b: Vector3) -> void:
	if _beam == null:
		_beam = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.14, 0.14, 1.0)
		_beam.mesh = box
		_beam.material_override = CombatVfx.get_glow_material(COLOR)
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world().add_child(_beam)
	_beam.visible = true
	var length := maxf(a.distance_to(b), 0.05)
	_beam.global_position = (a + b) * 0.5
	if length > 0.06:
		_beam.look_at((a + b) * 0.5 + (b - a), Vector3.UP)
	_beam.scale = Vector3(1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.02), 1.0, length)

func _hide() -> void:
	if _beam != null and is_instance_valid(_beam):
		_beam.visible = false

func on_death() -> void:
	if _beam != null and is_instance_valid(_beam):
		_beam.queue_free()
	_beam = null
