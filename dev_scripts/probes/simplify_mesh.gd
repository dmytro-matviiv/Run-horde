extends SceneTree
## Тимчасово (лише в test_env): спрощення моделі вбудованим у Godot
## meshoptimizer (ImporterMesh.generate_lods). Пише геометрію обраного
## рівня деталізації у файл: позиції, нормалі, UV, індекси — далі Python
## збирає з неї GLB з тими самими текстурами.
##   godot --headless --path . -s res://tools/simplify_mesh.gd -- <модель> <ціль трикутників> <вихідний .bin>
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: Node = (load(args[0]) as PackedScene).instantiate()
	var target := args[1].to_int()
	var mesh_instance := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(25.0, 60.0, [])
	var best: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	print("LOD0 трикутників ", best.size() / 3)
	for lod in importer.get_surface_lod_count(0):
		var indices := importer.get_surface_lod_indices(0, lod)
		print("LOD%d трикутників %d, поріг %.4f" % [lod + 1, indices.size() / 3, importer.get_surface_lod_size(0, lod)])
		if indices.size() / 3 >= target:
			best = indices
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	# Лише вершини, на які посилається спрощена сітка.
	var remap := {}
	var out_pos := PackedFloat32Array()
	var out_nor := PackedFloat32Array()
	var out_uv := PackedFloat32Array()
	var out_idx := PackedInt32Array()
	for old in best:
		if not remap.has(old):
			remap[old] = remap.size()
			var p := positions[old]
			var n := normals[old]
			var t := uvs[old]
			out_pos.append_array([p.x, p.y, p.z])
			out_nor.append_array([n.x, n.y, n.z])
			out_uv.append_array([t.x, t.y])
		out_idx.append(remap[old])
	var file := FileAccess.open(args[2], FileAccess.WRITE)
	file.store_32(remap.size())
	file.store_32(out_idx.size())
	file.store_buffer(out_pos.to_byte_array())
	file.store_buffer(out_nor.to_byte_array())
	file.store_buffer(out_uv.to_byte_array())
	file.store_buffer(out_idx.to_byte_array())
	file.close()
	print("ОБРАНО трикутників ", out_idx.size() / 3, ", вершин ", remap.size())
	quit(0)
