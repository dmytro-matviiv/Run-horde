extends Node
## Тимчасово (test_env): тверді прикраси й їхні коробки (червоні) — чи
## збігаються. Кадри зверху над кількома коробками.
const ProbeUtil := preload("res://tools/probe_util.gd")
var _dungeon: Node
func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for node in _dungeon.get_node("HUD").get_children():
			if node.has_signal("upgrade_chosen") and not node.is_queued_for_deletion():
				ProbeUtil.press_first_card(node)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PerfSettings.persist_settings = false
	var lvl := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="): lvl = a.get_slice("=", 1).to_int()
	GameState.max_dungeon_level = maxi(GameState.max_dungeon_level, lvl)
	GameState.dungeon_level = lvl
	_dungeon = load("res://scenes/dungeon/dungeon.tscn").instantiate()
	add_child(_dungeon)
	await _wait(4.0)
	for e in _dungeon.find_children("*", "Enemy3D", true, false):
		e.queue_free()
	var obstacles: Node = _dungeon.find_child("Obstacles", true, false)
	var decor: Array = []
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 0.1, 0.1, 0.35)
	for child in obstacles.get_children():
		if String(child.name).begins_with("Decor"):
			decor.append(child)
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = ((child as CollisionShape3D).shape as BoxShape3D).size
			mesh.mesh = box
			mesh.material_override = material
			_dungeon.add_child(mesh)
			mesh.global_position = (child as Node3D).global_position
	var player: Node3D = _dungeon.get_node("Player")
	var camera: Camera3D = _dungeon.get_viewport().get_camera_3d()
	var shots := 0
	for i in range(0, decor.size(), maxi(1, decor.size() / 4)):
		if shots >= 4:
			break
		var c: Vector3 = (decor[i] as Node3D).global_position
		player.global_position = c + Vector3(0, 0.3, 3.2)
		await _wait(1.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("D:/RuneHorde_work/screenshots/decor_%d_%d.png" % [lvl, shots])
		shots += 1
	get_tree().quit(0)
