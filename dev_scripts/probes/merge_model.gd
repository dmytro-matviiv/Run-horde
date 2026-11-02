extends Node

## Зливає модель з багатьох шматків в ОДИН меш — для телефона.
##
## Деякі моделі (наприклад, книга заклять) складаються з десятків
## окремих частин, і кожна — окрема команда відеокарті: 60 частин —
## 60 команд лише на книжку в руці героя. Цей інструмент збирає всі
## частини в один меш, а колір кожного матеріалу переносить у колір
## вершин — виходить одна команда замість шістдесяти.
##
## Працює для моделей без текстур (лише кольори матеріалів).
##   godot --path . res://tools/merge_model.tscn -- --in=res://шлях/модель.glb
##       --out=res://assets/models/weapons/назва --turn=0,-45,0
## Збереже назва.res (меш) і назва.tscn (сцену з ним). turn — поворот у
## градусах, щоб модель стала "вгору по Y, лицем на +Z".

func _ready() -> void:
	var source := ""
	var out := ""
	var turn := Vector3.ZERO
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--in="):
			source = argument.get_slice("=", 1)
		elif argument.begins_with("--out="):
			out = argument.get_slice("=", 1)
		elif argument.begins_with("--turn=") and argument != "--turn=face":
			var parts := argument.get_slice("=", 1).split(",")
			turn = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	if source == "" or out == "":
		push_error("Потрібні --in=... і --out=...")
		get_tree().quit(1)
		return
	var model: Node3D = load(source).instantiate()
	add_child(model)
	# --turn=face: самі шукаємо поворот навколо Y, за якого модель
	# найтонша по Z, — тоді її лице (обкладинка книги) дивиться на +Z.
	for argument in OS.get_cmdline_user_args():
		if argument == "--turn=face":
			turn = Vector3(0, _thinnest_turn(model), 0)
	var rotation := Basis.from_euler(turn * (PI / 180.0))

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var parts := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var t: Transform3D = Transform3D(rotation) * model.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var material := mi.get_active_material(s) as BaseMaterial3D
			var color := material.albedo_color if material != null else Color.WHITE
			var base := vertices.size()
			var surface_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var surface_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in surface_vertices.size():
				vertices.append(t * surface_vertices[i])
				normals.append((t.basis * surface_normals[i]).normalized() if i < surface_normals.size() else Vector3.UP)
				colors.append(color)
			var surface_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if surface_indices.is_empty():
				for i in surface_vertices.size():
					indices.append(base + i)
			else:
				for index in surface_indices:
					indices.append(base + index)
			parts += 1

	# Модель — у центр. Габарити рахуємо за самими вершинами: коробка
	# кожної частини після повороту роздувається й давала б хибний розмір.
	var lo := Vector3.ONE * INF
	var hi := -Vector3.ONE * INF
	for v in vertices:
		lo = lo.min(v)
		hi = hi.max(v)
	var bounds := AABB(lo, hi - lo)
	var center := bounds.get_center()
	for i in vertices.size():
		vertices[i] -= center

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	mesh.surface_set_material(0, material)
	ResourceSaver.save(mesh, out + ".res")

	var root := Node3D.new()
	root.name = out.get_file().to_pascal_case()
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = load(out + ".res")
	root.add_child(instance)
	instance.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, out + ".tscn")
	print("MERGE: %d частин -> 1 меш, %d вершин, поворот %s, розмір %s -> %s.tscn" % [parts, vertices.size(), turn, bounds.size, out])
	get_tree().quit(0)

## Кут навколо Y (градуси), за якого модель найтонша вздовж Z.
func _thinnest_turn(model: Node3D) -> float:
	var points := PackedVector3Array()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var t: Transform3D = model.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var surface: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for i in range(0, surface.size(), 7):
				points.append(t * surface[i])
	var best := 0.0
	var best_depth := INF
	for step in 180:
		var angle := -90.0 + step
		var basis := Basis(Vector3.UP, deg_to_rad(angle))
		var lo := INF
		var hi := -INF
		for p in points:
			var z := (basis * p).z
			lo = minf(lo, z)
			hi = maxf(hi, z)
		if hi - lo < best_depth:
			best_depth = hi - lo
			best = angle
	return best
