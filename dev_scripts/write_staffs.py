# Посохи Чарівниці (колишньої Жриці Багаття) з набору Zsky.
# Запуск із папки проєкту: python D:/RuneHorde_work/scripts/write_staffs.py
import io
import os

TEMPLATE = '''[gd_resource type="Resource" load_steps=2 format=3]

[ext_resource type="Script" path="res://data/weapons/weapon_def.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{id}"
title = "{title}"
description = "{description}"
hero_id = &"ember_priestess"
cost_gold = {gold}
cost_gems = 0
archetype = "projectile"
damage = {damage2d}
cooldown = {interval}
color = Color({color}, 1)
projectile_speed = 420.0
muzzle_offset = Vector3({muzzle})
spell = "{spell}"
cast_interval = {interval}
spell_speed = {speed}
staff_skill = &"{skill}"
style_3d = "staff"
damage_mult_3d = {dmg}
speed_mult_3d = 1.0
knockback_mult_3d = 0.6
grip_offset = Vector3({grip})
grip_rotation_deg = Vector3(0, 0, 90)
model_scale = {scale}
'''

STAFFS = [
    dict(id='arcane_staff', title='Арканний посох', gold=0, damage2d=10.0, interval=0.55,
         color='0.78, 0.45, 1.0', spell='arcane', speed=17.0, skill='arcane_barrage', dmg=0.8,
         muzzle='0, 2.142, 0', grip='-0.003451, 0.001176, -0.000273', scale=0.1409,
         description='Стартовий посох: арканні стріли самі доводяться на ціль. Особливе — «Арканний залп»: вісім стріл розлітаються й шукають ворогів довкола.'),
    dict(id='ice_staff', title='Крижаний посох', gold=3000, damage2d=10.0, interval=0.7,
         color='0.55, 0.85, 1.0', spell='frost', speed=19.0, skill='frost_nova', dmg=0.75,
         muzzle='0.022, 2.87, 0.016', grip='-0.000654, 0.001176, -0.000273', scale=0.1297,
         description='Крижані уламки сповільнюють ворога, а третій поспіль заморожує його в брилу. Особливе — «Крижана нова»: хвиля холоду заморожує всіх довкола.'),
    dict(id='venom_staff', title='Посох трясовини', gold=4500, damage2d=8.0, interval=0.8,
         color='0.45, 0.95, 0.3', spell='venom', speed=13.0, skill='venom_swamp', dmg=0.55,
         muzzle='-0.092, 1.414, -0.006', grip='-0.003846, 0.001176, -0.000273', scale=0.15,
         description='Отруйна куля лишає на влучанні хмару, що труїть усіх у ній. Особливе — «Отруйне болото»: велика трясовина сповільнює й труїть.'),
    dict(id='moon_staff', title='Місячний посох', gold=7000, damage2d=14.0, interval=0.95,
         color='1.0, 0.92, 0.45', spell='lightning', speed=40.0, skill='moon_storm', dmg=1.0,
         muzzle='-0.211, 3.844, 0', grip='0.000108, 0.001176, -0.000273', scale=0.143,
         description='Блискавка б\'є ціль і перескакує ще на трьох ворогів поруч. Особливе — «Місячна буря»: промені з неба б\'ють по ворогах довкола.'),
]

for staff in STAFFS:
    io.open('data/weapons/%s.tres' % staff['id'], 'w', encoding='utf-8', newline='\n').write(TEMPLATE.format(**staff))

p = 'scripts/systems/weapon_pool.gd'
s = io.open(p, encoding='utf-8').read()
old = '''	preload("res://data/weapons/ember_bolt.tres"),
	preload("res://data/weapons/flamethrower.tres"),
	preload("res://data/weapons/pyre_totem.tres"),
	preload("res://data/weapons/sun_lance.tres"),
'''
new = '''	# Чарівниця: посохи, кожен зі своїми чарами й особливою здібністю.
	preload("res://data/weapons/arcane_staff.tres"),
	preload("res://data/weapons/ice_staff.tres"),
	preload("res://data/weapons/venom_staff.tres"),
	preload("res://data/weapons/moon_staff.tres"),
'''
if old in s:
    s = s.replace(old, new)
    io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
for old_id in ['ember_bolt', 'flamethrower', 'pyre_totem', 'sun_lance']:
    path = 'data/weapons/%s.tres' % old_id
    if os.path.exists(path):
        os.remove(path)
print('ok')
