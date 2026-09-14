extends Node

## Автозавантаження: читає й пише прогрес гравця (GameState) у
## user://save.json. schema_version дозволяє в майбутньому мігрувати
## старі сейви замість того, щоб ламати прогрес гравців при оновленні
## структури файлу.

const SAVE_PATH := "user://save.json"
const CURRENT_SCHEMA_VERSION := 1

func save_game() -> void:
	var data := {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"gold": GameState.gold,
		"meta_upgrade_levels": _keys_to_string(GameState.meta_upgrade_levels),
		"last_seen_timestamp": GameState.last_seen_timestamp,
		"last_chest_claim_timestamp": GameState.last_chest_claim_timestamp,
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
	GameState.meta_upgrade_levels = _keys_to_string_name(data.get("meta_upgrade_levels", {}))
	GameState.last_seen_timestamp = data.get("last_seen_timestamp", 0)
	GameState.last_chest_claim_timestamp = data.get("last_chest_claim_timestamp", 0)

## Міграція між версіями схеми сейву. Зараз версія лише одна (1),
## тож функція нічого не робить — сюди додаватимуться кроки міграції,
## коли з'явиться версія 2, а не буде ламати сейви гравців, зроблені
## на версії 1.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = data.get("schema_version", 1)
	if version < CURRENT_SCHEMA_VERSION:
		pass
	return data

## JSON не вміє StringName-ключі — переводимо в String перед записом.
func _keys_to_string(dict: Dictionary) -> Dictionary:
	var result := {}
	for key in dict:
		result[str(key)] = dict[key]
	return result

## І назад у StringName після читання, бо саме такі ключі очікує
## Hero.upgrade_levels/GameState.meta_upgrade_levels.
func _keys_to_string_name(dict: Dictionary) -> Dictionary:
	var result := {}
	for key in dict:
		result[StringName(key)] = dict[key]
	return result
