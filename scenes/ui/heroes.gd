extends Control

## Екран героїв: розблокування за золото (HeroPool.get_def(id).unlock_cost),
## преміум-герой — за геми (HeroDef.gem_cost), і вибір активного героя
## для наступного рану (GameState.selected_hero_id). Під кожним героєм
## пишемо його класове вміння — саме воно, а не цифри, відрізняє клас.

## Короткий опис класової механіки (AbilityPool) для екрана вибору.
const ABILITY_HINTS := {
	&"rune_charge": "Рунний Заряд: кожні кілька пострілів — вибухова Рунна Нова",
	&"blade_rage": "Лють: сама робить ривок крізь ворогів з невразливістю",
	&"phoenix": "Слід Полум'я + Фенікс: раз за ран воскресає замість смерті",
	&"shadow_kit": "Мітка смерті, тіньові клони й димова завіса",
}

@onready var gold_label: Label = $VBoxContainer/GoldLabel
@onready var rows_container: VBoxContainer = $VBoxContainer/ScrollContainer/RowsContainer

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	gold_label.text = "Золото: %d    Геми: %d" % [GameState.gold, GameState.gems]
	for child in rows_container.get_children():
		child.queue_free()
	for def in HeroPool.ALL_HEROES:
		rows_container.add_child(_build_row(def))

func _build_row(def: HeroDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var info := Label.new()
	info.custom_minimum_size = Vector2(420, 0)
	info.text = "%s\n%s\n%s" % [def.title, def.description, ABILITY_HINTS.get(def.ability_id, "")]
	row.add_child(info)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(150, 48)

	if GameState.selected_hero_id == def.id:
		action_button.text = "Обрано"
		action_button.disabled = true
	elif GameState.is_hero_unlocked(def.id):
		action_button.text = "Обрати"
		action_button.pressed.connect(_on_select_pressed.bind(def.id))
	elif def.gem_cost > 0:
		action_button.text = "%d гемів" % def.gem_cost
		action_button.disabled = GameState.gems < def.gem_cost
		action_button.pressed.connect(_on_gem_unlock_pressed.bind(def.id))
	else:
		action_button.text = "Купити (%d)" % def.unlock_cost
		action_button.disabled = GameState.gold < def.unlock_cost
		action_button.pressed.connect(_on_unlock_pressed.bind(def.id))

	row.add_child(action_button)
	return row

func _on_select_pressed(id: StringName) -> void:
	GameState.select_hero(id)
	_rebuild()

func _on_unlock_pressed(id: StringName) -> void:
	GameState.unlock_hero(id)
	_rebuild()

func _on_gem_unlock_pressed(id: StringName) -> void:
	GameState.unlock_hero_with_gems(id)
	_rebuild()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
