# -*- coding: utf-8 -*-
# 3D-поля героїв і зброї + прив'язка моделі до Клинкової Вартової.
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


patch('data/heroes/hero_def.gd', [
    ('''@export_group("Спрайт-лист (куплений набір)")''',
     '''@export_group("3D: модель і бій")
## Модель героя (.glb). Порожньо — гра шукає файл за назвою героя:
## res://assets/models/heroes/<id>.glb. Немає й там — герой ходить
## тимчасовою моделлю, пофарбованою в його колір (гра працює, арт
## можна додати будь-коли).
@export var model_scene: PackedScene

## Кістка правої руки, до якої кріпиться зброя, і вбудована в модель
## зброя, яку треба сховати, коли герой бере іншу.
@export var weapon_bone: StringName = &"Wrist.R"
@export var builtin_weapon_node: StringName = &"Sword"

## Якщо в новій моделі анімації звуться інакше — тут перелік
## "наша назва" -> "назва в моделі". Порожньо = стандартні назви
## Quaternius (CharacterArmature|Idle, |Run, |Sword_Slash ...).
@export var animation_names: Dictionary = {}

## Активні здібності для кнопок у бою (Skills3D) і пасивна риса класу.
@export var skill_ids: Array[StringName] = []
@export var passive_id: StringName

@export_group("Спрайт-лист (куплений набір)")'''),
])

patch('data/weapons/weapon_def.gd', [
    ('''@export_group("Статус-ефект")''',
     '''@export_group("3D: зброя в руці")
## Модель зброї (.glb). Порожньо — гра шукає
## res://assets/models/weapons/<id>.glb, а якщо немає й там, збирає
## тимчасову зі простих фігур за стилем (WeaponModels).
@export var model_scene: PackedScene

## Стиль бою в 3D: від нього залежать і тимчасова модель, і те, як
## герой б'є (широкий замах сокири, довгий випад глефи, швидка серія
## парних клинків).
@export_enum("sword", "axe", "glaive", "twin_blades", "staff", "daggers")
var style_3d: String = "sword"

## Чим зброя відрізняється в бою. Множники до базового удару героя.
@export var damage_mult_3d: float = 1.0
@export var speed_mult_3d: float = 1.0
@export var knockback_mult_3d: float = 1.0
## Дальність замаху в метрах і його ширина в градусах.
@export var reach_3d: float = 2.9
@export var arc_3d: float = 150.0

## Як зброя лежить у руці (підганяється під конкретну модель).
@export var grip_offset := Vector3.ZERO
@export var grip_rotation_deg := Vector3.ZERO
@export var model_scale: float = 1.0

@export_group("Статус-ефект")'''),
])

# --- Герої: здібності, пасивки, модель Вартової ---
HERO_3D = {
    'blade_warden': {
        'skills': ['whirlwind', 'rage_dash'],
        'passive': 'rage',
        'model': 'res://assets/models/characters/hooded_adventurer.glb',
    },
    'runewielder': {'skills': ['rune_nova'], 'passive': 'rune_charge'},
    'ember_priestess': {'skills': ['fire_ring'], 'passive': 'phoenix'},
    'void_assassin': {'skills': ['smoke_veil'], 'passive': 'death_mark'},
}

for hero_id, cfg in HERO_3D.items():
    path = 'data/heroes/%s.tres' % hero_id
    s = open(path, encoding='utf-8').read()
    skills = ', '.join('&"%s"' % x for x in cfg['skills'])
    lines = ['skill_ids = Array[StringName]([%s])' % skills,
             'passive_id = &"%s"' % cfg['passive']]
    if 'model' in cfg:
        # Модель героя додається як зовнішній ресурс.
        ids = [int(m) for m in re.findall(r'id="(\d+)"', s)] or [1]
        new_id = max(ids) + 1
        s = s.replace('[resource]',
                      '[ext_resource type="PackedScene" path="%s" id="%d"]\n\n[resource]'
                      % (cfg['model'], new_id), 1)
        lines.append('model_scene = ExtResource("%d")' % new_id)
        s = re.sub(r'load_steps=(\d+)',
                   lambda m: 'load_steps=%d' % (int(m.group(1)) + 1), s, count=1)
    s = s.rstrip('\n') + '\n' + '\n'.join(lines) + '\n'
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('hero', hero_id)

# --- Зброя: як вона б'є в 3D ---
# reach — метри, arc — градуси, damage/speed/knockback — множники.
WEAPON_3D = {
    # Клинкова Вартова
    'war_blade':      ('sword', 1.0, 1.0, 1.0, 2.9, 150.0),
    'battle_axe':     ('axe', 1.45, 0.8, 1.7, 2.8, 170.0),
    'harpoon_glaive': ('glaive', 1.15, 0.95, 1.2, 3.9, 85.0),
    'blade_storm':    ('twin_blades', 0.75, 1.35, 0.6, 2.6, 180.0),
    # Руновод
    'rune_bolt':      ('staff', 0.9, 1.05, 0.8, 3.0, 140.0),
    'staff_meteor':   ('staff', 1.5, 0.75, 1.6, 3.0, 160.0),
    'storm_scepter':  ('staff', 1.0, 1.1, 0.9, 3.2, 150.0),
    'frost_staff':    ('staff', 0.95, 0.95, 1.1, 3.1, 150.0),
    # Жриця Багаття
    'ember_bolt':     ('staff', 0.95, 1.05, 0.8, 3.0, 140.0),
    'flamethrower':   ('staff', 0.8, 1.3, 0.5, 2.8, 170.0),
    'pyre_totem':     ('staff', 1.2, 0.85, 1.2, 3.0, 150.0),
    'sun_lance':      ('glaive', 1.3, 0.85, 1.3, 3.8, 90.0),
    # Асасин Порожнечі
    'shadow_dagger':  ('daggers', 0.7, 1.4, 0.5, 2.4, 130.0),
    'venom_daggers':  ('daggers', 0.75, 1.45, 0.5, 2.4, 140.0),
    'void_scythe':    ('glaive', 1.35, 0.9, 1.4, 3.6, 120.0),
    'shadow_chains':  ('twin_blades', 0.9, 1.15, 0.9, 3.2, 170.0),
}

for weapon_id, (style, damage, speed, knockback, reach, arc) in WEAPON_3D.items():
    path = 'data/weapons/%s.tres' % weapon_id
    s = open(path, encoding='utf-8').read().rstrip('\n')
    s += ('\nstyle_3d = "%s"\ndamage_mult_3d = %s\nspeed_mult_3d = %s\n'
          'knockback_mult_3d = %s\nreach_3d = %s\narc_3d = %s\n'
          % (style, damage, speed, knockback, reach, arc))
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('weapons ok')
