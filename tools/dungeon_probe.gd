extends Node

## Діагностика данжу: чи рухається герой, чи існують вороги і якого
## вони розміру.

const SCENE := "res://scenes/dungeon/dungeon.tscn"

func _ready() -> void:
	var dungeon: Node = load(SCENE).instantiate()
	add_child(dungeon)
	await get_tree().create_timer(2.0).timeout
	for node in dungeon.get_node("HUD").get_children():
		if node.has_signal("upgrade_chosen"):
			node.upgrade_chosen.emit(&"weapon_damage")
	await get_tree().create_timer(0.5).timeout
	get_tree().paused = false

	var player: CharacterBody3D = dungeon.get_node("Player")
	print("PROBE: старт героя ", player.global_position)

	# Женемо героя вперед дві секунди й дивимось, чи зрушив.
	var start := player.global_position
	for i in 120:
		player.set_move_input(Vector2(0, 1))
		await get_tree().physics_frame
	print("PROBE: після руху ", player.global_position, " пройшов ", start.distance_to(player.global_position))

	var enemies: Node = dungeon.get_node("Enemies")
	print("PROBE: ворогів у сцені ", enemies.get_child_count())
	for enemy in enemies.get_children():
		var model: Node3D = null
		for child in enemy.get_children():
			if child is Node3D and not (child is CollisionShape3D) and not (child is NavigationAgent3D):
				model = child
				break
		print("PROBE:   ", enemy.name, " поз ", enemy.global_position,
			" масштаб моделі ", "нема" if model == null else str(model.scale))
	get_tree().quit(0)
