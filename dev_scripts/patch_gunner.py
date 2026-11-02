# -*- coding: utf-8 -*-
# Боєць замість асасина, вогнепальна зброя, купівля зброї за золото.
import os
import re
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:80])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


# --- WeaponDef: ціна в золоті + стрілецькі поля ---
patch('data/weapons/weapon_def.gd', [
    ('''## Чий це асортимент (id героя). Стартова зброя героя — cost_gems = 0.
@export var hero_id: StringName
@export var cost_gems: int = 0''',
     '''## Чий це асортимент (id героя). Стартова зброя героя — cost_gold = 0.
@export var hero_id: StringName
## Ціна в золоті. Числа тимчасові — баланс зведемо, коли буде більше
## рівнів і стабільний заробіток за похід.
@export var cost_gold: int = 0
## Лишилось від старої версії, де зброя купувалась за геми. Тепер уся
## зброя купується за золото; поле тримаємо, щоб не ламати збереження.
@export var cost_gems: int = 0'''),
    ('''@export_group("3D: зброя в руці")''',
     '''@export_group("3D: вогнепальна зброя")
## Зброя стріляє, а не б'є. Тоді герой не махає, а веде вогонь:
## затримка між пострілами, магазин і перезарядка.
@export var ranged_3d := false
@export var fire_interval := 0.35        # секунд між пострілами
@export var magazine := 12               # набоїв у магазині
@export var reload_time := 1.5
@export var bullet_speed := 45.0
@export var bullet_spread_deg := 2.0
@export var bullets_per_shot := 1
## Звідки вилітає куля відносно моделі зброї (кінчик ствола).
@export var muzzle_offset := Vector3(0, 0, 0.5)

@export_group("3D: зброя в руці")'''),
    ('''@export_enum("sword", "axe", "glaive", "twin_blades", "staff", "daggers")
var style_3d: String = "sword"''',
     '''@export_enum("sword", "axe", "glaive", "twin_blades", "staff", "daggers", "pistol", "rifle")
var style_3d: String = "sword"'''),
])

# --- Купівля зброї за золото ---
patch('scripts/autoload/game_state.gd', [
    ('''func is_weapon_owned(id: StringName) -> bool:
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
	return true''',
     '''func is_weapon_owned(id: StringName) -> bool:
	return WeaponPool.get_def(id).cost_gold <= 0 or owned_weapon_ids.has(id)

## Повертає true, якщо зброю куплено. Уся зброя купується за ЗОЛОТО —
## те саме, що заробляється в походах, тож данжі й крамниця пов'язані.
func buy_weapon(id: StringName) -> bool:
	if is_weapon_owned(id):
		return false
	var def := WeaponPool.get_def(id)
	if gold < def.cost_gold:
		return false
	gold -= def.cost_gold
	owned_weapon_ids.append(id)
	SaveManager.save_game()
	return true'''),
    ('''func get_equipped_weapon_id(hero_id: StringName) -> StringName:
	var equipped: StringName = equipped_weapon_ids.get(hero_id, &"")
	if equipped != &"" and is_weapon_owned(equipped):
		return equipped
	return WeaponPool.get_starter_for_hero(hero_id).id''',
     '''func get_equipped_weapon_id(hero_id: StringName) -> StringName:
	var equipped: StringName = equipped_weapon_ids.get(hero_id, &"")
	# Перевіряємо не лише "куплено", а й що ця зброя досі належить цьому
	# героєві: його арсенал міг змінитись між версіями гри.
	if equipped != &"":
		var def := WeaponPool.get_def(equipped)
		if def != null and def.hero_id == hero_id and is_weapon_owned(equipped):
			return equipped
	return WeaponPool.get_starter_for_hero(hero_id).id'''),
])

# --- Ціни старої зброї переводимо в золото (тимчасові числа) ---
for path in os.listdir('data/weapons'):
    if not path.endswith('.tres'):
        continue
    full = 'data/weapons/' + path
    s = open(full, encoding='utf-8').read()
    match = re.search(r'cost_gems = (\d+)', s)
    if match is None:
        continue
    gems = int(match.group(1))
    gold = 0 if gems == 0 else int(round(gems * 12 / 100.0)) * 100
    if 'cost_gold' not in s:
        s = s.replace('cost_gems = %d' % gems, 'cost_gold = %d\ncost_gems = %d' % (gold, gems), 1)
        open(full, 'w', encoding='utf-8', newline='\n').write(s)
print('ціни в золоті проставлено')

# --- Новий герой-боєць замість асасина (id лишається заради збережень) ---
s = open('data/heroes/void_assassin.tres', encoding='utf-8').read()
s = re.sub(r'title = ".*"', 'title = "Оперативник"', s, count=1)
s = re.sub(r'description = ".*"',
           'description = "Боєць із вогнепальною зброєю. Мітить ціль, а димова граната ховає його від ворогів."', s, count=1)
s = re.sub(r'color = Color\([^)]*\)', 'color = Color(0.45, 0.6, 0.75, 1)', s, count=1)
open('data/heroes/void_assassin.tres', 'w', encoding='utf-8', newline='\n').write(s)
print('герой оновлений')

# --- Чотири стволи ---
GUNS = [
    # id, назва, модель, ціна, опис, стиль, шкода, темп, магазин, перезарядка,
    # швидкість кулі, розкид, куль за постріл
    ('pistol_basic', 'Пістолет', 'pistol', 0,
     'Стартовий ствол: невеликий калібр, зате швидка перезарядка.',
     1.0, 0.36, 12, 1.3, 46.0, 2.0, 1),
    ('pistol_heavy', 'Важкий Пістолет', 'pistol', 3500,
     'Один набій — одна дірка. Б\'є вдвічі сильніше, але магазин малий.',
     2.0, 0.55, 8, 1.7, 52.0, 1.5, 1),
    ('rifle_standard', 'Автомат', 'rifle', 6000,
     'Черга без упину: слабші кулі, зате багато й швидко.',
     0.7, 0.12, 30, 2.1, 55.0, 3.5, 1),
    ('rifle_heavy', 'Штурмова Гвинтівка', 'rifle', 11000,
     'Важкі кулі й помітна віддача: б\'є боляче, темп нижчий за автомат.',
     1.35, 0.2, 24, 2.4, 60.0, 2.5, 1),
]

TEMPLATE = '''[gd_resource type="Resource" load_steps=2 format=3]

[ext_resource type="Script" path="res://data/weapons/weapon_def.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{id}"
title = "{title}"
description = "{description}"
hero_id = &"void_assassin"
cost_gold = {gold}
cost_gems = 0
archetype = "projectile"
damage = {damage_2d}
cooldown = {fire_interval}
color = Color({color})
projectile_speed = 700.0
style_3d = "{style}"
ranged_3d = true
damage_mult_3d = {damage}
speed_mult_3d = 1.0
knockback_mult_3d = 0.4
reach_3d = 18.0
arc_3d = 30.0
fire_interval = {fire_interval}
magazine = {magazine}
reload_time = {reload}
bullet_speed = {bullet_speed}
bullet_spread_deg = {spread}
bullets_per_shot = {bullets}
'''

COLORS = {
    'pistol_basic': '0.85, 0.87, 0.92, 1',
    'pistol_heavy': '0.95, 0.75, 0.35, 1',
    'rifle_standard': '0.6, 0.85, 1.0, 1',
    'rifle_heavy': '1.0, 0.55, 0.3, 1',
}

for (weapon_id, title, style, gold, description, damage, interval,
     magazine, reload, speed, spread, bullets) in GUNS:
    text = TEMPLATE.format(
        id=weapon_id, title=title, description=description, gold=gold, style=style,
        damage=damage, fire_interval=interval, magazine=magazine, reload=reload,
        bullet_speed=speed, spread=spread, bullets=bullets,
        damage_2d=round(damage * 14, 1), color=COLORS[weapon_id])
    open('data/weapons/%s.tres' % weapon_id, 'w', encoding='utf-8', newline='\n').write(text)
print('стволи створені')

# --- Реєстр зброї: замість старого арсеналу асасина ---
patch('scripts/systems/weapon_pool.gd', [
    ('''	preload("res://data/weapons/shadow_dagger.tres"),
	preload("res://data/weapons/venom_daggers.tres"),
	preload("res://data/weapons/void_scythe.tres"),
	preload("res://data/weapons/shadow_chains.tres"),''',
     '''	# Оперативник: вогнепальна зброя. Стартовий пістолет безкоштовний,
	# решта купується за золото.
	preload("res://data/weapons/pistol_basic.tres"),
	preload("res://data/weapons/pistol_heavy.tres"),
	preload("res://data/weapons/rifle_standard.tres"),
	preload("res://data/weapons/rifle_heavy.tres"),'''),
])
