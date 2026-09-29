extends Node

## Розбирає модель-набір на окремі сцени. Буває, автор кладе в один файл
## десятки деталей рядочком ("Forge Parts" — міх, ковадла, точила,
## діжки...), а данжу потрібна кожна окремо: щоб розставляти й пакувати
## (MeshBatcher). Кожна деталь стає на підлогу серединою в нулі,
## масштабується й зберігається: <назва>.tscn + меш <назва>_mesh.res.
##   godot --path . res://tools/split_model.tscn -- --source=res://шлях.glb --out=res://папка --part=вузол:назва:масштаб ...

func _ready() -> void:
	var source := ""
	var out := ""
	var parts: Array[PackedStringArray] = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="):
			source = argument.get_slice("=", 1)
		elif argument.begins_with("--out="):
			out = argument.get_slice("=", 1)
		elif argument.begins_with("--part="):
			parts.append(argument.get_slice("=", 1).split(":"))
	var scene: Node3D = (load(source) as PackedScene).instantiate()
	add_child(scene)
	for part in parts:
		var node := scene.find_child(part[0], true, false) as MeshInstance3D
		if node == null:
			print("SPLIT немає вузла ", part[0])
			continue
		_save_part(node, out, part[1], float(part[2]))
	get_tree().quit(0)

func _save_part(source: MeshInstance3D, out: String, name: String, scale_factor: float) -> void:
	var bounds: AABB = source.global_transform * source.get_aabb()
	var bottom_center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var mesh := source.mesh.duplicate(true) as Mesh
	var mesh_path := "%s/%s_mesh.res" % [out, name]
	ResourceSaver.save(mesh, mesh_path)
	mesh.take_over_path(mesh_path)
	var root := Node3D.new()
	root.name = name.to_pascal_case()
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	# Деталь стає на підлогу серединою в нулі й збільшується до потрібного.
	var basis := source.global_transform.basis.scaled(Vector3.ONE * scale_factor)
	instance.transform = Transform3D(basis, (source.global_transform.origin - bottom_center) * scale_factor)
	root.add_child(instance)
	instance.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	var scene_path := "%s/%s.tscn" % [out, name]
	ResourceSaver.save(packed, scene_path)
	print("SPLIT %s <- %s, розмір %s" % [scene_path, source.name, (bounds.size * scale_factor).snapped(Vector3.ONE * 0.01)])
