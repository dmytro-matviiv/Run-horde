# -*- coding: utf-8 -*-
import os
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:60])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


patch('scripts/autoload/game_state.gd', [
    ("""	&"talent_aura_power": 3,
}""",
     """	&"talent_aura_power": 3,
	&"talent_shadow_clones": 3,
}"""),
    ("""func is_hero_unlocked(id: StringName) -> bool:""",
     """## Преміум-герой купується за геми, а не за золото (HeroDef.gem_cost).
func unlock_hero_with_gems(id: StringName) -> bool:
	if is_hero_unlocked(id):
		return false
	var def := HeroPool.get_def(id)
	if def.gem_cost <= 0 or not spend_gems(def.gem_cost):
		return false
	unlocked_hero_ids.append(id)
	SaveManager.save_game()
	return true

# Зброя (WeaponPool). Стартова зброя героя безкоштовна й доступна
# завжди; решту купують за геми. Спорядження — окреме на кожного
# героя: сокира вартової не з'являється в руках жриці.
var owned_weapon_ids: Array = []          # StringName
var equipped_weapon_ids: Dictionary = {}  # StringName (hero_id) -> StringName (weapon_id)

func is_weapon_owned(id: StringName) -> bool:
	return WeaponPool.get_def(id).cost_gems <= 0 or owned_weapon_ids.has(id)

## Повертає true, якщо зброю куплено (вистачило гемів і її ще не було).
func buy_weapon(id: StringName) -> bool:
	if is_weapon_owned(id):
		return false
	var def := WeaponPool.get_def(id)
	if not spend_gems(def.cost_gems):
		return false
	owned_weapon_ids.append(id)
	SaveManager.save_game()
	return true

## Спорядити зброю героєві. Чужу зброю (іншого героя) взяти не можна —
## асортимент у кожного свій.
func equip_weapon(hero_id: StringName, weapon_id: StringName) -> bool:
	var def := WeaponPool.get_def(weapon_id)
	if def.hero_id != hero_id or not is_weapon_owned(weapon_id):
		return false
	equipped_weapon_ids[hero_id] = weapon_id
	SaveManager.save_game()
	return true

## Чим герой б'ється зараз. Якщо нічого не спорядили — стартова зброя.
func get_equipped_weapon_id(hero_id: StringName) -> StringName:
	var equipped: StringName = equipped_weapon_ids.get(hero_id, &"")
	if equipped != &"" and is_weapon_owned(equipped):
		return equipped
	return WeaponPool.get_starter_for_hero(hero_id).id

func is_hero_unlocked(id: StringName) -> bool:"""),
])

patch('scripts/autoload/save_manager.gd', [
    ('const CURRENT_SCHEMA_VERSION := 3', 'const CURRENT_SCHEMA_VERSION := 4'),
    ("""		"claimed_starter_packs": _stringnames_to_strings(GameState.claimed_starter_packs),
	}""",
     """		"claimed_starter_packs": _stringnames_to_strings(GameState.claimed_starter_packs),
		"owned_weapon_ids": _stringnames_to_strings(GameState.owned_weapon_ids),
		"equipped_weapon_ids": _keys_to_string(_values_to_strings(GameState.equipped_weapon_ids)),
	}"""),
    ("""	GameState.claimed_starter_packs = _strings_to_stringnames(data.get("claimed_starter_packs", []))""",
     """	GameState.claimed_starter_packs = _strings_to_stringnames(data.get("claimed_starter_packs", []))
	GameState.owned_weapon_ids = _strings_to_stringnames(data.get("owned_weapon_ids", []))
	GameState.equipped_weapon_ids = _keys_to_string_name(_values_to_stringnames(data.get("equipped_weapon_ids", {})))"""),
    ("""	if version < 3:
		data = _migrate_v2_to_v3(data)
	return data""",
     """	if version < 3:
		data = _migrate_v2_to_v3(data)
	if version < 4:
		data = _migrate_v3_to_v4(data)
	return data"""),
    ("""## JSON не вміє StringName-ключі""",
     """## v4 додав зброю. Старому сейву просто дописуємо порожні списки —
## герой і далі б'ється стартовою зброєю, поки гравець не купить іншу.
func _migrate_v3_to_v4(data: Dictionary) -> Dictionary:
	data["owned_weapon_ids"] = data.get("owned_weapon_ids", [])
	data["equipped_weapon_ids"] = data.get("equipped_weapon_ids", {})
	data["schema_version"] = 4
	return data

## У словнику "герой -> зброя" в String треба перевести не лише ключі,
## а й значення (теж StringName).
func _values_to_strings(dict: Dictionary) -> Dictionary:
	var result := {}
	for key in dict:
		result[key] = str(dict[key])
	return result

func _values_to_stringnames(dict: Dictionary) -> Dictionary:
	var result := {}
	for key in dict:
		result[key] = StringName(dict[key])
	return result

## JSON не вміє StringName-ключі"""),
])

patch('scenes/ui/meta_upgrades.gd', [
    ("""	&"talent_aura_power": {"title": "Багаття Люті", "per_level": "+радіус і шкода аури"},
}""",
     """	&"talent_aura_power": {"title": "Багаття Люті", "per_level": "+радіус і шкода аури"},
	&"talent_shadow_clones": {"title": "Володар Тіней", "per_level": "клони приходять частіше й б'ють сильніше"},
}"""),
])

# Герой: доступ до рівнів талантів для класових умінь
patch('scenes/run/hero.gd', [
    ("""	_meta_talent_bolt_pierce = meta_levels.get(&"talent_bolt_pierce", 0)""",
     """	_meta_levels = meta_levels
	_meta_talent_bolt_pierce = meta_levels.get(&"talent_bolt_pierce", 0)"""),
    ("""var _meta_talent_aura_power := 0""",
     """var _meta_talent_aura_power := 0
# Повний словник мета-рівнів — класові вміння читають свій талант
# самі (get_meta_talent_level), щоб герой не знав про кожне вміння.
var _meta_levels: Dictionary = {}"""),
    ("""func get_luck_bonus() -> float:""",
     """## Рівень будь-якого мета-таланту цього героя — для класових умінь.
func get_meta_talent_level(id: StringName) -> int:
	return _meta_levels.get(id, 0)

func get_luck_bonus() -> float:"""),
])

# Асасин: талант "Володар Тіней" пришвидшує клонів
patch('scripts/systems/abilities/shadow_kit.gd', [
    ("""var _kills := 0
var _smoke_cooldown_left := 0.0""",
     """var _kills := 0
var _smoke_cooldown_left := 0.0
var _talent_level := 0

func _on_setup() -> void:
	# Талант "Володар Тіней" (мета-прокачка асасина): клони приходять
	# після меншої кількості вбивств і б'ють сильніше.
	_talent_level = hero.get_meta_talent_level(&"talent_shadow_clones")

func _get_kills_per_clones() -> int:
	return maxi(KILLS_PER_CLONES - 2 * _talent_level, 6)"""),
    ("""	_kills += 1
	if _kills % KILLS_PER_CLONES == 0:
		_summon_clones()""",
     """	_kills += 1
	if _kills % _get_kills_per_clones() == 0:
		_summon_clones()"""),
    ("""		clone.spawn(hero, Vector2(cos(angle), sin(angle)) * 60.0, CLONE_DAMAGE * hero.get_damage_multiplier(), CLONE_LIFETIME)""",
     """		var damage := CLONE_DAMAGE * hero.get_damage_multiplier() * (1.0 + 0.2 * _talent_level)
		clone.spawn(hero, Vector2(cos(angle), sin(angle)) * 60.0, damage, CLONE_LIFETIME)"""),
    ("""	return float(_kills % KILLS_PER_CLONES) / float(KILLS_PER_CLONES)""",
     """	return float(_kills % _get_kills_per_clones()) / float(_get_kills_per_clones())"""),
    ("""	var left := KILLS_PER_CLONES - (_kills % KILLS_PER_CLONES)""",
     """	var left := _get_kills_per_clones() - (_kills % _get_kills_per_clones())"""),
])
print('all patched')
