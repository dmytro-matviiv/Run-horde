extends Node

## Автозавантаження: читає й пише прогрес гравця (GameState) у
## user://save.json. schema_version дозволяє мігрувати старі сейви
## замість того, щоб ламати прогрес гравців при оновленні структури
## файлу.

const SAVE_PATH := "user://save.json"
const CURRENT_SCHEMA_VERSION := 7

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
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не вдалось відкрити файл сейву для запису: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Не вдалось відкрити файл сейву для читання: %s" % SAVE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Сейв пошкоджений, ігнорую: %s" % SAVE_PATH)
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
