extends RefCounted
class_name LootTable

## ЗДОБИЧ З ВОРОГІВ. Що й з якою ймовірністю падає в данжі:
##   звичайний ворог — рідко (MOB_CHANCE), еліта — частіше;
##   бос — завжди одна річ (інколи дві), не гірша за зелену;
##   мега-бос (данжі 5, 10, 15) — дві речі, щонайменше сині.
## Що складніший данж, то частіше рідкісні речі й то вищий рівень речі
## (рівень = номер данжу: числа ростуть разом зі здоров'ям ворогів).
## Перевага — речам класу зброї в руках (CLASS_BIAS).

const MOB_CHANCE := 0.04
const ELITE_CHANCE := 0.22
const BOSS_SECOND := 0.35
const WEAPON_SHARE := 0.38
const CLASS_BIAS := 0.6
const MEGA_LEVELS := [4, 9, 14]
## Вага рідкостей на першому й на останньому данжі (між ними — плавно).
const WEIGHTS_EARLY := {"common": 62.0, "uncommon": 30.0, "rare": 7.0, "epic": 1.0, "legendary": 0.0}
const WEIGHTS_LATE := {"common": 12.0, "uncommon": 28.0, "rare": 32.0, "epic": 20.0, "legendary": 8.0}
const LAST_LEVEL := 14

## Що випало з ворога: масив речей (порожній — нічого).
static func roll_drop(level_index: int, is_boss: bool, is_elite: bool) -> Array:
	var result := []
	var mega := is_boss and MEGA_LEVELS.has(level_index)
	if mega:
		result.append(_item(level_index, "rare"))
		result.append(_item(level_index, "rare"))
	elif is_boss:
		result.append(_item(level_index, "uncommon"))
		if randf() < BOSS_SECOND:
			result.append(_item(level_index, "common"))
	elif randf() < (ELITE_CHANCE if is_elite else MOB_CHANCE):
		result.append(_item(level_index, "common", "epic"))
	return result

static func _item(level_index: int, min_rarity: String, max_rarity: String = "legendary") -> Dictionary:
	var rarity := _pick_rarity(level_index, min_rarity, max_rarity)
	var base_id := _pick_base(rarity)
	return ItemDb.roll(base_id, rarity, level_index + 1)

static func _pick_rarity(level_index: int, min_rarity: String, max_rarity: String) -> String:
	var t := clampf(float(level_index) / LAST_LEVEL, 0.0, 1.0)
	var lo := ItemDb.RARITIES.find(min_rarity)
	var hi := ItemDb.RARITIES.find(max_rarity)
	var total := 0.0
	var weights := {}
	for i in range(lo, hi + 1):
		var r: String = ItemDb.RARITIES[i]
		var w := lerpf(float(WEIGHTS_EARLY[r]), float(WEIGHTS_LATE[r]), t)
		# Мінімальна рідкість ніколи не має нульової ваги.
		weights[r] = maxf(w, 0.5 if i == lo else 0.0)
		total += weights[r]
	var roll := randf() * total
	for r: String in weights:
		roll -= float(weights[r])
		if roll <= 0.0:
			return r
	return min_rarity

## Заготовка: зброя (з тією самою рідкістю — у зброї вона своя) або броня.
## Частіше — під клас зброї в руках.
static func _pick_base(rarity: String) -> String:
	var cls := TalentTree.current_class()
	var want_weapon := randf() < WEAPON_SHARE
	var prefer_class := cls != "" and randf() < CLASS_BIAS
	var pool := []
	var fallback := []
	for id: String in ItemDb.BASES:
		var base: Dictionary = ItemDb.BASES[id]
		var is_weapon := String(base.slot) == "weapon"
		if is_weapon != want_weapon or String(base.slot) in ["amulet", "ring1", "ring2"]:
			continue
		# Зброя й сетові речі мають свою рідкість — беремо лише відповідні.
		if base.has("rarity") and String(base.rarity) != rarity:
			continue
		fallback.append(id)
		if not prefer_class or String(base.get("class", "any")) in [cls, "any"]:
			pool.append(id)
	if pool.is_empty():
		pool = fallback
	if pool.is_empty():
		# Зброї такої рідкості для класу немає — беремо броню.
		for id: String in ItemDb.BASES:
			if String(ItemDb.BASES[id].slot) in ["helmet", "chest", "legs", "boots"]:
				pool.append(id)
	return pool[randi() % pool.size()]
