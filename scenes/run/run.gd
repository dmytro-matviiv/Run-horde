extends Node2D

## Кореневий контролер рану: створює пули ворогів/снарядів/кристалів,
## веде відлік часу рану, оновлює HUD і реагує на смерть героя.

const ENEMY_SCENE := preload("res://scenes/run/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/run/projectile.tscn")
const CRYSTAL_SCENE := preload("res://scenes/run/xp_crystal.tscn")

@onready var hero: CharacterBody2D = $Hero
@onready var enemy_container: Node2D = $EnemyContainer
@onready var projectile_container: Node2D = $ProjectileContainer
@onready var crystal_container: Node2D = $CrystalContainer
@onready var spawner: Node = $Spawner
@onready var timer_label: Label = $HUD/TimerLabel
@onready var hp_label: Label = $HUD/HPLabel
@onready var xp_label: Label = $HUD/XpLabel
@onready var game_over_label: Label = $HUD/GameOverLabel

var _elapsed_time := 0.0
var _run_active := true
var _xp_total := 0
var _gold_total := 0

func _ready() -> void:
	# Попередньо створюємо частину інстансів (preload_count), щоб перші
	# секунди рану не тригерили instantiate() посеред бою.
	var enemy_pool := ObjectPool.new(ENEMY_SCENE, enemy_container, 20)
	var projectile_pool := ObjectPool.new(PROJECTILE_SCENE, projectile_container, 10)
	var crystal_pool := ObjectPool.new(CRYSTAL_SCENE, crystal_container, 20)

	hero.setup(projectile_pool)
	hero.died.connect(_on_hero_died)
	hero.xp_collected.connect(_on_xp_collected)
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
	hp_label.text = "HP: %d / %d" % [int(hero.current_hp), int(Balance.HERO_MAX_HP)]

func _on_xp_collected(amount: int) -> void:
	_xp_total += amount
	xp_label.text = "XP: %d" % _xp_total

func _on_gold_collected(amount: int) -> void:
	_gold_total += amount

func _on_hero_died() -> void:
	_run_active = false
	spawner.set_process(false)
	game_over_label.visible = true
