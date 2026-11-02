extends Node

## Перевірка смужок здоров'я: у героя зелена й видима завжди, у ворога
## червона з'являється від удару й спадає з кожним тіком.

const ProbeUtil := preload("res://tools/probe_util.gd")

const SCENE := "res://scenes/dungeon/dungeon.tscn"

func _find_bar(node: Node) -> HealthBar3D:
	for child in node.get_children():
		if child is HealthBar3D:
			return child
	return null

func _ready() -> void:
	var dungeon: Node = load(SCENE).instantiate()
	add_child(dungeon)
	await get_tree().create_timer(2.0).timeout
	for node in dungeon.get_node("HUD").get_children():
		if node.has_signal("upgrade_chosen"):
			ProbeUtil.press_first_card(node)
	await get_tree().create_timer(0.5).timeout
	get_tree().paused = false

	var player: CharacterBody3D = dungeon.get_node("Player")
	var player_bar := _find_bar(player)
	print("BAR: у героя смужка є=", player_bar != null, " видима=", player_bar.visible if player_bar else false)

	var enemy: CharacterBody3D = dungeon.get_node("Enemies").get_child(0)
	var enemy_bar := _find_bar(enemy)
	print("BAR: у ворога смужка є=", enemy_bar != null, " видима до удару=", enemy_bar.visible if enemy_bar else true)

	enemy.take_damage(enemy.max_hp * 0.4)
	await get_tree().physics_frame
	print("BAR: після удару видима=", enemy_bar.visible, " заповнення=%.2f" % enemy_bar._ratio)

	enemy.take_damage(enemy.max_hp * 0.4)
	await get_tree().physics_frame
	print("BAR: після другого удару заповнення=%.2f" % enemy_bar._ratio)

	player.take_damage(40.0)
	await get_tree().physics_frame
	print("BAR: у героя заповнення=%.2f" % player_bar._ratio)
	get_tree().quit(0)
