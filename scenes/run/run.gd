extends Node2D
class_name Run

## Кореневий контролер рану: створює пули ворогів/снарядів/кристалів,
## веде відлік часу рану, оновлює HUD, показує екран вибору апгрейду
## на левел-апі (ставлячи дерево сцени на паузу) й реагує на смерть
## героя.

const ENEMY_SCENE := preload("res://scenes/run/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/run/projectile.tscn")
const CRYSTAL_SCENE := preload("res://scenes/run/xp_crystal.tscn")
const LEVEL_UP_CHOICE_SCENE := preload("res://scenes/ui/level_up_choice.tscn")

@onready var hero: CharacterBody2D = $Hero
@onready var enemy_container: Node2D = $EnemyContainer
@onready var projectile_container: Node2D = $ProjectileContainer
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

func _ready() -> void:
	# Попередньо створюємо частину інстансів (preload_count), щоб перші
	# секунди рану не тригерили instantiate() посеред бою.
	var enemy_pool := ObjectPool.new(ENEMY_SCENE, enemy_container, 20)
	var projectile_pool := ObjectPool.new(PROJECTILE_SCENE, projectile_container, 10)
	var crystal_pool := ObjectPool.new(CRYSTAL_SCENE, crystal_container, 20)

	hero.setup(projectile_pool)
	hero.died.connect(_on_hero_died)
	hero.leveled_up.connect(_on_hero_leveled_up)
	hero.gold_collected.connect(_on_gold_collected)

	spawner.setup(enemy_pool, crystal_pool, hero, self)

	game_over_label.visible = false
	_update_hud()

func _process(delta: float) -> void:
	if not _run_active:
		return
	_elapsed_time += delta
	_update_hud()

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

## За один підбір кристала теоретично можна перестрибнути й кілька
## рівнів — тоді питаємо про апгрейд послідовно, по одному вибору.
func _on_hero_leveled_up(levels_gained: int) -> void:
	for i in levels_gained:
		await _show_level_up_choice()

func _show_level_up_choice() -> void:
	var choices := UpgradePool.pick_choices(hero.upgrade_levels)
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
	_run_active = false
	spawner.set_process(false)
	game_over_label.visible = true
