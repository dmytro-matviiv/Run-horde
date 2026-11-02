extends Node

## Перевірка керування камерою: чи крутиться вона рукою, чи доводиться
## сама за рухом і чи лишається рух "вперед" тим, що гравець бачить.

const ProbeUtil := preload("res://tools/probe_util.gd")

const SCENE := "res://scenes/dungeon/dungeon.tscn"

func _ready() -> void:
	var dungeon: Node = load(SCENE).instantiate()
	add_child(dungeon)
	await get_tree().create_timer(2.0).timeout
	for node in dungeon.get_node("HUD").get_children():
		if node.has_signal("upgrade_chosen"):
			ProbeUtil.press_first_card(node)
	await get_tree().create_timer(0.5).timeout
	get_tree().paused = false

	var rig: Node3D = dungeon.get_node("CameraRig")
	var player: CharacterBody3D = dungeon.get_node("Player")

	print("CAM: кут на старті %.2f" % rig.rotation.y)
	rig.rotate_by(1.0)
	await get_tree().physics_frame
	print("CAM: після ручного повороту %.2f" % rig.rotation.y)

	# Переносимо героя у велику залу: у вузькому коридорі він уперся б
	# у стіну й стояв, а нам треба перевірити саме рух.
	player.global_position = Vector3(38, 0.3, 30)
	await get_tree().physics_frame

	# Біжимо вперед: камера має САМА доводитись за спину героя.
	var before := rig.rotation.y
	for i in 240:
		player.set_move_input(Vector2(0, 1))
		await get_tree().physics_frame
	print("CAM: герой біжить у напрямку %.2f, камера %.2f (було %.2f)" % [
		player.get_move_yaw(), rig.rotation.y, before])
	# Нахил: перевіряємо, що він рухається і не вилітає за межі.
	var arm: SpringArm3D = rig.get_node("SpringArm3D")
	var pitch_before := arm.rotation_degrees.x
	rig.pitch_by(0.4)
	await get_tree().physics_frame
	var pitch_after := arm.rotation_degrees.x
	rig.pitch_by(10.0)   # свідомо забагато — має впертись у межу
	await get_tree().physics_frame
	print("CAM: нахил %.1f -> %.1f, після перебору %.1f (межа %.1f)" % [
		pitch_before, pitch_after, arm.rotation_degrees.x, rig.max_pitch_degrees])

	print("CAM: швидкість %.2f, пройшов %.1f м" % [
		Vector2(player.velocity.x, player.velocity.z).length(),
		player.global_position.distance_to(Vector3(38, 0.3, 30))])
	get_tree().quit(0)
