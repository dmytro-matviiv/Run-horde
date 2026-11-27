extends EnemyAbility

## ВСЕЛЕННЯ (Привид бога). Привид летить у найближчого союзника (ближче за
## range) і вселяється: привид зникає, а одержимий світиться блакитним,
## б'є в power разів сильніше й бігає в haste разів швидше. Убий
## одержимого — привид вилетить і буде вразливий, поки не знайде нового.
## Налаштування: range, power, haste, rest (с після вигнання).

const COLOR := Color(0.55, 0.95, 1.0)

var _host: Enemy3D
var _overlay: StandardMaterial3D

func _init() -> void:
	id = "possess"
	cooldown = 6.0

func try_use(_distance: float) -> bool:
	if _host != null:
		return false
	var best: Enemy3D = null
	var best_d := float(config.get("range", 9.0))
	for node in enemy.get_parent().get_children():
		var other := node as Enemy3D
		if other == null or other == enemy or not other.is_alive() or other.stationary \
				or other.kind == Enemy3D.Kind.BOSS or other.has_meta("possessed"):
			continue
		var has_self := false
		for ability in other.abilities:
			if ability.id == id:
				has_self = true
		if has_self:
			continue
		var d := other.global_position.distance_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = other
	if best == null:
		return false
	start_cooldown()
	_enter(best)
	return true

func _enter(host: Enemy3D) -> void:
	_host = host
	host.set_meta("possessed", true)
	CombatVfx.glow_orb(world(), enemy.global_position + Vector3.UP * enemy.target_height * 0.5, host, host.target_height * 0.6, COLOR, 0.35)
	host.damage *= float(config.get("power", 1.5))
	host.move_speed *= float(config.get("haste", 1.3))
	if _overlay == null:
		_overlay = StandardMaterial3D.new()
		_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_overlay.albedo_color = Color(COLOR, 0.35)
	for node in CombatVfx.body_meshes(host._model):
		(node as GeometryInstance3D).material_overlay = _overlay
	host.died.connect(_on_host_died, CONNECT_ONE_SHOT)
	enemy.visible = false
	enemy.invulnerable = true
	enemy.untargetable = true
	enemy.collision_layer = 0

func is_busy() -> bool:
	return _host != null

func tick(delta: float) -> void:
	super.tick(delta)
	if _host == null:
		return
	if not is_instance_valid(_host) or not _host.is_alive():
		_leave(enemy.global_position)
		return
	enemy.global_position = _host.global_position

func _on_host_died(position: Vector3, _xp: int) -> void:
	_leave(position)

func _leave(position: Vector3) -> void:
	if _host == null:
		return
	_host = null
	if not is_instance_valid(enemy) or not enemy.is_alive():
		return
	enemy.global_position = position + Vector3.UP * 0.2
	enemy.visible = true
	enemy.invulnerable = false
	enemy.untargetable = false
	enemy.collision_layer = 4
	_left = float(config.get("rest", 5.0))
	CombatVfx.smoke_puff(world(), position + Vector3.UP, COLOR, 1.4)

func on_death() -> void:
	if _host != null and is_instance_valid(_host):
		_host.remove_meta("possessed")
	_host = null
