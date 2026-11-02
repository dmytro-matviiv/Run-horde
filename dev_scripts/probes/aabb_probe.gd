extends SceneTree
func _init() -> void:
	for path in ["res://assets/models/monsters/orc_cleaver.glb", "res://assets/models/monsters/Orc.glb"]:
		var node: Node3D = (load(path) as PackedScene).instantiate()
		var box := AABB()
		var first := true
		for m in node.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var t := Transform3D()
			var n: Node = mi
			while n != node:
				t = (n as Node3D).transform * t
				n = n.get_parent()
			var b := t * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		print(path, " ", box)
		node.free()
	quit()
