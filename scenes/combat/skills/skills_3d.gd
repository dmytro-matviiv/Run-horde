extends RefCounted
class_name Skills3D

## Реєстр здібностей і пасивок для 3D-бою — як HeroPool для героїв.
## Нова здібність додається сюди одним рядком, і її одразу можна
## вписати героєві в data/heroes/<герой>.tres (поле skill_ids).

const SKILLS := {
	&"whirlwind": preload("res://scenes/combat/skills/whirlwind.gd"),
	&"rage_dash": preload("res://scenes/combat/skills/rage_dash.gd"),
	&"rune_nova": preload("res://scenes/combat/skills/rune_nova.gd"),
	&"fire_ring": preload("res://scenes/combat/skills/fire_ring.gd"),
	&"smoke_veil": preload("res://scenes/combat/skills/smoke_veil.gd"),
	# Особливі здібності посохів Чарівниці — кнопка з'являється лише з
	# відповідним посохом у руках (WeaponDef.staff_skill).
	&"arcane_barrage": preload("res://scenes/combat/skills/arcane_barrage.gd"),
	&"frost_nova": preload("res://scenes/combat/skills/frost_nova.gd"),
	&"venom_swamp": preload("res://scenes/combat/skills/venom_swamp.gd"),
	&"moon_storm": preload("res://scenes/combat/skills/moon_storm.gd"),
	# Особливі здібності зброї Руновода.
	&"great_seal": preload("res://scenes/combat/skills/great_seal.gd"),
	&"card_storm": preload("res://scenes/combat/skills/card_storm.gd"),
}

const PASSIVES := {
	&"rage": preload("res://scenes/combat/skills/passive_rage.gd"),
	&"rune_charge": preload("res://scenes/combat/skills/passive_rune_charge.gd"),
	&"phoenix": preload("res://scenes/combat/skills/passive_phoenix.gd"),
	&"death_mark": preload("res://scenes/combat/skills/passive_death_mark.gd"),
}

static func create_skill(id: StringName) -> HeroSkill3D:
	return SKILLS[id].new() if SKILLS.has(id) else null

static func create_passive(id: StringName) -> HeroPassive3D:
	return PASSIVES[id].new() if PASSIVES.has(id) else null

## Усі здібності героя — для кнопок у бою та для опису на екрані вибору.
static func create_for_hero(hero: HeroDef) -> Array[HeroSkill3D]:
	var result: Array[HeroSkill3D] = []
	if hero == null:
		return result
	for skill_id: StringName in hero.skill_ids:
		var skill := create_skill(skill_id)
		if skill != null:
			result.append(skill)
	return result

## Короткий опис здібностей героя для вітрини (екран вибору героя).
## weapon — споряджена зброя: у посоха є своя особлива здібність.
static func describe(hero: HeroDef, weapon: WeaponDef = null) -> Array:
	var cards := []
	var passive := create_passive(hero.passive_id)
	if passive != null:
		cards.append({"title": passive.title, "text": passive.description, "color": passive.color, "kind": &"passive", "id": passive.id})
	var skills := create_for_hero(hero)
	if weapon != null and weapon.staff_skill != &"":
		var staff_skill := create_skill(weapon.staff_skill)
		if staff_skill != null:
			skills.insert(0, staff_skill)
	for skill: HeroSkill3D in skills:
		cards.append({"title": skill.title, "text": skill.description, "color": skill.color, "kind": &"skill", "id": skill.id})
	return cards
