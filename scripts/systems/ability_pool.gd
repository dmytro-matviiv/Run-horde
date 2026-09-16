extends RefCounted
class_name AbilityPool

## Реєстр класових умінь: HeroDef.ability_id -> клас уміння. Як
## HeroPool і WeaponPool — усе явним списком в одному місці.

const ABILITIES := {
	&"rune_charge": preload("res://scripts/systems/abilities/rune_charge.gd"),
	&"blade_rage": preload("res://scripts/systems/abilities/blade_rage.gd"),
	&"phoenix": preload("res://scripts/systems/abilities/phoenix_ability.gd"),
	&"shadow_kit": preload("res://scripts/systems/abilities/shadow_kit.gd"),
}

## Повертає новий вузол уміння або null, якщо в героя його немає.
static func create(ability_id: StringName) -> HeroAbility:
	if not ABILITIES.has(ability_id):
		return null
	return ABILITIES[ability_id].new()
