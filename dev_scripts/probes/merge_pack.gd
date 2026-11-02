extends SceneTree
## Тимчасово (лише в test_env): модель з багатьох частин і плоских кольорових
## матеріалів -> дві злиті сітки з кольором у вершинах: звичайна й та, що
## світиться (руни, кристали). Звичайна спрощується вбудованим meshoptimizer.
##   godot --headless -s res://tools/merge_pack.gd -- <модель> <вихід.bin> <ціль трикутників> [фільтр назв] [--recenter]
const GLOW_MATERIALS := ["Frozen rune", "Cyan crystal", "Crystal bright facets"]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var root: Node3D = (load(args[0]) as PackedScene).instantiate()
	var target := args[2].to_int()
	var name_filter := args[3] if args.size() > 3 and not args[3].begins_with("--") else ""
	var recenter := args.has("--recenter")
	var groups := [_empty(), _empty()]   # 0 — звичайна, 1 — світиться
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if name_filter != "" and not String(mi.name).begins_with(name_filter):
			continue
		var xform := Transform3D.IDENTITY
		var walk: Node = mi
		while walk != root:
			xform = (walk as Node3D).transform * xform
			walk = walk.get_parent()
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var mat := mi.get_active_material(s) as BaseMaterial3D
			var glow := GLOW_MATERIALS.has(mat.resource_name)
			var color: Color = mat.albedo_color
			var g: Dictionary = groups[1 if glow else 0]
			var base: int = g.pos.size()
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				g.pos.append(xform * v)
				g.col.append(color)
			for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
				g.nor.append((xform.basis * n).normalized())
			for i: int in arrays[Mesh.ARRAY_INDEX]:
				g.idx.append(base + i)
	if recenter:
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for g: Dictionary in groups:
			for p: Vector3 in g.pos:
				lo = lo.min(p)
				hi = hi.max(p)
		var shift := Vector3(-(lo.x + hi.x) * 0.5, -lo.y, -(lo.z + hi.z) * 0.5)
		for g: Dictionary in groups:
			for i in g.pos.size():
				g.pos[i] += shift
	# Звичайну частину — спростити до цілі.
	var lit: Dictionary = groups[0]
	if lit.idx.size() / 3 > target:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = lit.pos
		arrays[Mesh.ARRAY_NORMAL] = lit.nor
		arrays[Mesh.ARRAY_COLOR] = lit.col
		arrays[Mesh.ARRAY_INDEX] = lit.idx
		var importer := ImporterMesh.new()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		importer.generate_lods(25.0, 60.0, [])
		print("LOD0 ", lit.idx.size() / 3)
		var best: PackedInt32Array = lit.idx
		for lod in importer.get_surface_lod_count(0):
			var indices := importer.get_surface_lod_indices(0, lod)
			print("LOD%d %d" % [lod + 1, indices.size() / 3])
			if indices.size() / 3 >= target:
				best = indices
		lit.idx = best
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_32(groups.size())
	for gi in groups.size():
		var g: Dictionary = groups[gi]
		# Лише вершини, на які посилаються трикутники.
		var remap := {}
		var pos := PackedFloat32Array()
		var nor := PackedFloat32Array()
		var col := PackedFloat32Array()
		var idx := PackedInt32Array()
		for old: int in g.idx:
			if not remap.has(old):
				remap[old] = remap.size()
				var p: Vector3 = g.pos[old]
				var n: Vector3 = g.nor[old]
				var c: Color = g.col[old]
				pos.append_array([p.x, p.y, p.z])
				nor.append_array([n.x, n.y, n.z])
				col.append_array([c.r, c.g, c.b, c.a])
			idx.append(remap[old])
		file.store_32(gi)
		file.store_32(remap.size())
		file.store_32(idx.size())
		file.store_buffer(pos.to_byte_array())
		file.store_buffer(nor.to_byte_array())
		file.store_buffer(col.to_byte_array())
		file.store_buffer(idx.to_byte_array())
		print("ГРУПА %d: трикутників %d, вершин %d" % [gi, idx.size() / 3, remap.size()])
	file.close()
	quit(0)

func _empty() -> Dictionary:
	return {"pos": PackedVector3Array(), "nor": PackedVector3Array(), "col": PackedColorArray(), "idx": PackedInt32Array()}
