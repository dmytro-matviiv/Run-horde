extends EnemyAbility

## ПОСИЛЕННЯ (Кістяний тотем): тягне зелені нитки до ворогів довкола — поки
## нитка тримається, ворог б'є сильніше (bonus) і потроху лікується (regen —
## частка здоров'я за секунду). Сам тотем не б'є: розбий його першим.
##
## Налаштування: radius, bonus (множник шкоди), regen, links (скільки ниток).

const REFRESH := 0.5
const COLOR := Color(0.45, 1.0, 0.45)

var _refresh_left := 0.0
var _links: Array[Enemy3D] = []
var _beams: Array[MeshInstance3D] = []

func _init() -> void:
	id = "empower"
	cooldown = 0.0

func tick(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH
		_relink()
	_draw_beams()

func _relink() -> void:
	var reach := float(config.get("radius", 8.0))
	var candidates: Array[Enemy3D] = []
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or other == enemy or not other.is_alive() or other.stationary or other.kind == Enemy3D.Kind.BOSS:
			continue
		if other.global_position.distance_to(enemy.global_position) <= reach:
			candidates.append(other)
	candidates.sort_custom(func(a: Enemy3D, b: Enemy3D) -> bool:
		return a.global_position.distance_to(enemy.global_position) < b.global_position.distance_to(enemy.global_position))
	_links = candidates.slice(0, int(config.get("links", 6)))
	var bonus := float(config.get("bonus", 1.25))
	var regen := float(config.get("regen", 0.015))
	for other in _links:
		other.apply_empower(bonus, REFRESH * 2.0)
		if other.current_hp < other.max_hp:
			other.heal(other.max_hp * regen * REFRESH)

## Нитки від тотема до кожного, кого він посилює (ворог під землею —
## без нитки).
func _draw_beams() -> void:
	while _beams.size() < _links.size():
		var beam := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		beam.mesh = mesh
		beam.material_override = CombatVfx.get_glow_material(COLOR)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.top_level = true
		enemy.add_child(beam)
		_beams.append(beam)
	var from := enemy.global_position + Vector3.UP * enemy.target_height * 0.8
	for i in _beams.size():
		var beam := _beams[i]
		if i >= _links.size() or not is_instance_valid(_links[i]) or not _links[i].is_aim_target():
			beam.visible = false
			continue
		var to := _links[i].global_position + Vector3.UP * _links[i].target_height * 0.6
		var length := from.distance_to(to)
		if length < 0.1:
			beam.visible = false
			continue
		beam.visible = true
		beam.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP).scaled(Vector3(0.05, 0.05, length)),
			from.lerp(to, 0.5))

func on_death() -> void:
	for beam in _beams:
		if is_instance_valid(beam):
			beam.queue_free()
	_beams.clear()
	_links.clear()
