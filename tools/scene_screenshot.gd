extends Node

## Знімок будь-якої сцени:
##   godot --path . res://tools/scene_screenshot.tscn -- --scene=res://... --out=C:/x.png [--fps]

func _ready() -> void:
	PerfSettings.persist_settings = false
	var scene_path := "res://scenes/ui/main_menu.tscn"
	var out_path := "user://scene_screenshot.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_path = argument.get_slice("=", 1)
		elif argument.begins_with("--out="):
			out_path = argument.get_slice("=", 1)
		elif argument == "--fps":
			PerfSettings._set_fps_visible(true)
	add_child(load(scene_path).instantiate())
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	print("SHOT: ", out_path)
	get_tree().quit(0)
