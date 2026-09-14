extends Node

## Автозавантаження: прогрес гравця, що живе, поки запущений
## застосунок. GameState — єдине джерело правди в пам'яті; сам файл
## user://save.json читає й пише SaveManager, GameState про формат
## файлу нічого не знає.
##
## 7 мета-апгрейдів зі статами + розблокування/вибір героя
## (HeroPool) — усе разом розділ 6 ТЗ.

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

# Ідл-шар: коли гравця бачили востаннє й скільки золота накопичилось,
# поки застосунок був закритий (розділ 7 ТЗ).
var last_seen_timestamp := 0
var pending_offline_gold := 0

# Скринька на головному екрані (розділ 8 ТЗ) — окремий таймер,
# не пов'язаний з офлайн-золотом.
var last_chest_claim_timestamp := 0

# Герої (розділ 6 ТЗ): перший розблокований одразу, інші — за золото.
var unlocked_hero_ids: Array = [&"runewielder"]
var selected_hero_id: StringName = &"runewielder"

func is_hero_unlocked(id: StringName) -> bool:
	return unlocked_hero_ids.has(id)

## Повертає true, якщо розблокування здійснено (вистачило золота й
## герой ще не розблокований).
func unlock_hero(id: StringName) -> bool:
	if is_hero_unlocked(id):
		return false
	var def := HeroPool.get_def(id)
	if gold < def.unlock_cost:
		return false
	gold -= def.unlock_cost
	unlocked_hero_ids.append(id)
	SaveManager.save_game()
	return true

func select_hero(id: StringName) -> void:
	if not is_hero_unlocked(id):
		return
	selected_hero_id = id
	SaveManager.save_game()

func _ready() -> void:
	SaveManager.load_game()
	_compute_offline_gold()

func get_total_meta_levels() -> int:
	var total := 0
	for id in meta_upgrade_levels:
		total += meta_upgrade_levels[id]
	return total

## Рахує офлайн-золото за час з останнього виходу (обмежено
## Balance.IDLE_MAX_HOURS). Захист від перекрученого годинника: якщо
## різниця часу від'ємна — нараховуємо нуль, мітку все одно оновлюємо.
func _compute_offline_gold() -> void:
	var now := int(Time.get_unix_time_from_system())
	var elapsed_seconds := now - last_seen_timestamp
	if last_seen_timestamp <= 0 or elapsed_seconds <= 0:
		pending_offline_gold = 0
	else:
		var capped_hours: float = minf(elapsed_seconds / 3600.0, Balance.IDLE_MAX_HOURS)
		pending_offline_gold = int(floor(Balance.idle_gold_per_hour(get_total_meta_levels()) * capped_hours))
	last_seen_timestamp = now
	SaveManager.save_game()

## Викликає екран "поки тебе не було". multiplier=2 — коли гравець
## додивився rewarded-рекламу за подвоєння (AdsManager.show_rewarded_ad).
func claim_offline_gold(multiplier: int = 1) -> void:
	add_gold(pending_offline_gold * multiplier)
	pending_offline_gold = 0

func is_chest_available() -> bool:
	if last_chest_claim_timestamp <= 0:
		return true
	var now := int(Time.get_unix_time_from_system())
	return now - last_chest_claim_timestamp >= int(Balance.CHEST_COOLDOWN_HOURS * 3600.0)

## Скільки секунд лишилось до наступної доступної скриньки (0, якщо
## вже доступна).
func get_chest_seconds_left() -> int:
	if is_chest_available():
		return 0
	var now := int(Time.get_unix_time_from_system())
	var elapsed := now - last_chest_claim_timestamp
	return int(Balance.CHEST_COOLDOWN_HOURS * 3600.0) - elapsed

## Викликати лише після успішного перегляду rewarded-реклами
## (AdsManager.show_rewarded_ad). Повертає скільки золота випало.
func claim_chest_reward() -> int:
	var reward := randi_range(Balance.CHEST_GOLD_MIN, Balance.CHEST_GOLD_MAX)
	add_gold(reward)
	last_chest_claim_timestamp = int(Time.get_unix_time_from_system())
	SaveManager.save_game()
	return reward

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
