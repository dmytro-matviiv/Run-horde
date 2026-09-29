extends EnemyAbility

## ОБЕРІГ: тотем тягне світні нитки до найближчих ворогів — поки нитка
## тримається, ворог майже не отримує шкоди ("factor" — частка шкоди,
## що проходить). Тотем стоїть на місці й сам не б'є: його треба
## розбити першим. З "target": "boss" — це пілон, що береже боса
## (factor 0 — повна невразливість).

const REFRESH := 0.25
const COLOR := Color(0.55, 0.85, 1.0)

var _refresh_left := 0.0
var _links: Array[Enemy3D] = []
var _beams: Array[MeshInstance3D] = []

func _init() -> void:
	id = "ward"
	cooldown = 0.0

func tick(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH
		_relink()
	_draw_beams()

func _relink() -> void:
	var factor := float(config.get("factor", 0.2))
	var reach := float(config.get("range", 8.0))
	var boss_only := String(config.get("target", "")) == "boss"
	var candidates: Array[Enemy3D] = []
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or other == enemy or not other.is_aim_target() or other.stationary:
			continue
		if boss_only != (other.kind == Enemy3D.Kind.BOSS):
			continue
		if other.global_position.distance_to(enemy.global_position) <= reach:
			candidates.append(other)
	candidates.sort_custom(func(a: Enemy3D, b: Enemy3D) -> bool:
		return a.global_position.distance_to(enemy.global_position) < b.global_position.distance_to(enemy.global_position))
	_links = candidates.slice(0, int(config.get("links", 3)))
	for other in _links:
		other.apply_ward(factor, REFRESH * 2.0)

## Нитки від тотема до кожного, кого він береже.
func _draw_beams() -> void:
	var color: Color = config.get("color", COLOR)
	while _beams.size() < _links.size():
		var beam := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		beam.mesh = mesh
		beam.material_override = CombatVfx.get_glow_material(color)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.top_level = true
		enemy.add_child(beam)
		_beams.append(beam)
	var from := enemy.global_position + Vector3.UP * enemy.target_height * 0.85
	for i in _beams.size():
		var beam := _beams[i]
		if i >= _links.size() or not is_instance_valid(_links[i]) or not _links[i].is_alive():
			beam.visible = false
			continue
		var to := _links[i].global_position + Vector3.UP * _links[i].target_height * 0.6
		var length := from.distance_to(to)
		if length < 0.1:
			beam.visible = false
			continue
		beam.visible = true
		beam.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP).scaled(Vector3(0.07, 0.07, length)),
			from.lerp(to, 0.5))

func on_death() -> void:
	for beam in _beams:
		if is_instance_valid(beam):
			beam.queue_free()
	_beams.clear()
	_links.clear()
