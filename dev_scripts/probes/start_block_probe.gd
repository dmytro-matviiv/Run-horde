extends Node
func _ready() -> void:
	PerfSettings.persist_settings = false
	GameState.dungeon_level = 0
	var d: Node = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(d)
	await get_tree().create_timer(3.0).timeout
	var p: Node3D = d.get_node("Player")
	print("PROBE start ", p.global_position)
	for c in d.find_child("Obstacles", true, false).get_children():
		var cs := c as CollisionShape3D
		if cs == null: continue
		var pos := cs.global_position
		if Vector2(pos.x - 38.0, pos.z - 58.0).length() < 4.0:
			print("PROBE near: ", cs.name, " ", pos, " ", (cs.shape as BoxShape3D).size if cs.shape is BoxShape3D else cs.shape)
	get_tree().quit(0)
