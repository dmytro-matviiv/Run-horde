extends EnemyAbility

## ОЖЕЛЕДЬ (Берсерк Півночі). Кожен його удар сокирою (влучив чи ні)
## лишає під собою пляму криги на life секунд (не більше max). Хто на
## кризі — того несе: розганяється й гальмує вдесятеро повільніше, тож
## ухилитись від наступного удару важче. Берсерк б'ється на своїй кризі.
## Налаштування: radius, life, max.

const COLOR := Color(0.75, 0.92, 1.0, 0.55)

var _patches: Array = []

func _init() -> void:
	id = "ice_slick"
	cooldown = 0.0

func on_strike() -> void:
	var spot := Vector3(enemy.global_position.x, DungeonBuilder.FLOOR_TOP, enemy.global_position.z) + enemy.model_forward() * 1.0
	if _patches.size() >= int(config.get("max", 3)):
		_drop(0)
	var radius := float(config.get("radius", 1.6))
	var patch := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 16
	disc.rings = 1
	patch.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.6
	mat.roughness = 0.05
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.45, 0.6)
	mat.emission_energy_multiplier = 0.4
	patch.material_override = mat
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world().add_child(patch)
	patch.global_position = spot + Vector3.UP * 0.03
	_patches.append({"node": patch, "spot": spot, "left": float(config.get("life", 7.0))})

func tick(delta: float) -> void:
	super.tick(delta)
	if _patches.is_empty():
		return
	var hero := player()
	var radius := float(config.get("radius", 1.6))
	for i in range(_patches.size() - 1, -1, -1):
		var patch: Dictionary = _patches[i]
		patch.left -= delta
		if patch.left <= 0.0:
			_drop(i)
			continue
		if hero != null and is_instance_valid(hero) and hero.has_method("set_slick"):
			var offset: Vector3 = hero.global_position - patch.spot
			offset.y = 0.0
			if offset.length() <= radius:
				hero.set_slick(0.15)

func _drop(index: int) -> void:
	var patch: Dictionary = _patches[index]
	_patches.remove_at(index)
	if is_instance_valid(patch.node):
		var node: Node3D = patch.node
		var tween := node.create_tween()
		tween.tween_property(node, "scale", Vector3(0.05, 1.0, 0.05), 0.4)
		tween.tween_callback(node.queue_free)

func on_death() -> void:
	while not _patches.is_empty():
		_drop(0)
