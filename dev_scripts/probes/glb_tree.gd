extends Node

func _ready() -> void:
	for path in OS.get_cmdline_user_args():
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		document.append_from_file(path, state)
		var scene := document.generate_scene(state)
		add_child(scene)
		var box := AABB()
		var first := true
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			var m := node as MeshInstance3D
			var b: AABB = m.global_transform * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
		print("NODE %s pos=%s size=%s" % [path.get_file(), box.position.snapped(Vector3.ONE * 0.01), box.size.snapped(Vector3.ONE * 0.01)])
		scene.queue_free()
	get_tree().quit(0)
