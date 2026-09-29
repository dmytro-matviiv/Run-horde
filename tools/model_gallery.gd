extends Node3D

## Галерея моделей: знімає кожну GLB-модель із папки окремим кадром —
## щоб подивитись, що прийшло в новому наборі, не імпортуючи його в
## проєкт (моделі читаються з диска напряму).
##   godot --path . res://tools/model_gallery.tscn -- --dir=D:/папка --out=D:/кадри [--filter=слово]
## Кадри: <out>/<номер>.png, список назв — у виводі ("GALLERY номер назва").

var _camera: Camera3D
var _holder: Node3D

func _ready() -> void:
	var dir := ""
	var out := ""
	var filter := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--dir="):
			dir = argument.get_slice("=", 1)
		elif argument.begins_with("--out="):
			out = argument.get_slice("=", 1)
		elif argument.begins_with("--filter="):
			filter = argument.get_slice("=", 1).to_lower()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.2, 0.21, 0.24)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 35.0
	add_child(_camera)
	_holder = Node3D.new()
	add_child(_holder)

	var files := _find_glb(dir)
	var index := 0
	for path in files:
		if filter != "" and not path.get_file().to_lower().contains(filter):
			continue
		var model := _load(path)
		if model == null:
			continue
		_holder.add_child(model)
		_frame(model)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%03d.png" % [out, index])
		print("GALLERY %03d %s" % [index, path.get_file().get_basename()])
		model.queue_free()
		index += 1
	get_tree().quit(0)

func _find_glb(dir: String) -> Array[String]:
	var result: Array[String] = []
	var access := DirAccess.open(dir)
	if access == null:
		return result
	for name in access.get_files():
		if name.to_lower().ends_with(".glb"):
			result.append(dir.path_join(name))
	for sub in access.get_directories():
		result.append_array(_find_glb(dir.path_join(sub)))
	result.sort()
	return result

func _load(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	return document.generate_scene(state) as Node3D

## Камера згори навскоси, так щоб модель вміщалась у кадр.
func _frame(model: Node3D) -> void:
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 0.05)
	var distance := radius / tan(deg_to_rad(_camera.fov * 0.5)) * 1.1
	var direction := Vector3(0.55, 0.6, 1.0).normalized()
	_camera.global_position = center + direction * distance
	_camera.look_at(center)
