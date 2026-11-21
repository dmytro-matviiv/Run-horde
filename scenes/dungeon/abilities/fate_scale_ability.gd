extends EnemyAbility

## ВАГИ РОЗПЛАТИ (ідол, Скарбниця Тіней). Вороги в радіусі range пов'язані
## золотими нитками: удар по будь-кому з них ділиться порівну між усіма
## пов'язаними (Enemy3D.fate_scale). Одного не добити — б'єш усю купу
## потроху. Розбий ваги — нитки рвуться. Сам ідол шкоду не ділить.

const COLOR := Color(1.0, 0.82, 0.3)
const RELINK := 0.4

var _linked: Array = []
var _threads := {}
var _relink_left := 0.0
var _sharing := false

func _init() -> void:
	id = "fate_scale"
	cooldown = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	if not enemy.is_alive():
		return
	_relink_left -= delta
	if _relink_left <= 0.0:
		_relink_left = RELINK
		_relink()
	_draw_threads()

func _relink() -> void:
	var radius := float(config.get("range", 7.0))
	var fresh: Array = []
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or other == enemy or not other.is_alive() or other.kind == Enemy3D.Kind.BOSS:
			continue
		if other.global_position.distance_to(enemy.global_position) <= radius:
			fresh.append(other)
	for other: Enemy3D in _linked:
		if not fresh.has(other) and is_instance_valid(other) and other.fate_scale == self:
			other.fate_scale = null
	for other: Enemy3D in fresh:
		other.fate_scale = self
	_linked = fresh

## Удар по пов'язаному: йому — лише його частка, решта — іншим.
func share(target: Enemy3D, amount: float) -> float:
	if _sharing:
		return amount
	var group: Array = _linked.filter(func(e: Enemy3D) -> bool: return is_instance_valid(e) and e.is_alive())
	if group.size() <= 1 or not group.has(target):
		return amount
	var part := amount / group.size()
	_sharing = true
	for other: Enemy3D in group:
		if other != target:
			other.take_damage(part)
	_sharing = false
	return part

func _draw_threads() -> void:
	var top := enemy.global_position + Vector3.UP * enemy.target_height * 0.8
	for other in _threads.keys():
		if not _linked.has(other) or not is_instance_valid(other):
			if is_instance_valid(_threads[other]):
				_threads[other].queue_free()
			_threads.erase(other)
	for other: Enemy3D in _linked:
		if not is_instance_valid(other):
			continue
		var thread: MeshInstance3D = _threads.get(other)
		if thread == null or not is_instance_valid(thread):
			thread = MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.04, 0.04, 1.0)
			thread.mesh = box
			thread.material_override = CombatVfx.get_glow_material(COLOR)
			thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world().add_child(thread)
			_threads[other] = thread
		var to := other.global_position + Vector3.UP * other.target_height * 0.6
		var span := to - top
		thread.global_position = top + span * 0.5
		if span.length() > 0.05:
			thread.look_at(to, Vector3.UP)
		thread.scale = Vector3(1.0, 1.0, maxf(span.length(), 0.05))

func on_death() -> void:
	for other: Enemy3D in _linked:
		if is_instance_valid(other) and other.fate_scale == self:
			other.fate_scale = null
	_linked.clear()
	for thread in _threads.values():
		if is_instance_valid(thread):
			thread.queue_free()
	_threads.clear()
	CombatVfx.shockwave(world(), enemy.global_position, 3.0, COLOR, 0.4)
