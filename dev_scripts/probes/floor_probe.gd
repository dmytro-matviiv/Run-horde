extends SceneTree
func _init() -> void:
	for path in ["res://assets/models/citadel/kit/floor_runes.glb", "res://assets/models/citadel/kit/floor_glow.glb"]:
		if not ResourceLoader.exists(path):
			print("missing ", path); continue
		var node: Node = (load(path) as PackedScene).instantiate()
		for m in node.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var aabb := mi.get_aabb()
			print(path, " ", mi.name, " aabb ", aabb, " xform ", mi.transform.origin)
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if mat is BaseMaterial3D:
					print("  transparency ", (mat as BaseMaterial3D).transparency, " blend ", (mat as BaseMaterial3D).blend_mode, " emission ", (mat as BaseMaterial3D).emission_enabled)
		node.free()
	quit()
