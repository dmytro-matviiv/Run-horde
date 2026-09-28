extends RefCounted
class_name WeaponPool

## Реєстр усієї зброї гри — як HeroPool для героїв. Нова зброя
## додається сюди явно, щоб увесь асортимент було видно одним поглядом.
## Стартова зброя героя — та, у якої cost_gold = 0.

const ALL_WEAPONS: Array[WeaponDef] = [
	preload("res://data/weapons/rune_bolt.tres"),
	preload("res://data/weapons/staff_meteor.tres"),
	preload("res://data/weapons/storm_scepter.tres"),
	preload("res://data/weapons/frost_staff.tres"),

	# Клинкова Вартова — від дешевшої до найсильнішої.
	preload("res://data/weapons/war_blade.tres"),
	preload("res://data/weapons/talwar.tres"),
	preload("res://data/weapons/twin_daggers.tres"),
	preload("res://data/weapons/harpoon_glaive.tres"),
	preload("res://data/weapons/battle_axe.tres"),
	preload("res://data/weapons/cleaver.tres"),
	preload("res://data/weapons/blade_storm.tres"),
	preload("res://data/weapons/devils_axe.tres"),

	# Чарівниця: посохи, кожен зі своїми чарами й особливою здібністю.
	preload("res://data/weapons/arcane_staff.tres"),
	preload("res://data/weapons/ice_staff.tres"),
	preload("res://data/weapons/venom_staff.tres"),
	preload("res://data/weapons/moon_staff.tres"),

	# Оперативник: вогнепальна зброя. Стартовий пістолет безкоштовний,
	# решта купується за золото.
	preload("res://data/weapons/pistol_basic.tres"),
	preload("res://data/weapons/pistol_heavy.tres"),
	preload("res://data/weapons/rifle_standard.tres"),
	preload("res://data/weapons/rifle_heavy.tres"),
]

static func get_def(id: StringName) -> WeaponDef:
	for def in ALL_WEAPONS:
		if def.id == id:
			return def
	return ALL_WEAPONS[0]

## Уся зброя конкретного героя — стартова першою, далі платна.
static func get_for_hero(hero_id: StringName) -> Array[WeaponDef]:
	var result: Array[WeaponDef] = []
	for def in ALL_WEAPONS:
		if def.hero_id == hero_id:
			result.append(def)
	return result

## Безкоштовна стартова зброя героя — нею він б'ється, поки гравець
## не купив і не спорядив іншу.
static func get_starter_for_hero(hero_id: StringName) -> WeaponDef:
	for def in ALL_WEAPONS:
		if def.hero_id == hero_id and def.cost_gold <= 0:
			return def
	return ALL_WEAPONS[0]
