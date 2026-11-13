extends Node

## Автозавантаження: прогрес гравця, що живе, поки запущений
## застосунок. GameState — єдине джерело правди в пам'яті; сам файл
## user://save.json читає й пише SaveManager, GameState про формат
## файлу нічого не знає.
##
## 7 мета-апгрейдів зі статами + розблокування/вибір героя
## (HeroPool) — усе разом розділ 6 ТЗ.
##
## Золото — спільне на всіх героїв, а самі рівні апгрейдів/талантів —
## окремі для кожного (hero_meta_levels: hero_id -> {upgrade_id: рівень}).
## Так прокачка Клинкової Вартової не впливає на Жрицю Багаття.

const META_UPGRADE_MAX_LEVELS := {
	&"meta_max_hp": 10,
	&"meta_damage": 10,
	&"meta_move_speed": 8,
	&"meta_pickup_radius": 5,
	&"meta_gold_gain": 10,
	&"meta_luck": 5,
	&"meta_start_level": 3,
	# Унікальні таланти — по одному на героя (HeroDef.unique_talent_id).
	&"talent_bolt_pierce": 3,
	&"talent_extra_blades": 2,
	&"talent_aura_power": 3,
	&"talent_shadow_clones": 3,
}

var gold := 0
var hero_meta_levels: Dictionary = {}   # StringName (hero_id) -> Dictionary (StringName -> int)

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

# Реклама (розділ 8 ТЗ). ads_removed виставить покупка remove_ads —
# вимикає лише банер та interstitial, rewarded лишається.
var ads_removed := false
var completed_runs := 0
var last_interstitial_timestamp := 0
var last_run_gold_doubled := false

## Викликає IapManager після справжньої (або тестової на ПК) покупки
## remove_ads, а також стартовий набір за геми.
func grant_remove_ads() -> void:
	ads_removed = true
	SaveManager.save_game()
	AdsManager.hide_banner()

# Геми — преміум-валюта: купуються лише за реальні гроші (IapManager),
# витрачаються на обмін, стартові набори, а згодом — на зброю й героя.
var gems := 0
# Коли гру вперше запустили — від цього рахуються 48 год до стартових наборів.
var install_timestamp := 0
var claimed_starter_packs: Array = []   # StringName id вже куплених наборів

const STARTER_PACK_IDS: Array[StringName] = [&"starter_ads", &"starter_hero", &"starter_gold"]

func add_gems(amount: int) -> void:
	if amount <= 0:
		return
	gems += amount
	SaveManager.save_game()

## Повертає true, якщо гемів вистачило й їх списано.
func spend_gems(amount: int) -> bool:
	if amount <= 0 or gems < amount:
		return false
	gems -= amount
	SaveManager.save_game()
	return true

## index — рядок з Balance.GEM_EXCHANGES. Повертає true, якщо обмін відбувся.
func exchange_gems_for_gold(index: int) -> bool:
	if index < 0 or index >= Balance.GEM_EXCHANGES.size():
		return false
	var exchange: Array = Balance.GEM_EXCHANGES[index]
	if not spend_gems(exchange[0]):
		return false
	add_gold(exchange[1])
	return true

## Скільки секунд лишилось, поки стартові набори з'являться в магазині
## (0 — вже доступні).
func get_starter_packs_seconds_left() -> int:
	var now := int(Time.get_unix_time_from_system())
	var unlock_at := install_timestamp + int(Balance.STARTER_PACK_DELAY_HOURS * 3600.0)
	return maxi(unlock_at - now, 0)

func is_starter_pack_claimed(id: StringName) -> bool:
	return claimed_starter_packs.has(id)

func get_starter_pack_cost(id: StringName) -> int:
	match id:
		&"starter_ads":
			return Balance.STARTER_ADS_COST_GEMS
		&"starter_hero":
			return Balance.STARTER_HERO_COST_GEMS
		&"starter_gold":
			return Balance.STARTER_GOLD_COST_GEMS
	return 0

## Повертає true, якщо набір куплено. Кожен набір — лише один раз.
## Якщо частина набору вже є (реклама вже прибрана / герой уже
## розблокований) — замість неї гравець отримує золото, щоб не платити
## гемами за порожнє місце.
func buy_starter_pack(id: StringName) -> bool:
	if not STARTER_PACK_IDS.has(id) or is_starter_pack_claimed(id):
		return false
	if get_starter_packs_seconds_left() > 0:
		return false
	if not spend_gems(get_starter_pack_cost(id)):
		return false
	claimed_starter_packs.append(id)
	match id:
		&"starter_ads":
			if not ads_removed:
				grant_remove_ads()
			add_gold(Balance.STARTER_ADS_GOLD)
		&"starter_hero":
			if is_hero_unlocked(&"blade_warden"):
				add_gold(HeroPool.get_def(&"blade_warden").unlock_cost)
			else:
				unlocked_hero_ids.append(&"blade_warden")
			add_gold(Balance.STARTER_HERO_GOLD)
		&"starter_gold":
			add_gold(Balance.STARTER_GOLD_GOLD)
	SaveManager.save_game()
	return true

# Екрани будівель (Зала героїв, Збройня, Храм, Ринок): куди з них
# повертатись — у місто до тих самих дверей або в головне меню, якщо
# екран відкрили звідти. Між запусками не зберігається.
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const TOWN_SCENE := "res://scenes/world/haven/haven.tscn"
var ui_return_scene := MAIN_MENU_SCENE
var town_return_spot := Vector3.INF

## Відкрити екран будівлі з міста: "Назад" поверне героя до її дверей.
func open_from_town(scene_path: String, spot: Vector3) -> void:
	ui_return_scene = TOWN_SCENE
	town_return_spot = spot
	get_tree().change_scene_to_file(scene_path)

## "Назад" з екрана будівлі.
func return_from_ui() -> void:
	var target := ui_return_scene
	ui_return_scene = MAIN_MENU_SCENE
	if target == TOWN_SCENE:
		SceneLoader.change_scene(TOWN_SCENE, "Місто")
	else:
		get_tree().change_scene_to_file(target)

# Данж (3D). dungeon_level — який рівень зараз обрано, max_dungeon_level
# — найдальший, куди герой уже дійшов.
var dungeon_level := 0
var max_dungeon_level := 0

## ЛИШЕ ДЛЯ ПЕРЕВІРКИ: у тестовій (debug) збірці — з редактора чи debug-APK
## на телефоні — відкриті всі рівні данжу. Сейв не змінюється:
## max_dungeon_level лишається справжнім, і "Пройдено" показує чесно. У
## релізній збірці не діє (OS.is_debug_build() там false). ПЕРЕД ВИПУСКОМ
## ГРИ — постав false.
const DEV_UNLOCK_ALL_DUNGEONS := true

## Найдальший рівень, куди вже можна зайти (з урахуванням перемикача вище).
func get_unlocked_dungeon_level() -> int:
	if DEV_UNLOCK_ALL_DUNGEONS and OS.is_debug_build():
		return DungeonLevels.get_level_count() - 1
	return max_dungeon_level

func unlock_next_dungeon_level() -> void:
	max_dungeon_level = maxi(max_dungeon_level, dungeon_level + 1)
	SaveManager.save_game()

func select_dungeon_level(index: int) -> void:
	dungeon_level = clampi(index, 0, get_unlocked_dungeon_level())
	SaveManager.save_game()

func register_completed_run() -> void:
	completed_runs += 1
	SaveManager.save_game()

func is_interstitial_due() -> bool:
	if ads_removed or completed_runs <= Balance.INTERSTITIAL_GRACE_RUNS:
		return false
	if completed_runs % Balance.INTERSTITIAL_EVERY_N_RUNS != 0:
		return false
	var now := int(Time.get_unix_time_from_system())
	return now - last_interstitial_timestamp >= Balance.INTERSTITIAL_MIN_INTERVAL_SEC

func mark_interstitial_shown() -> void:
	last_interstitial_timestamp = int(Time.get_unix_time_from_system())
	SaveManager.save_game()

# Герої (розділ 6 ТЗ): перший розблокований одразу, інші — за золото.
var unlocked_hero_ids: Array = [&"runewielder"]
var selected_hero_id: StringName = &"runewielder"

## Преміум-герой купується за геми, а не за золото (HeroDef.gem_cost).
func unlock_hero_with_gems(id: StringName) -> bool:
	if is_hero_unlocked(id):
		return false
	var def := HeroPool.get_def(id)
	if def.gem_cost <= 0 or not spend_gems(def.gem_cost):
		return false
	unlocked_hero_ids.append(id)
	SaveManager.save_game()
	return true

# Зброя (WeaponPool). Стартова зброя героя безкоштовна й доступна
# завжди; решту купують за геми. Спорядження — окреме на кожного
# героя: сокира вартової не з'являється в руках жриці.
var owned_weapon_ids: Array = []          # StringName
var equipped_weapon_ids: Dictionary = {}  # StringName (hero_id) -> StringName (weapon_id)

func is_weapon_owned(id: StringName) -> bool:
	return WeaponPool.get_def(id).cost_gold <= 0 or owned_weapon_ids.has(id)

## Повертає true, якщо зброю куплено. Уся зброя купується за ЗОЛОТО —
## те саме, що заробляється в походах, тож данжі й крамниця пов'язані.
func buy_weapon(id: StringName) -> bool:
	if is_weapon_owned(id):
		return false
	var def := WeaponPool.get_def(id)
	if gold < def.cost_gold:
		return false
	gold -= def.cost_gold
	owned_weapon_ids.append(id)
	SaveManager.save_game()
	return true

## Спорядити зброю героєві. Чужу зброю (іншого героя) взяти не можна —
## асортимент у кожного свій.
func equip_weapon(hero_id: StringName, weapon_id: StringName) -> bool:
	var def := WeaponPool.get_def(weapon_id)
	if def.hero_id != hero_id or not is_weapon_owned(weapon_id):
		return false
	equipped_weapon_ids[hero_id] = weapon_id
	SaveManager.save_game()
	return true

## Чим герой б'ється зараз. Якщо нічого не спорядили — стартова зброя.
func get_equipped_weapon_id(hero_id: StringName) -> StringName:
	var equipped: StringName = equipped_weapon_ids.get(hero_id, &"")
	# Перевіряємо не лише "куплено", а й що ця зброя досі належить цьому
	# героєві: його арсенал міг змінитись між версіями гри.
	if equipped != &"":
		var def := WeaponPool.get_def(equipped)
		if def != null and def.hero_id == hero_id and is_weapon_owned(equipped):
			return equipped
	return WeaponPool.get_starter_for_hero(hero_id).id

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
	if install_timestamp <= 0:
		install_timestamp = int(Time.get_unix_time_from_system())
	_compute_offline_gold()

## Сума рівнів усіх апгрейдів/талантів усіх героїв разом — використовує
## лише формула офлайн-золота (розділ 7 ТЗ), як загальний показник
## того, скільки гравець уже вклав у прогрес.
func get_total_meta_levels() -> int:
	var total := 0
	for hero_id in hero_meta_levels:
		var levels: Dictionary = hero_meta_levels[hero_id]
		for id in levels:
			total += levels[id]
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

# Прихисток: ресурси, квести (QuestBook).
## Добуте в Прихистку: "wood", "stone", "herb" -> кількість.
var resources: Dictionary = {}
## id квесту -> {"state", "progress"} (див. QuestBook).
var quests: Dictionary = {}
signal quests_changed

func add_resource(id: String, amount: int = 1) -> void:
	resources[id] = int(resources.get(id, 0)) + amount
	QuestBook.report(id, amount)
	SaveManager.save_game()

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	SaveManager.save_game()

func get_hero_meta_levels(hero_id: StringName) -> Dictionary:
	return hero_meta_levels.get(hero_id, {})

func get_meta_level(hero_id: StringName, id: StringName) -> int:
	return get_hero_meta_levels(hero_id).get(id, 0)

func get_meta_max_level(id: StringName) -> int:
	return META_UPGRADE_MAX_LEVELS.get(id, 0)

func get_meta_upgrade_cost(hero_id: StringName, id: StringName) -> int:
	return Balance.meta_upgrade_cost(get_meta_level(hero_id, id) + 1)

## Повертає true, якщо купівлю здійснено (вистачило золота й ще не
## досягнуто максимального рівня для ЦЬОГО героя).
func buy_meta_upgrade(hero_id: StringName, id: StringName) -> bool:
	var current_level := get_meta_level(hero_id, id)
	if current_level >= get_meta_max_level(id):
		return false
	var cost := get_meta_upgrade_cost(hero_id, id)
	if gold < cost:
		return false
	gold -= cost
	if not hero_meta_levels.has(hero_id):
		hero_meta_levels[hero_id] = {}
	hero_meta_levels[hero_id][id] = current_level + 1
	SaveManager.save_game()
	return true
