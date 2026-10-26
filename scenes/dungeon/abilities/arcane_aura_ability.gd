extends EnemyAbility

## КРИЖАНА АУРА (Інейна чаклунка, як Arcane Aura у Crystal Maiden): поки
## чаклунка в бою, союзники поруч заряджають удари й прийоми швидше на
## bonus (частка). Під нею — бліде рунне коло. Ще одна причина вбити її
## першою.
##
## Налаштування: radius, bonus.

const COLOR := Color(0.55, 0.85, 1.0, 0.5)
const STEP := 0.5

var _step_left := STEP
var _marker: MeshInstance3D

func _init() -> void:
	id = "arcane_aura"
	cooldown = 9999.0

func tick(delta: float) -> void:
	super.tick(delta)
	_step_left -= delta
	if _step_left > 0.0:
		return
	_step_left = STEP
	var active := bool(enemy.get("_aggro"))
	_show(active)
	if not active:
		return
	var bonus := STEP * float(config.get("bonus", 0.3))
	var radius := float(config.get("radius", 8.0))
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var ally := node as Enemy3D
		if ally == null or ally == enemy or not ally.is_alive() or ally.kind == Enemy3D.Kind.BOSS:
			continue
		if ally.global_position.distance_squared_to(enemy.global_position) > radius * radius:
			continue
		ally.set("_attack_left", float(ally.get("_attack_left")) - bonus)
		for ability in ally.abilities:
			ability.tick(bonus)

func _show(on: bool) -> void:
	if on and _marker == null:
		_marker = CombatVfx.make_ground_marker(COLOR, 0.9)
		_marker.set_instance_shader_parameter(&"progress", 1.0)
		enemy.add_child(_marker)
		_marker.position = Vector3(0, 0.05, 0)
		var spin := _marker.create_tween().set_loops()
		spin.tween_property(_marker, "rotation:y", TAU, 6.0).from(0.0)
	if _marker != null and is_instance_valid(_marker):
		_marker.visible = on

func on_death() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
