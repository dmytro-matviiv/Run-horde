extends Node2D
class_name Run

## Кореневий контролер рану: створює пули ворогів/снарядів/кристалів,
## веде відлік часу рану, оновлює HUD, показує екран вибору апгрейду
## на левел-апі (ставлячи дерево сцени на паузу) й реагує на смерть
## героя або перемогу (дожив до Balance.RUN_DURATION). В обох випадках
## банкує зібране золото в GameState і переходить на екран результатів.

const ENEMY_SCENE := preload("res://scenes/run/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/run/projectile.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/run/enemy_projectile.tscn")
const CRYSTAL_SCENE := preload("res://scenes/run/xp_crystal.tscn")
const LEVEL_UP_CHOICE_SCENE := preload("res://scenes/ui/level_up_choice.tscn")
const RESULTS_SCENE_PATH := "res://scenes/ui/results.tscn"

@onready var hero: CharacterBody2D = $Hero
@onready var enemy_container: Node2D = $EnemyContainer
@onready var projectile_container: Node2D = $ProjectileContainer
@onready var enemy_projectile_container: Node2D = $EnemyProjectileContainer
@onready var crystal_container: Node2D = $CrystalContainer
@onready var spawner: Node = $Spawner
@onready var hud: CanvasLayer = $HUD
@onready var timer_label: Label = $HUD/TimerLabel
@onready var hp_label: Label = $HUD/HPLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var gold_label: Label = $HUD/GoldLabel
@onready var game_over_label: Label = $HUD/GameOverLabel

var _elapsed_time := 0.0
var _run_active := true
var _gold_total := 0
var _kills_total := 0

func _ready() -> void:
	# Попередньо створюємо частину інстансів (preload_count), щоб перші
	# секунди рану не тригерили instantiate() посеред бою.
	var enemy_pool := ObjectPool.new(ENEMY_SCENE, enemy_container, 20)
	var projectile_pool := ObjectPool.new(PROJECTILE_SCENE, projectile_container, 10)
	var enemy_projectile_pool := ObjectPool.new(ENEMY_PROJECTILE_SCENE, enemy_projectile_container, 5)
	var crystal_pool := ObjectPool.new(CRYSTAL_SCENE, crystal_container, 20)

	hero.setup(projectile_pool)
	hero.died.connect(_on_hero_died)
	hero.leveled_up.connect(_on_hero_leveled_up)
	hero.gold_collected.connect(_on_gold_collected)
	hero.apply_hero_def(HeroPool.get_def(GameState.selected_hero_id))
	# apply_meta_upgrades може одразу емітити leveled_up (бонусні рівні
	# від "Стартового рівня") — сигнал має бути підключений до цього.
	hero.apply_meta_upgrades(GameState.get_hero_meta_levels(GameState.selected_hero_id))

	spawner.setup(enemy_pool, crystal_pool, enemy_projectile_pool, hero, self, _on_enemy_died)

	game_over_label.visible = false
	_update_hud()

func _process(delta: float) -> void:
	if not _run_active:
		return
	_elapsed_time += delta
	_update_hud()
	if _elapsed_time >= Balance.RUN_DURATION:
		_end_run(true)

func get_elapsed_minutes() -> float:
	return _elapsed_time / 60.0

func _update_hud() -> void:
	var minutes := int(_elapsed_time) / 60
	var seconds := int(_elapsed_time) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	hp_label.text = "HP: %d / %d" % [int(hero.current_hp), int(hero.max_hp)]
	level_label.text = "Рівень %d (XP %d/%d)" % [hero.level, hero.xp, Balance.xp_to_next(hero.level)]
	gold_label.text = "Золото: %d" % _gold_total

func _on_gold_collected(amount: int) -> void:
	_gold_total += amount

func _on_enemy_died() -> void:
	_kills_total += 1

## За один підбір кристала теоретично можна перестрибнути й кілька
## рівнів — тоді питаємо про апгрейд послідовно, по одному вибору.
func _on_hero_leveled_up(levels_gained: int) -> void:
	for i in levels_gained:
		await _show_level_up_choice()

func _show_level_up_choice() -> void:
	var choices := UpgradePool.pick_choices(hero.upgrade_levels, hero.get_luck_bonus())
	if choices.is_empty():
		return
	get_tree().paused = true
	var choice_ui: Node = LEVEL_UP_CHOICE_SCENE.instantiate()
	choice_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(choice_ui)
	choice_ui.setup(hero.level, choices, hero.upgrade_levels)
	var picked_id: StringName = await choice_ui.upgrade_chosen
	choice_ui.queue_free()
	hero.apply_upgrade(picked_id)
	get_tree().paused = false

func _on_hero_died() -> void:
	_end_run(false)

## Смерть ніколи не марна — золото банкується в GameState в обох
## випадках (перемога/смерть), а не лише при вдалому забігу.
func _end_run(victory: bool) -> void:
	if not _run_active:
		return
	_run_active = false
	spawner.set_process(false)
	game_over_label.text = "Перемога!" if victory else "Ви загинули"
	game_over_label.visible = true
	GameState.add_gold(_gold_total)
	GameState.last_run_gold = _gold_total
	GameState.last_run_kills = _kills_total
	GameState.last_run_time = _elapsed_time
	GameState.last_run_victory = victory
	get_tree().create_timer(1.2).timeout.connect(_go_to_results)

func _go_to_results() -> void:
	get_tree().change_scene_to_file(RESULTS_SCENE_PATH)
