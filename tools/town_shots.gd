extends Node

## Кілька знімків міста з різних точок — щоб оцінити вигляд, не
## запускаючи гру руками.
##   godot --path . res://tools/town_shots.tscn -- --out=D:/папка

const SCENE := "res://scenes/world/base_island.tscn"

## Точка героя, поворот і нахил камери, відстань.
const VIEWS := [
	{"name": "spawn", "pos": Vector3(0, 0.2, 24), "yaw": 0.0, "pitch": -30.0, "distance": 9.0},
	{"name": "gate", "pos": Vector3(0, 0.2, -20), "yaw": 0.0, "pitch": -22.0, "distance": 8.0},
	{"name": "west", "pos": Vector3(-6, 0.2, 2), "yaw": 90.0, "pitch": -28.0, "distance": 9.0},
	{"name": "east", "pos": Vector3(6, 0.2, 2), "yaw": -90.0, "pitch": -28.0, "distance": 9.0},
	{"name": "south", "pos": Vector3(0, 0.2, 10), "yaw": 180.0, "pitch": -24.0, "distance": 9.0},
	{"name": "overview", "pos": Vector3(0, 0.2, 12), "yaw": 0.0, "pitch": -55.0, "distance": 38.0},
]

func _ready() -> void:
	PerfSettings.persist_settings = false
	var out_dir := "D:/RuneHorde_work/screenshots"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.get_slice("=", 1)
	var world: Node = load(SCENE).instantiate()
	add_child(world)
	await get_tree().create_timer(2.0).timeout
	var player: Node3D = world.get_node("Player")
	var rig: Node3D = world.get_node("CameraRig")
	for view: Dictionary in VIEWS:
		player.global_position = view.pos
		rig.global_position = view.pos + Vector3.UP * 1.2
		rig.set("_yaw", deg_to_rad(view.yaw))
		rig.rotation.y = deg_to_rad(view.yaw)
		var arm: SpringArm3D = rig.get_node("SpringArm3D")
		arm.spring_length = view.distance
		rig.set("_pitch", deg_to_rad(view.pitch))
		arm.rotation.x = deg_to_rad(view.pitch)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/town_%s.png" % [out_dir, view.name])
		print("SHOT: ", view.name)
	get_tree().quit(0)
