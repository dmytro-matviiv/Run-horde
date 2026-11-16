extends RefCounted
class_name ItemDb

## ПРЕДМЕТИ: броня, зброя, прикраси.
##
## Заготовка (BASES) — що це за річ: слот, назва, з яких частин складається
## на персонажі (CharacterBuilder), до якого класу тяжіє, базові числа.
## Конкретна річ у торбі — словник:
##   {"uid": "i123", "base": "ranger_jacket", "rarity": "rare",
##    "stats": {"armor": 14, "hp": 22, "crit": 3}, "level": 1}
## Рідкість множить базові числа і додає випадкові властивості:
## сіра 0, зелена 1, синя 2, фіолетова 3, легендарна 4.
##
## Торба — GameState.inventory (масив речей), надіте —
## GameState.equipment (слот -> uid), скриня вдома — GameState.stash.

const SLOTS := ["helmet", "chest", "legs", "boots", "weapon", "amulet", "ring1", "ring2"]
const SLOT_TITLES := {"helmet": "Шолом", "chest": "Груди", "legs": "Штани", "boots": "Взуття", "weapon": "Зброя",
	"amulet": "Талісман", "ring1": "Кільце", "ring2": "Кільце"}
## Прикраси відкриваються з цього рівня.
const JEWELRY_LEVEL := 10

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_TITLES := {"common": "Звичайна", "uncommon": "Незвичайна", "rare": "Рідкісна", "epic": "Епічна", "legendary": "Легендарна"}
const RARITY_COLORS := {"common": Color(0.75, 0.75, 0.75), "uncommon": Color(0.45, 0.9, 0.4), "rare": Color(0.35, 0.65, 1.0),
	"epic": Color(0.75, 0.45, 1.0), "legendary": Color(1.0, 0.72, 0.2)}
const RARITY_POWER := {"common": 1.0, "uncommon": 1.25, "rare": 1.55, "epic": 1.9, "legendary": 2.4}
const RARITY_AFFIXES := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4}

## Характеристики: назва, одиниця, наскільки "добре" більше значення.
const STATS := {
	"hp": {"title": "Здоров'я", "suffix": "", "icon": "stat_hp"},
	"armor": {"title": "Броня", "suffix": "", "icon": "stat_armor"},
	"damage": {"title": "Шкода", "suffix": "%", "icon": "stat_damage"},
	"attack_speed": {"title": "Швидкість атаки", "suffix": "%", "icon": "stat_attack_speed"},
	"crit": {"title": "Критичний удар", "suffix": "%", "icon": "stat_crit"},
	"move_speed": {"title": "Швидкість руху", "suffix": "%", "icon": "stat_speed"},
	"mana": {"title": "Мана", "suffix": "", "icon": "boon_potion"},
	"mana_regen": {"title": "Відновлення мани", "suffix": "/с", "icon": "boon_potion"},
	"cooldown": {"title": "Перезарядка вмінь", "suffix": "%", "icon": "skill_rune_charge"},
	"regen": {"title": "Відновлення здоров'я", "suffix": "/с", "icon": "stat_hp"},
}
## Випадкові властивості: стат -> [мінімум, максимум] для сірої речі.
const AFFIX_RANGES := {
	"hp": [6, 14], "armor": [2, 5], "damage": [2, 5], "attack_speed": [2, 5], "crit": [1, 3],
	"move_speed": [1, 3], "mana": [6, 14], "mana_regen": [1, 2], "cooldown": [2, 4], "regen": [1, 2],
}

## Класи, до яких тяжіють речі (і дерево талантів).
const CLASSES := {"knight": "Мечник", "tank": "Танк", "mage": "Маг", "archer": "Лучник", "druid": "Друїд", "any": "Будь-хто"}

## Заготовки речей. parts — частини на персонажі (CharacterBuilder),
## base — числа сірої речі, class — до кого тяжіє.
const BASES := {
	"peasant_shirt": {"slot": "chest", "title": "Лляна сорочка", "parts": ["Peasant_Body", "Peasant_Arms"],
		"class": "any", "base": {"armor": 3, "hp": 8}},
	"ranger_jacket": {"slot": "chest", "title": "Шкіряна куртка", "parts": ["Ranger_Body", "Ranger_Arms"],
		"class": "archer", "base": {"armor": 6, "hp": 12, "attack_speed": 2}},
	"ranger_pauldron": {"slot": "chest", "title": "Куртка з наплічником", "parts": ["Ranger_Body", "Ranger_Arms", "Ranger_Acc_Pauldron"],
		"class": "knight", "base": {"armor": 9, "hp": 16}},
	"druid_robe": {"slot": "chest", "title": "Мантія мандрівника", "parts": ["Peasant_Body", "Ranger_Arms"],
		"class": "druid", "base": {"armor": 4, "hp": 10, "mana": 12}},
	"peasant_pants": {"slot": "legs", "title": "Лляні штани", "parts": ["Peasant_Legs"],
		"class": "any", "base": {"armor": 2, "hp": 6}},
	"ranger_pants": {"slot": "legs", "title": "Шкіряні штани", "parts": ["Ranger_Legs"],
		"class": "archer", "base": {"armor": 4, "hp": 9, "move_speed": 1}},
	"peasant_shoes": {"slot": "boots", "title": "Постоли", "parts": ["Peasant_Feet"],
		"class": "any", "base": {"armor": 1, "move_speed": 2}},
	"ranger_boots": {"slot": "boots", "title": "Чоботи слідопита", "parts": ["Ranger_Feet_Boots"],
		"class": "archer", "base": {"armor": 3, "move_speed": 3}},
	"ranger_hood": {"slot": "helmet", "title": "Каптур слідопита", "parts": ["Ranger_Head_Hood"],
		"class": "archer", "base": {"armor": 3, "crit": 2}},
	"mage_hood": {"slot": "helmet", "title": "Каптур чарівника", "parts": ["Ranger_Head_Hood"],
		"class": "mage", "base": {"armor": 2, "mana": 14, "cooldown": 2}},
	# Зброя: weapon — id з WeaponPool (модель і бій беруться звідти).
	"iron_sword": {"slot": "weapon", "title": "Залізний меч", "weapon": "war_blade", "class": "knight",
		"base": {"damage": 10}},
	"oak_staff": {"slot": "weapon", "title": "Дубовий посох", "weapon": "arcane_staff", "class": "mage",
		"base": {"damage": 8, "mana": 10}},
}

static var _counter := 0

## Нова річ заготовки base потрібної рідкості (числа — випадкові в межах).
static func roll(base_id: String, rarity: String = "common", level: int = 1) -> Dictionary:
	var base: Dictionary = BASES[base_id]
	var power: float = RARITY_POWER.get(rarity, 1.0) * (1.0 + 0.08 * (level - 1))
	var stats := {}
	for stat: String in base.base:
		stats[stat] = maxi(1, roundi(float(base.base[stat]) * power * randf_range(0.9, 1.1)))
	var pool := AFFIX_RANGES.keys()
	pool.shuffle()
	var extra: int = RARITY_AFFIXES.get(rarity, 0)
	for stat: String in pool:
		if extra <= 0:
			break
		var range_: Array = AFFIX_RANGES[stat]
		var value := roundi(randf_range(range_[0], range_[1]) * power)
		stats[stat] = int(stats.get(stat, 0)) + maxi(1, value)
		extra -= 1
	_counter += 1
	return {"uid": "i%d%d" % [Time.get_ticks_msec(), _counter], "base": base_id, "rarity": rarity, "stats": stats, "level": level}

static func base_of(item: Dictionary) -> Dictionary:
	return BASES.get(String(item.get("base", "")), {})

static func slot_of(item: Dictionary) -> String:
	return String(base_of(item).get("slot", ""))

## "Рідкісна Шкіряна куртка" — назва з рідкістю (сіра — без префікса).
static func title_of(item: Dictionary) -> String:
	return String(base_of(item).get("title", "Річ"))

static func color_of(item: Dictionary) -> Color:
	return RARITY_COLORS.get(item.get("rarity", "common"), Color.WHITE)

## Іконка речі: своя (kit/icons/item_<заготовка>), зброя — з WeaponPool,
## інакше — значок слота.
static func icon_of(item: Dictionary) -> Texture2D:
	var own := ArtSlots.kit_icon("item_" + String(item.get("base", "")))
	if own != null:
		return own
	var base := base_of(item)
	if base.has("weapon"):
		var def := WeaponPool.get_def(StringName(base.weapon))
		if def != null:
			var icon := ArtSlots.weapon_icon(def.id, def.icon)
			if icon != null:
				return icon
	return slot_icon(String(base.get("slot", "")))

static func slot_icon(slot: String) -> Texture2D:
	var names := {"helmet": "menu_heroes", "chest": "stat_armor", "legs": "stat_armor", "boots": "stat_speed",
		"weapon": "stat_damage", "amulet": "boon_potion", "ring1": "meta_luck", "ring2": "meta_luck"}
	return ArtSlots.kit_icon(names.get(slot, "stat_armor"))

## Що надіто: слот -> річ (лише ті, що справді є в торбі/надіті).
static func equipped_items() -> Dictionary:
	var result := {}
	for slot: String in GameState.equipment:
		var item := find(String(GameState.equipment[slot]))
		if not item.is_empty():
			result[slot] = item
	return result

static func find(uid: String) -> Dictionary:
	for item: Dictionary in GameState.equipped_store:
		if item.uid == uid:
			return item
	for item: Dictionary in GameState.inventory:
		if item.uid == uid:
			return item
	return {}

## Вигляд надітого для CharacterBuilder: слот -> {parts, rarity}.
static func gear_look(items: Dictionary = {}) -> Dictionary:
	if items.is_empty():
		items = equipped_items()
	var gear := {}
	for slot: String in items:
		var base := base_of(items[slot])
		if base.has("parts"):
			gear[slot] = {"parts": base.parts, "rarity": items[slot].rarity}
	return gear

## Сума характеристик усіх надітих речей.
static func total_stats(items: Dictionary = {}) -> Dictionary:
	if items.is_empty():
		items = equipped_items()
	var total := {}
	for slot: String in items:
		var stats: Dictionary = items[slot].get("stats", {})
		for stat: String in stats:
			total[stat] = int(total.get(stat, 0)) + int(stats[stat])
	return total

## Чи можна вдягти: прикраси — з JEWELRY_LEVEL.
static func can_equip(item: Dictionary) -> bool:
	var slot := slot_of(item)
	if slot in ["amulet", "ring1", "ring2"]:
		return GameState.hero_level >= JEWELRY_LEVEL
	return slot != ""

## Вдягти річ із торби: попередня в цьому слоті повертається в торбу.
static func equip(uid: String) -> void:
	var item: Dictionary = {}
	for candidate: Dictionary in GameState.inventory:
		if candidate.uid == uid:
			item = candidate
	if item.is_empty() or not can_equip(item):
		return
	var slot := slot_of(item)
	unequip(slot)
	GameState.inventory.erase(item)
	GameState.equipped_store.append(item)
	GameState.equipment[slot] = uid
	GameState.equipment_changed.emit()
	SaveManager.save_game()

## Зняти річ зі слоту в торбу.
static func unequip(slot: String) -> void:
	var uid := String(GameState.equipment.get(slot, ""))
	if uid == "":
		return
	for item: Dictionary in GameState.equipped_store.duplicate():
		if item.uid == uid:
			GameState.equipped_store.erase(item)
			GameState.inventory.append(item)
	GameState.equipment.erase(slot)
	GameState.equipment_changed.emit()
	SaveManager.save_game()

## Покласти річ у торбу (нагорода, здобич).
static func give(item: Dictionary) -> void:
	GameState.inventory.append(item)
	GameState.equipment_changed.emit()
	SaveManager.save_game()

## Порівняння: стат -> різниця (нова мінус надіта в тому ж слоті).
static func compare(item: Dictionary) -> Dictionary:
	var current := find(String(GameState.equipment.get(slot_of(item), "")))
	var keys := {}
	for stat: String in item.get("stats", {}):
		keys[stat] = true
	for stat: String in current.get("stats", {}):
		keys[stat] = true
	var diff := {}
	for stat: String in keys:
		diff[stat] = int(item.get("stats", {}).get(stat, 0)) - int(current.get("stats", {}).get(stat, 0))
	return diff
