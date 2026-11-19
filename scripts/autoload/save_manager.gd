extends Node

## Автозавантаження: читає й пише прогрес гравця (GameState) у
## user://save.json. schema_version дозволяє мігрувати старі сейви
## замість того, щоб ламати прогрес гравців при оновленні структури
## файлу.

const SAVE_PATH := "user://save.json"
const CURRENT_SCHEMA_VERSION := 7

## ПЕРСОНАЖІ. Кожен персонаж — окремий файл user://char_<id>.json (його
## прогрес: золото, квести, рівні...). Список персонажів і все, що
## належить АКАУНТУ, а не персонажу (геми, куплене за гроші, без
## реклами), — у user://characters.json. Старий єдиний сейв (save.json)
## при першому запуску стає першим персонажем.
const ROSTER_PATH := "user://characters.json"
const ACCOUNT_KEYS := ["gems", "ads_removed", "claimed_starter_packs", "install_timestamp", "last_interstitial_timestamp"]
var roster := {"active": "", "list": []}

func characters() -> Array:
	return roster.list

func active_id() -> String:
	return String(roster.active)

func _char_path(id: String) -> String:
	return "user://char_%s.json" % id

func _save_path() -> String:
	return _char_path(active_id()) if active_id() != "" else SAVE_PATH

## Новий персонаж: чистий прогрес, свій вигляд. Стає активним.
func create_character(char_name: String, look: Dictionary) -> String:
	if active_id() != "":
		save_game()
	var id := "c%d" % Time.get_ticks_usec() + str(randi() % 1000)
	GameState.reset_progress()
	GameState.character = {"name": char_name, "look": look}
	roster.list.append({"id": id, "name": char_name, "look": look, "level": 1, "created": int(Time.get_unix_time_from_system())})
	roster.active = id
	save_game()
	return id

## Обрати персонажа: його прогрес стає поточним.
func select_character(id: String) -> void:
	if active_id() != "" and active_id() != id:
		save_game()
	roster.active = id
	GameState.reset_progress()
	_load_file(_char_path(id))
	_apply_account()
	_save_roster()

## Видалити персонажа назавжди (файл його прогресу теж).
func delete_character(id: String) -> void:
	for entry: Dictionary in roster.list.duplicate():
		if entry.id == id:
			roster.list.erase(entry)
	var path := ProjectSettings.globalize_path(_char_path(id))
	if FileAccess.file_exists(_char_path(id)):
		DirAccess.remove_absolute(path)
	if active_id() == id:
		roster.active = ""
		if not roster.list.is_empty():
			select_character(String(roster.list[0].id))
			return
		GameState.reset_progress()
	_save_roster()

func _save_roster() -> void:
	var account := {}
	for key: String in ACCOUNT_KEYS:
		var value: Variant = GameState.get(key)
		account[key] = _stringnames_to_strings(value) if value is Array else value
	roster["account"] = account
	for entry: Dictionary in roster.list:
		if entry.id == active_id():
			entry["level"] = int(GameState.get("hero_level")) if GameState.get("hero_level") != null else 1
			entry["name"] = String(GameState.character.get("name", entry.name))
			entry["look"] = GameState.character.get("look", entry.look)
	var file := FileAccess.open(ROSTER_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(roster, "\t"))

func _load_roster() -> void:
	if FileAccess.file_exists(ROSTER_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTER_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			roster = parsed
			if not roster.has("list"):
				roster["list"] = []
			return
	# Перший запуск нової версії: старий сейв стає першим персонажем.
	if FileAccess.file_exists(SAVE_PATH):
		var id := "c1"
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(_char_path(id)))
		roster = {"active": id, "list": [{"id": id, "name": "Мандрівник", "look": {}, "level": 1}]}

func _apply_account() -> void:
	var account: Dictionary = roster.get("account", {})
	for key: String in ACCOUNT_KEYS:
		if account.has(key):
			var value: Variant = account[key]
			GameState.set(key, _strings_to_stringnames(value) if value is Array else value)

## v7: Руновод узяв книгу рун і рунні карти замість посохів-заглушок.
const V7_WEAPON_RENAMES := {
	"rune_bolt": "rune_book",
	"staff_meteor": "rune_cards",
	"storm_scepter": "rune_cards",
	"frost_staff": "rune_cards",
}

## v6: Жриця Багаття стала Чарівницею з посохами. Куплена стара зброя
## переходить на відповідні посохи — гравець нічого не втрачає.
const V6_WEAPON_RENAMES := {
	"ember_bolt": "arcane_staff",
	"flamethrower": "ice_staff",
	"pyre_totem": "venom_staff",
	"sun_lance": "moon_staff",
}

func save_game() -> void:
	var data := {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"gold": GameState.gold,
		"hero_meta_levels": _hero_levels_to_json(GameState.hero_meta_levels),
		"last_seen_timestamp": GameState.last_seen_timestamp,
		"last_chest_claim_timestamp": GameState.last_chest_claim_timestamp,
		"unlocked_hero_ids": _stringnames_to_strings(GameState.unlocked_hero_ids),
		"selected_hero_id": str(GameState.selected_hero_id),
		"ads_removed": GameState.ads_removed,
		"completed_runs": GameState.completed_runs,
		"last_interstitial_timestamp": GameState.last_interstitial_timestamp,
		"gems": GameState.gems,
		"install_timestamp": GameState.install_timestamp,
		"claimed_starter_packs": _stringnames_to_strings(GameState.claimed_starter_packs),
		"dungeon_level": GameState.dungeon_level,
		"max_dungeon_level": GameState.max_dungeon_level,
		"owned_weapon_ids": _stringnames_to_strings(GameState.owned_weapon_ids),
		"equipped_weapon_ids": _keys_to_string(_values_to_strings(GameState.equipped_weapon_ids)),
		"resources": GameState.resources,
		"quests": GameState.quests,
		"haven": GameState.haven,
		"character": GameState.character,
		"inventory": GameState.inventory,
		"equipped_store": GameState.equipped_store,
		"equipment": GameState.equipment,
		"stash": GameState.stash,
		"hero_level": GameState.hero_level,
		"hero_xp": GameState.hero_xp,
		"talents": GameState.talents,
		"talent_resets": GameState.talent_resets,
		"bonus_talent_points": GameState.bonus_talent_points,
		"skill_loadout": GameState.skill_loadout,
		"discovered": GameState.discovered,
	}
	var path := _save_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Не вдалось відкрити файл сейву для запису: %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if active_id() != "":
		_save_roster()

func load_game() -> void:
	_load_roster()
	_load_file(_save_path())
	_apply_account()

func _load_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не вдалось відкрити файл сейву для читання: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Сейв пошкоджений, ігнорую: %s" % path)
		return
	var data: Dictionary = _migrate(parsed)
	GameState.gold = data.get("gold", 0)
	GameState.hero_meta_levels = _hero_levels_from_json(data.get("hero_meta_levels", {}))
	GameState.last_seen_timestamp = data.get("last_seen_timestamp", 0)
	GameState.last_chest_claim_timestamp = data.get("last_chest_claim_timestamp", 0)
	GameState.unlocked_hero_ids = _strings_to_stringnames(data.get("unlocked_hero_ids", ["runewielder"]))
	GameState.selected_hero_id = StringName(data.get("selected_hero_id", "runewielder"))
	GameState.ads_removed = data.get("ads_removed", false)
	GameState.completed_runs = data.get("completed_runs", 0)
	GameState.last_interstitial_timestamp = data.get("last_interstitial_timestamp", 0)
	GameState.gems = data.get("gems", 0)
	GameState.install_timestamp = data.get("install_timestamp", 0)
	GameState.claimed_starter_packs = _strings_to_stringnames(data.get("claimed_starter_packs", []))
	GameState.dungeon_level = data.get("dungeon_level", 0)
	GameState.max_dungeon_level = data.get("max_dungeon_level", 0)
	GameState.owned_weapon_ids = _strings_to_stringnames(data.get("owned_weapon_ids", []))
	GameState.equipped_weapon_ids = _keys_to_string_name(_values_to_stringnames(data.get("equipped_weapon_ids", {})))
	GameState.resources = data.get("resources", {})
	# JSON читає числа як float — прогрес квестів тримаємо цілими.
	var quests: Dictionary = data.get("quests", {})
	for id: String in quests:
		var entry: Dictionary = quests[id]
		var progress: Array = entry.get("progress", [])
		for i in progress.size():
			progress[i] = int(progress[i])
	GameState.quests = quests
	var haven: Dictionary = data.get("haven", {})
	var boons: Dictionary = haven.get("boons", {})
	for id: String in boons:
		boons[id] = int(boons[id])
	GameState.haven = haven
	GameState.character = data.get("character", {})
	GameState.inventory = _items_from_json(data.get("inventory", []))
	GameState.equipped_store = _items_from_json(data.get("equipped_store", []))
	GameState.equipment = data.get("equipment", {})
	GameState.stash = _items_from_json(data.get("stash", []))
	GameState.hero_level = int(data.get("hero_level", 1))
	GameState.hero_xp = int(data.get("hero_xp", 0))
	GameState.talents = data.get("talents", {})
	GameState.talent_resets = int(data.get("talent_resets", 0))
	GameState.bonus_talent_points = int(data.get("bonus_talent_points", 0))
	GameState.skill_loadout = data.get("skill_loadout", {})
	GameState.discovered = data.get("discovered", {})
	# Старі сейви: усе, що вже є в торбі, надіте чи в скрині — відкрите.
	for list: Array in [GameState.inventory, GameState.equipped_store, GameState.stash]:
		for item: Dictionary in list:
			GameState.discovered[String(item.get("base", ""))] = true
	# Сейв із часів до спорядження (давній гравець): він уже пройшов
	# стартові квести, тож не голий — у простому одязі й з мечем.
	if not data.has("inventory") and int(data.get("completed_runs", 0)) > 0:
		for base: String in ["peasant_shirt", "peasant_pants", "peasant_shoes", "iron_sword"]:
			var item := ItemDb.roll(base, "common")
			GameState.equipped_store.append(item)
			GameState.equipment[ItemDb.slot_of(item)] = item.uid

## JSON читає числа як float — характеристики речей тримаємо цілими.
## Що надіто на героя id (слот -> річ) — прямо з його файлу, не
## перемикаючи активного героя (для екрана вибору).
func equipped_of(id: String) -> Dictionary:
	var path := _char_path(id)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return {}
	var store := _items_from_json((data as Dictionary).get("equipped_store", []))
	var result := {}
	var equipment: Dictionary = (data as Dictionary).get("equipment", {})
	for slot: String in equipment:
		for item: Dictionary in store:
			if String(item.get("uid", "")) == String(equipment[slot]):
				result[slot] = item
	return result

func _items_from_json(list: Array) -> Array:
	for item: Dictionary in list:
		var stats: Dictionary = item.get("stats", {})
		for stat: String in stats:
			stats[stat] = int(stats[stat])
		item["level"] = int(item.get("level", 1))
	return list

## Міграція між версіями схеми сейву — кожна пройдена версія лишає
## сейв у форматі наступної, тому старі сейви ніколи не ламаються.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = data.get("schema_version", 1)
	if version < 2:
		data = _migrate_v1_to_v2(data)
	if version < 3:
		data = _migrate_v2_to_v3(data)
	if version < 4:
		data = _migrate_v3_to_v4(data)
	if version < 5:
		data = _migrate_v4_to_v5(data)
	if version < 6:
		data = _rename_weapons(data, V6_WEAPON_RENAMES, 6)
	if version < 7:
		data = _rename_weapons(data, V7_WEAPON_RENAMES, 7)
	return data

## Перейменування зброї між версіями: куплене й споряджене переходить на
## нову зброю, дублікати (кілька старих -> одна нова) прибираються.
func _rename_weapons(data: Dictionary, renames: Dictionary, version: int) -> Dictionary:
	var owned: Array = []
	for id in data.get("owned_weapon_ids", []):
		var renamed: String = renames.get(str(id), str(id))
		if not owned.has(renamed):
			owned.append(renamed)
	data["owned_weapon_ids"] = owned
	var equipped: Dictionary = data.get("equipped_weapon_ids", {})
	for hero in equipped:
		equipped[hero] = renames.get(str(equipped[hero]), equipped[hero])
	data["equipped_weapon_ids"] = equipped
	data["schema_version"] = version
	return data

## v1 мав один спільний meta_upgrade_levels на всіх героїв разом; v2 —
## окремий прогрес на кожного героя (hero_meta_levels). Переносимо
## старі рівні на runewielder, щоб гравці не втратили вже куплене.
func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	if data.has("meta_upgrade_levels") and not data.has("hero_meta_levels"):
		data["hero_meta_levels"] = {"runewielder": data["meta_upgrade_levels"]}
	data.erase("meta_upgrade_levels")
	data["schema_version"] = 2
	return data

## v3 додав геми й дату встановлення. Сейв, створений до v3, належить
## гравцю, який уже грав раніше, — мітка 1 (давно) відкриває йому стартові
## набори одразу, а не змушує чекати 48 год з моменту оновлення гри.
func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
	if not data.has("install_timestamp"):
		data["install_timestamp"] = 1
	data["schema_version"] = 3
	return data

## v5 додав прогрес данжу: старі сейви починають з першого рівня.
func _migrate_v4_to_v5(data: Dictionary) -> Dictionary:
	data["dungeon_level"] = data.get("dungeon_level", 0)
	data["max_dungeon_level"] = data.get("max_dungeon_level", 0)
	data["schema_version"] = 5
	return data

## v4 додав зброю. Старому сейву просто дописуємо порожні списки —
## герой і далі б'ється стартовою зброєю, поки гравець не купить іншу.
func _migrate_v3_to_v4(data: Dictionary) -> Dictionary:
	data["owned_weapon_ids"] = data.get("owned_weapon_ids", [])
	data["equipped_weapon_ids"] = data.get("equipped_weapon_ids", {})
	data["schema_version"] = 4
	return data

## У словнику "герой -> зброя" в String треба перевести не лише ключі,
## а й значення (теж StringName).
func _values_to_strings(dict: Dictionary) -> Dictionary:
	var result := {}
	for key in dict:
		result[key] = str(dict[key])
	return result

func _values_to_stringnames(dict: Dictionary) -> Dictionary:
	var result := {}
	for key in dict:
		result[key] = StringName(dict[key])
	return result

## JSON не вміє StringName-ключі — переводимо в String перед записом.
func _keys_to_string(dict: Dictionary) -> Dictionary:
	var result := {}
	for key in dict:
		result[str(key)] = dict[key]
	return result

## І назад у StringName після читання, бо саме такі ключі очікує
## Hero.upgrade_levels/GameState.hero_meta_levels.
func _keys_to_string_name(dict: Dictionary) -> Dictionary:
	var result := {}
	for key in dict:
		result[StringName(key)] = dict[key]
	return result

## Те саме, що _keys_to_string()/_keys_to_string_name(), але для
## елементів масиву (GameState.unlocked_hero_ids) замість ключів словника.
func _stringnames_to_strings(arr: Array) -> Array:
	var result := []
	for item in arr:
		result.append(str(item))
	return result

func _strings_to_stringnames(arr: Array) -> Array:
	var result := []
	for item in arr:
		result.append(StringName(item))
	return result

## hero_meta_levels — словник словників (hero_id -> {upgrade_id: рівень}),
## обидва рівні ключів треба перевести в String для JSON і назад.
func _hero_levels_to_json(dict: Dictionary) -> Dictionary:
	var result := {}
	for hero_id in dict:
		result[str(hero_id)] = _keys_to_string(dict[hero_id])
	return result

func _hero_levels_from_json(dict: Dictionary) -> Dictionary:
	var result := {}
	for hero_id in dict:
		result[StringName(hero_id)] = _keys_to_string_name(dict[hero_id])
	return result
