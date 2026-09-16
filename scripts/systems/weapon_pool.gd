extends RefCounted
class_name WeaponPool

## Реєстр усієї зброї гри — як HeroPool для героїв. Нова зброя
## додається сюди явно, щоб увесь асортимент було видно одним поглядом.
## Стартова зброя героя — та, у якої cost_gems = 0.

const ALL_WEAPONS: Array[WeaponDef] = [
	preload("res://data/weapons/rune_bolt.tres"),
	preload("res://data/weapons/staff_meteor.tres"),
	preload("res://data/weapons/storm_scepter.tres"),
	preload("res://data/weapons/frost_staff.tres"),

	preload("res://data/weapons/war_blade.tres"),
	preload("res://data/weapons/battle_axe.tres"),
	preload("res://data/weapons/blade_storm.tres"),
	preload("res://data/weapons/harpoon_glaive.tres"),

	preload("res://data/weapons/ember_bolt.tres"),
	preload("res://data/weapons/flamethrower.tres"),
	preload("res://data/weapons/pyre_totem.tres"),
	preload("res://data/weapons/sun_lance.tres"),

	preload("res://data/weapons/shadow_dagger.tres"),
	preload("res://data/weapons/venom_daggers.tres"),
	preload("res://data/weapons/void_scythe.tres"),
	preload("res://data/weapons/shadow_chains.tres"),
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
		if def.hero_id == hero_id and def.cost_gems == 0:
			return def
	return ALL_WEAPONS[0]
