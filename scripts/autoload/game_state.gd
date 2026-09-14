extends Node

## Автозавантаження: прогрес гравця, що живе, поки запущений
## застосунок. GameState — єдине джерело правди в пам'яті; сам файл
## user://save.json читає й пише SaveManager, GameState про формат
## файлу нічого не знає.
##
## Тут лише 7 мета-апгрейдів зі статами (розділ 6 ТЗ). Розблокування
## другого/третього героя свідомо не додане — героїв поки один,
## розблоковувати нема чого; це Фаза 5.

const META_UPGRADE_MAX_LEVELS := {
	&"meta_max_hp": 10,
	&"meta_damage": 10,
	&"meta_move_speed": 8,
	&"meta_pickup_radius": 5,
	&"meta_gold_gain": 10,
	&"meta_luck": 5,
	&"meta_start_level": 3,
}

var gold := 0
var meta_upgrade_levels: Dictionary = {}   # StringName -> int

# Дані останнього завершеного рану — для екрана результатів.
# У сейв не пишуться, живуть лише до наступного рану.
var last_run_gold := 0
var last_run_kills := 0
var last_run_time := 0.0
var last_run_victory := false

func _ready() -> void:
	SaveManager.load_game()

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	SaveManager.save_game()

func get_meta_level(id: StringName) -> int:
	return meta_upgrade_levels.get(id, 0)

func get_meta_max_level(id: StringName) -> int:
	return META_UPGRADE_MAX_LEVELS.get(id, 0)

func get_meta_upgrade_cost(id: StringName) -> int:
	return Balance.meta_upgrade_cost(get_meta_level(id) + 1)

## Повертає true, якщо купівлю здійснено (вистачило золота й ще не
## досягнуто максимального рівня).
func buy_meta_upgrade(id: StringName) -> bool:
	var current_level := get_meta_level(id)
	if current_level >= get_meta_max_level(id):
		return false
	var cost := get_meta_upgrade_cost(id)
	if gold < cost:
		return false
	gold -= cost
	meta_upgrade_levels[id] = current_level + 1
	SaveManager.save_game()
	return true
