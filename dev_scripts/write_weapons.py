# Хват для наявної зброї Вартової і чотири нові клинки з набору MiniPoly.
# Запуск із папки проєкту: python D:/RuneHorde_work/scripts/write_weapons.py
import io
import re


def set_fields(path, fields, description=None, title=None):
    s = io.open(path, encoding='utf-8').read()
    for key, value in fields.items():
        line = '%s = %s' % (key, value)
        pattern = r'(?m)^%s = .*$' % re.escape(key)
        if re.search(pattern, s):
            s = re.sub(pattern, lambda _m: line, s)
        else:
            s = s.rstrip('\n') + '\n' + line + '\n'
    if description is not None:
        s = re.sub(r'(?m)^description = ".*"$', lambda _m: 'description = "%s"' % description, s)
    if title is not None:
        s = re.sub(r'(?m)^title = ".*"$', lambda _m: 'title = "%s"' % title, s)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


set_fields('data/weapons/battle_axe.tres', {
    'grip_offset': 'Vector3(-0.001136, 0.000911, -0.000273)',
    'grip_rotation_deg': 'Vector3(0, 0, 90)',
    'model_scale': '1.8363',
})
set_fields('data/weapons/harpoon_glaive.tres', {
    'grip_offset': 'Vector3(0.005312, 0.001174, -0.000497)',
    'grip_rotation_deg': 'Vector3(0, 0, 90)',
    'model_scale': '0.3003',
}, title='Тризуб',
    description="Тризуб на довгому держаку: б'є далі за все інше й прошиває ворогів, що стоять у ряд.")
set_fields('data/weapons/blade_storm.tres', {
    'grip_offset': 'Vector3(0.001354, 0.001176, -0.000273)',
    'grip_rotation_deg': 'Vector3(0, 0, 90)',
    'model_scale': '1.4407',
    'dual_wield': 'true',
}, description='Диявольський меч у кожній руці: швидка серія широких ударів ріже всіх довкола, хоч кожен удар і легший.')

TEMPLATE = '''[gd_resource type="Resource" load_steps=3 format=3]

[ext_resource type="Script" path="res://data/weapons/weapon_def.gd" id="1"]
[ext_resource type="Resource" path="res://data/vfx/wind_slash.tres" id="2"]

[resource]
script = ExtResource("1")
id = &"{id}"
title = "{title}"
description = "{description}"
hero_id = &"blade_warden"
cost_gold = {gold}
cost_gems = 0
archetype = "melee_arc"
damage = {damage2d}
cooldown = {cooldown2d}
color = Color({color}, 1)
melee_arc_deg = {arc2d}
melee_range = 115.0
swing_vfx = ExtResource("2")
style_3d = "{style}"
damage_mult_3d = {dmg}
speed_mult_3d = {speed}
knockback_mult_3d = {knock}
reach_3d = {reach}
arc_3d = {arc}
grip_offset = Vector3({grip})
grip_rotation_deg = Vector3(0, 0, 90)
model_scale = {scale}
{extra}'''

NEW = [
    dict(id='talwar', title='Талвар', gold=2400, damage2d=10.0, cooldown2d=0.7,
         color='0.95, 0.78, 0.3', arc2d=160.0,
         style='sword', dmg=0.85, speed=1.2, knock=0.75, reach=2.8, arc=185.0,
         grip='-0.000506, 0.001579, -0.000273', scale=1.1276, extra='',
         description='Вигнута шабля: легкі швидкі замахи дуже широкою дугою — зручно різати юрбу, що обступила.'),
    dict(id='twin_daggers', title='Парні кинджали', gold=3000, damage2d=7.0, cooldown2d=0.45,
         color='0.95, 0.55, 0.25', arc2d=110.0,
         style='daggers', dmg=0.6, speed=1.7, knock=0.4, reach=2.3, arc=130.0,
         grip='-0.001386, 0.001176, -0.000273', scale=0.2948, extra='dual_wield = true\n',
         description='Кинджал у кожній руці: найшвидші удари, але короткі й легкі — ворогів майже не відкидає. Що більше ударів, то швидше росте лють.'),
    dict(id='cleaver', title='Тесак', gold=4800, damage2d=30.0, cooldown2d=1.1,
         color='0.85, 0.3, 0.25', arc2d=100.0,
         style='axe', dmg=1.9, speed=0.68, knock=1.4, reach=2.5, arc=110.0,
         grip='-0.000824, 0.000696, -0.000273', scale=1.2592, extra='',
         description='Важкий тесак рубає повільно й вузько, зате кожен удар — найсильніший серед клинків. Для боса саме те.'),
    dict(id='devils_axe', title='Диявольська сокира', gold=8000, damage2d=40.0, cooldown2d=0.95,
         color='0.85, 0.15, 0.15', arc2d=170.0,
         style='axe', dmg=1.7, speed=0.85, knock=2.0, reach=3.1, arc=190.0,
         grip='-0.003948, 0.000928, -0.000273', scale=1.214, extra='',
         description='Сокира з багряним лезом: широкий, далекий і нищівний замах — найсильніша зброя вартової.'),
]
for w in NEW:
    io.open('data/weapons/%s.tres' % w['id'], 'w', encoding='utf-8', newline='\n').write(TEMPLATE.format(**w))

p = 'scripts/systems/weapon_pool.gd'
s = io.open(p, encoding='utf-8').read()
old = '''	preload("res://data/weapons/war_blade.tres"),
	preload("res://data/weapons/battle_axe.tres"),
	preload("res://data/weapons/blade_storm.tres"),
	preload("res://data/weapons/harpoon_glaive.tres"),
'''
new = '''	# Клинкова Вартова — від дешевшої до найсильнішої.
	preload("res://data/weapons/war_blade.tres"),
	preload("res://data/weapons/talwar.tres"),
	preload("res://data/weapons/twin_daggers.tres"),
	preload("res://data/weapons/harpoon_glaive.tres"),
	preload("res://data/weapons/battle_axe.tres"),
	preload("res://data/weapons/cleaver.tres"),
	preload("res://data/weapons/blade_storm.tres"),
	preload("res://data/weapons/devils_axe.tres"),
'''
if old in s:
    s = s.replace(old, new)
    io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
