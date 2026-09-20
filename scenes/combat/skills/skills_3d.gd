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
static func describe(hero: HeroDef) -> Array:
	var cards := []
	var passive := create_passive(hero.passive_id)
	if passive != null:
		cards.append({"title": passive.title, "text": passive.description, "color": passive.color, "kind": &"passive"})
	for skill: HeroSkill3D in create_for_hero(hero):
		cards.append({"title": skill.title, "text": skill.description, "color": skill.color, "kind": &"skill"})
	return cards
