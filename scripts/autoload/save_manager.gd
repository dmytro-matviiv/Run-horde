extends Node

## Автозавантаження: читає й пише прогрес гравця (GameState) у
## user://save.json. schema_version дозволяє мігрувати старі сейви
## замість того, щоб ламати прогрес гравців при оновленні структури
## файлу.

const SAVE_PATH := "user://save.json"
const CURRENT_SCHEMA_VERSION := 2

func save_game() -> void:
	var data := {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"gold": GameState.gold,
		"hero_meta_levels": _hero_levels_to_json(GameState.hero_meta_levels),
		"last_seen_timestamp": GameState.last_seen_timestamp,
		"last_chest_claim_timestamp": GameState.last_chest_claim_timestamp,
		"unlocked_hero_ids": _stringnames_to_strings(GameState.unlocked_hero_ids),
		"selected_hero_id": str(GameState.selected_hero_id),
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

## Міграція між версіями схеми сейву — кожна пройдена версія лишає
## сейв у форматі наступної, тому старі сейви ніколи не ламаються.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = data.get("schema_version", 1)
	if version < 2:
		data = _migrate_v1_to_v2(data)
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
