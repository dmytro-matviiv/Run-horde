extends RefCounted
class_name UpgradePool

## Пул усіх апгрейдів рану: знає повний список, вміє відбирати
## випадкові варіанти, яких гравець ще не вичерпав до максимуму.
##
## Додаючи новий апгрейд: створи .tres у data/upgrades/ і додай його
## сюди в ALL_UPGRADES — самого сканування папки свідомо немає, щоб
## список апгрейдів завжди був видно одним поглядом в одному місці.
const ALL_UPGRADES: Array[UpgradeDef] = [
	preload("res://data/upgrades/weapon_damage.tres"),
	preload("res://data/upgrades/weapon_cooldown.tres"),
	preload("res://data/upgrades/weapon_pierce.tres"),
	preload("res://data/upgrades/weapon_multishot.tres"),
	preload("res://data/upgrades/weapon_ricochet.tres"),
	preload("res://data/upgrades/max_hp.tres"),
	preload("res://data/upgrades/regen.tres"),
	preload("res://data/upgrades/armor.tres"),
	preload("res://data/upgrades/iframe_duration.tres"),
	preload("res://data/upgrades/move_speed.tres"),
	preload("res://data/upgrades/pickup_radius.tres"),
	preload("res://data/upgrades/gold_gain.tres"),
	preload("res://data/upgrades/xp_gain.tres"),
	preload("res://data/upgrades/crystal_magnet.tres"),
	preload("res://data/upgrades/orbital_blades.tres"),
	preload("res://data/upgrades/damage_aura.tres"),
]

const CHOICES_COUNT := 3
const OWNED_WEAPON_BOOST_CHANCE := 0.2

## Повертає до CHOICES_COUNT випадкових неповторюваних апгрейдів,
## яких гравець ще не вичерпав. З ~20% шансом підмішує вже взяту
## нову зброю (орбітальні клинки/аура), щоб гравець міг стабільніше
## прокачувати те, що вже почав будувати, а не тільки нові речі.
static func pick_choices(current_levels: Dictionary) -> Array[UpgradeDef]:
	var available: Array[UpgradeDef] = []
	for upgrade in ALL_UPGRADES:
		var current_level: int = current_levels.get(upgrade.id, 0)
		if current_level < upgrade.max_level:
			available.append(upgrade)
	available.shuffle()

	var result: Array[UpgradeDef] = []
	for i in mini(CHOICES_COUNT, available.size()):
		result.append(available[i])

	if result.size() == CHOICES_COUNT and randf() < OWNED_WEAPON_BOOST_CHANCE:
		var owned_weapon := _pick_owned_new_weapon(current_levels)
		if owned_weapon != null and not result.has(owned_weapon):
			result[randi() % result.size()] = owned_weapon

	return result

static func _pick_owned_new_weapon(current_levels: Dictionary) -> UpgradeDef:
	var candidates: Array[UpgradeDef] = []
	for upgrade in ALL_UPGRADES:
		if upgrade.category != "new_weapon":
			continue
		var current_level: int = current_levels.get(upgrade.id, 0)
		if current_level > 0 and current_level < upgrade.max_level:
			candidates.append(upgrade)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]
