# -*- coding: utf-8 -*-
"""Генератор міста для Rune Horde.

Пише scenes/world/base_island.tscn і текстури землі. Усе, що
розставлено, лишається звичайними вузлами — їх можна рухати в
редакторі Godot. Під час гри однакові моделі автоматично пакуються
(TownBatcher), тож на телефоні місто лишається легким.

Одиниці — метри. Площа в (0, 0), північ — мінус Z (туди дивиться
камера на старті), данж — на півночі, ворота міста — на півдні.
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

PROJECT = r'D:\Claude code\idle survivor_like'
SIZES = json.load(open(r'D:\RuneHorde_work\logs\town_models.json', encoding='utf-8'))
ENV = 'res://assets/models/environment/'
DUN = 'res://assets/models/dungeon/'

random.seed(20260928)

# --- рельєф (та сама формула, що в town_ground.gdshader) ---
VALLEY_RADIUS = 38.0
HILL_HEIGHT = 18.0
HILL_WIDTH = 45.0


def hill(x, z):
    r = math.hypot(x, z)
    t = max(r - VALLEY_RADIUS, 0.0) / HILL_WIDTH
    a = math.atan2(z, x)
    wobble = 0.75 + 0.2 * math.sin(a * 3.0 + 1.3) + 0.12 * math.sin(a * 7.0 + 0.4)
    return (t ** 1.6) * HILL_HEIGHT * wobble


# --- ресурси сцени ---
ext = {}          # path -> id
ext_order = []


def res(path, kind='PackedScene'):
    if path not in ext:
        ext[path] = '%d' % (len(ext) + 10)
        ext_order.append((path, kind))
    return ext[path]


nodes = []        # готові блоки тексту вузлів


def fmt(v):
    return ('%.4f' % v).rstrip('0').rstrip('.') if abs(v) > 1e-9 else '0'


def transform(x, y, z, yaw=0.0, scale=1.0):
    c, s = math.cos(yaw), math.sin(yaw)
    basis = [c * scale, 0, -s * scale, 0, scale, 0, s * scale, 0, c * scale]
    return 'Transform3D(%s)' % ', '.join(fmt(v) for v in basis + [x, y, z])


def ground_y(model_path, scale):
    """Модель має стояти на землі: піднімаємо на її нижню точку."""
    key = model_path
    info = SIZES.get(key)
    if info is None:
        return 0.0
    return -info['min'][1] * scale


def place(parent, name, model_path, x, z, yaw=0.0, scale=1.0, y=None, on_hill=False):
    rid = res(model_path)
    # Центруємо модель: у багатьох моделей точка опори зсунута від
    # середини (у кінної статуї — на 4 метри), і без цього все стояло б
    # не там, де задумано.
    info = SIZES.get(model_path)
    if info is not None:
        cx = (info['min'][0] + info['size'][0] * 0.5) * scale
        cz = (info['min'][2] + info['size'][2] * 0.5) * scale
        c, sn = math.cos(yaw), math.sin(yaw)
        x -= cx * c + cz * sn
        z -= -cx * sn + cz * c
    if y is None:
        y = ground_y(model_path, scale)
        if on_hill:
            y += hill(x, z) - 0.3
    nodes.append('[node name="%s" parent="%s" instance=ExtResource("%s")]\ntransform = %s\n'
                 % (name, parent, rid, transform(x, y, z, yaw, scale)))


def plain(parent, name, node_type, x=0.0, y=0.0, z=0.0, extra=''):
    nodes.append('[node name="%s" type="%s" parent="%s"]\ntransform = %s\n%s'
                 % (name, node_type, parent, transform(x, y, z), extra))


def face_center(x, z):
    """Поворот, за якого "перед" моделі (+Z) дивиться на площу."""
    return math.atan2(-x, -z)


def polar(angle_deg, radius):
    a = math.radians(angle_deg)
    # 0° — північ (мінус Z), кут росте за годинниковою стрілкою (на схід).
    return math.sin(a) * radius, -math.cos(a) * radius


# ============================================================
# Маска доріжок (512 px на 128 м => 0.25 м на піксель)
# ============================================================
MASK_SIZE = 128.0
PX = 512


def to_px(x, z):
    return ((x / MASK_SIZE + 0.5) * PX, (z / MASK_SIZE + 0.5) * PX)


dirt = Image.new('L', (PX, PX), 0)
stone = Image.new('L', (PX, PX), 0)
shade = Image.new('L', (PX, PX), 0)
d_dirt = ImageDraw.Draw(dirt)
d_stone = ImageDraw.Draw(stone)
d_shade = ImageDraw.Draw(shade)


def path_line(draw, points, width_m):
    pts = [to_px(x, z) for x, z in points]
    width = int(width_m * PX / MASK_SIZE)
    draw.line(pts, fill=255, width=width, joint='curve')
    for p in pts:
        r = width / 2
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=255)


def disc(draw, x, z, radius_m, value=255):
    cx, cy = to_px(x, z)
    r = radius_m * PX / MASK_SIZE
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=value)


# ============================================================
# ПЛОЩА й головна вулиця (бруківка)
# ============================================================
disc(d_stone, 0, 0, 10.5)
# Головна вулиця: південні ворота -> площа -> ворота данжу.
path_line(d_stone, [(0, 34), (0, 8)], 5.0)
path_line(d_stone, [(0, -8), (0, -27)], 5.5)
disc(d_stone, 0, -28.5, 5.5)            # майданчик перед входом у данж

# Площа: кінна статуя в центрі.
nodes.append('[node name="Town" type="Node3D" parent="."]\n')
nodes.append('[node name="Plaza" type="Node3D" parent="Town"]\n')
place('Town/Plaza', 'Statue', DUN + 'Statue_Horse.fbx', 0, 0, math.radians(180), 0.9)

# ============================================================
# БУДІВЛІ, з якими можна взаємодіяти
# ============================================================
nodes.append('[node name="Buildings" type="Node3D" parent="."]\n')

INTERACTIVE = [
    # назва вузла, модель, x, z, масштаб, дія, підпис, колір підпису, поправка повороту
    # Моделі з малою кількістю матеріалів: кожен матеріал — окрема команда
    # відеокарті, а ці будівлі видно майже завжди.
    ('HeroesHall', ENV + 'Fortress.glb', -22, -4, 6.4, 'heroes', 'Зала героїв', (1, 0.92, 0.6), 0),
    ('Armory', ENV + 'Wooden Encampment.glb', -19, 17, 4.6, 'weapons', 'Збройня', (0.7, 0.9, 1.0), 0),
    ('Temple', ENV + 'Temple-CE2Mn7lh6A.glb', 22, -4, 3.3, 'talents', 'Храм талантів', (0.8, 1.0, 0.8), 0),
    ('Market', ENV + 'Market Stalls.glb', 19, 17, 5.2, 'shop', 'Ринок', (1.0, 0.82, 0.9), 0),
]

zones = []
for name, model, x, z, scale, action, title, color, yaw_fix in INTERACTIVE:
    yaw = face_center(x, z) + yaw_fix
    place('Buildings', name, model, x, z, yaw, scale)
    # Зона дії — між будівлею й площею, там, куди веде доріжка.
    dx, dz = -x, -z
    length = math.hypot(dx, dz)
    zx, zz = x + dx / length * 7.5, z + dz / length * 7.5
    zones.append((name + 'Zone', zx, zz, action, title, color))
    disc(d_dirt, zx, zz, 3.0)

# Вхід у данж — окрема зона перед аркою.
zones.append(('DungeonZone', 0, -26.5, 'portal', 'Вхід у данж', (0.78, 0.6, 1.0)))

# Доріжки від площі до кожної зони (ґрунт).
for name, zx, zz, action, title, color in zones:
    if action == 'portal':
        continue
    length = math.hypot(zx, zz)
    path_line(d_dirt, [(zx * 9.0 / length, zz * 9.0 / length), (zx, zz)], 3.4)

# Вулиця по колу вздовж ґанків будинків (без північного сектора, де
# вхід у данж).
street = [polar(a, 23.5) for a in range(36, 325, 6)]
path_line(d_dirt, street, 2.6)

# ============================================================
# ЖИТЛОВІ БУДИНКИ по колу
# ============================================================
nodes.append('[node name="Houses" type="Node3D" parent="Town"]\n')
# Кілька ПОВТОРЮВАНИХ легких моделей (2-4 матеріали) замість десяти
# різних: повтори пакуються в одну команду малювання, а кожна нова
# модель — це ще кілька команд для телефона.
HOUSES = [
    ('HallNW', ENV + 'Town Center Second Age.glb', -48, 29, 5.2),
    ('HouseNE', ENV + 'House.glb', 46, 28, 7.5),
    ('HouseE', ENV + 'Shack-HuzLJcbUd2.glb', 72, 29, 5.6),
    ('HouseW', ENV + 'House.glb', -72, 29, 7.5),
    ('WindmillE', ENV + 'Windmill-jpHoi9xDLG.glb', 112, 30, 5.2),
    ('ShackW', ENV + 'Shack-HuzLJcbUd2.glb', -114, 29, 5.6),
    ('HutSE', ENV + 'Hut-4MJWbyd6vw.glb', 150, 28, 7.2),
    ('HouseSW', ENV + 'House.glb', -150, 28, 7.2),
    ('HouseS2', ENV + 'House.glb', 132, 27, 7.0),
    ('HutS2', ENV + 'Hut-4MJWbyd6vw.glb', -132, 27, 7.2),
]
for name, model, angle, radius, scale in HOUSES:
    x, z = polar(angle, radius)
    place('Town/Houses', name, model, x, z, face_center(x, z), scale)
    # Коротка стежка від вулиці до ґанку.
    length = math.hypot(x, z)
    px, pz = x * (radius - 5.0) / length, z * (radius - 5.0) / length
    path_line(d_dirt, [polar(angle, 23.5), (px, pz)], 1.8)

# ============================================================
# СТІНИ, ВЕЖІ Й ВОРОТА
# ============================================================
nodes.append('[node name="Walls" type="Node3D" parent="Town"]\n')
WALL_RADIUS = 36.5
wall_model = ENV + 'Stone Wall.glb'
wall_scale = 5.2
wall_length = SIZES[wall_model]['size'][0] * wall_scale
angle_step = math.degrees(wall_length / WALL_RADIUS) * 0.97
angle = 38.0
index = 0
while angle < 322.0:
    # Проміжок під ворота на півдні.
    if 171.0 < angle < 189.0:
        angle += angle_step
        continue
    x, z = polar(angle + angle_step / 2, WALL_RADIUS)
    yaw = math.radians(-(angle + angle_step / 2))
    place('Town/Walls', 'Wall%d' % index, wall_model, x, z, yaw, wall_scale)
    disc(d_shade, x, z, 2.0, 140)
    index += 1
    angle += angle_step

for i, tower_angle in enumerate([40, 95, 145, 215, 265, 320]):
    x, z = polar(tower_angle, WALL_RADIUS + 0.5)
    place('Town/Walls', 'Tower%d' % i, ENV + 'Watch Tower.glb', x, z, face_center(x, z), 5.6)

gx, gz = polar(180, WALL_RADIUS)
place('Town/Walls', 'SouthGate', ENV + 'Castle Gate.glb', gx, gz, 0.0, 5.4)

# ============================================================
# ВХІД У ДАНЖ: скеля, арка, колони, смолоскипи, жаровні
# ============================================================
nodes.append('[node name="DungeonGate" type="Node3D" parent="Town"]\n')
GATE_Z = -31.0
place('Town/DungeonGate', 'Arch', DUN + 'Arch.fbx', 0, GATE_Z, 0.0, 1.75)
for side in (-1, 1):
    tag = 'L' if side < 0 else 'R'
    place('Town/DungeonGate', 'Column' + tag, DUN + 'Column.fbx', side * 5.4, GATE_Z + 0.4, 0.0, 1.2)
    place('Town/DungeonGate', 'Banner' + tag, DUN + 'Banner.fbx', side * 8.2, GATE_Z - 0.6, 0.0, 1.05)
    place('Town/DungeonGate', 'Brazier' + tag, DUN + 'Pedestal2.fbx', side * 3.6, GATE_Z + 5.2, 0.0, 0.55)
    place('Town/DungeonGate', 'Fire' + tag, DUN + 'Woodfire.fbx', side * 3.6, GATE_Z + 5.2, 0.0, 1.3,
          y=SIZES[DUN + 'Pedestal2.fbx']['size'][1] * 0.55 + 0.02)
    place('Town/DungeonGate', 'Skull' + tag, DUN + 'Skull.fbx', side * 6.8, GATE_Z + 3.0, side * 0.6, 1.4)
    for k in range(3):
        rx = side * (9.5 + k * 2.6 + random.uniform(-0.5, 0.5))
        rz = GATE_Z + 1.0 + random.uniform(-1.5, 2.5)
        place('Town/DungeonGate', 'Rock%s%d' % (tag, k), ENV + 'Rock-JmFMh7ztL9.glb', rx, rz,
              random.uniform(0, 6.28), random.uniform(3.5, 5.5))

# Скеля позаду: великі гори, в яких "вирубано" вхід.
nodes.append('[node name="Nature" type="Node3D" parent="."]\n')
nodes.append('[node name="Cliffs" type="Node3D" parent="Nature"]\n')
place('Nature/Cliffs', 'CliffCenter', ENV + 'Mountains.glb', 0, -52, math.radians(180), 9.5, y=-1.0)
place('Nature/Cliffs', 'CliffLeft', ENV + 'Mountain Group.glb', -27, -46, math.radians(160), 8.5, y=-0.5)
place('Nature/Cliffs', 'CliffRight', ENV + 'Mountain Group.glb', 27, -47, math.radians(200), 8.5, y=-0.5)

# ============================================================
# РЕКВІЗИТ біля будівель
# ============================================================
nodes.append('[node name="Props" type="Node3D" parent="Town"]\n')
PROPS = [
    # Збройня: бочки, ящики, колоди
    (DUN + 'Barrel.fbx', -13.5, 20.5, 0.8), (DUN + 'Barrel.fbx', -12.2, 21.4, 0.75),
    (DUN + 'Crate.fbx', -24.5, 12.0, 0.8), (DUN + 'Crate.fbx', -25.6, 13.3, 0.7),
    # Ринок: прилавки, бочки
    (ENV + 'Market Stalls.glb', 10.5, 23.0, 4.0), (ENV + 'Market Stalls.glb', 26.5, 9.5, 3.8),
    # Площа: прилавки з двох боків, бочки й ящики — щоб вона жила
    (ENV + 'Market Stalls.glb', 11.5, -6.5, 3.4), (ENV + 'Market Stalls.glb', -11.5, 6.5, 3.4),
    (DUN + 'Barrel.fbx', -13.2, 4.2, 0.7), (DUN + 'Crate.fbx', 13.4, -3.8, 0.7),
    (DUN + 'Barrel.fbx', 13.0, 22.0, 0.8), (DUN + 'Crate.fbx', 24.5, 22.0, 0.8),
    # Зала героїв: прапори
    (DUN + 'Banner.fbx', -16.5, -9.5, 0.9), (DUN + 'Banner.fbx', -16.5, 1.5, 0.9),
    # Храм: жаровні
    (DUN + 'Pedestal2.fbx', 16.0, -8.5, 0.5), (DUN + 'Pedestal2.fbx', 16.0, 0.5, 0.5),
]
for i, (model, x, z, scale) in enumerate(PROPS):
    place('Town/Props', 'Prop%d' % i, model, x, z, face_center(x, z) + random.uniform(-0.3, 0.3), scale)

# Каміння вздовж доріжок і біля стін.
for i in range(14):
    angle_deg = random.uniform(0, 360)
    if -40 < ((angle_deg + 180) % 360) - 180 < 40:
        continue
    x, z = polar(angle_deg, random.uniform(31, 34))
    place('Town/Props', 'Stone%d' % i, ENV + random.choice(['Rock-JmFMh7ztL9.glb', 'Rock-RtLRqYjfMs.glb']),
          x, z, random.uniform(0, 6.28), random.uniform(2.2, 3.4))

# ============================================================
# ПРИРОДА: дерева в місті, ліс на пагорбах, гори довкола
# ============================================================
nodes.append('[node name="Trees" type="Node3D" parent="Nature"]\n')
TOWN_TREES = [(-9, 28), (9, 29), (-30, 3), (30, 3), (-12, -24), (12, -24), (-28, -18), (28, -18)]
for i, (x, z) in enumerate(TOWN_TREES):
    place('Nature/Trees', 'TownTree%d' % i, ENV + 'Trees.glb', x, z, random.uniform(0, 6.28), 3.2)
    disc(d_shade, x, z, 3.5, 170)

nodes.append('[node name="Forest" type="Node3D" parent="Nature"]\n')
forest = 0
for ring_radius, count, scale in [(43, 16, 6.5), (56, 16, 8.5), (70, 14, 10.0)]:
    for k in range(count):
        angle_deg = k * 360.0 / count + random.uniform(-4, 4)
        # На півночі — скеля з входом у данж, ліс там не потрібен.
        if -32 < ((angle_deg + 180) % 360) - 180 < 32 and ring_radius < 60:
            continue
        x, z = polar(angle_deg, ring_radius + random.uniform(-3, 3))
        model = ENV + 'Pine Trees.glb'
        place('Nature/Forest', 'Forest%d' % forest, model, x, z, random.uniform(0, 6.28),
              scale * random.uniform(0.85, 1.15), on_hill=True)
        forest += 1

nodes.append('[node name="Mountains" type="Node3D" parent="Nature"]\n')
for k in range(12):
    angle_deg = k * 30.0 + random.uniform(-8, 8)
    x, z = polar(angle_deg, random.uniform(92, 108))
    model = ENV + ('Mountains.glb' if k % 2 == 0 else 'Mountain Group.glb')
    place('Nature/Mountains', 'Mountain%d' % k, model, x, z, face_center(x, z) + random.uniform(-0.5, 0.5),
          random.uniform(11, 14), y=hill(x, z) - 2.0)

for k in range(20):
    angle_deg = random.uniform(0, 360)
    x, z = polar(angle_deg, random.uniform(40, 62))
    place('Nature/Mountains', 'HillRock%d' % k, ENV + random.choice(['Rock-JmFMh7ztL9.glb', 'Rocks.glb']),
          x, z, random.uniform(0, 6.28), random.uniform(5, 9), on_hill=True)

# ============================================================
# ЗОНИ ДІЇ, ВОГНІ, ПОРТАЛ
# ============================================================
res('res://scenes/world/interactable.gd', 'Script')
for name, x, z, action, title, color in zones:
    extra = ('collision_layer = 0\ncollision_mask = 2\nscript = ExtResource("%s")\naction = "%s"\n'
             'title = "%s"\nlabel_height = 2.6\nlabel_color = Color(%s, %s, %s, 1)\n'
             % (ext['res://scenes/world/interactable.gd'], action, title, *color))
    plain('Buildings', name, 'Area3D', x, 0, z, extra)
    nodes.append('[node name="Shape" type="CollisionShape3D" parent="Buildings/%s"]\n'
                 'shape = SubResource("ZoneShape")\n' % name)

nodes.append('[node name="Effects" type="Node3D" parent="."]\n')
fire_points = [(-3.6, GATE_Z + 5.2, 1.65), (3.6, GATE_Z + 5.2, 1.65), (16.0, -8.5, 1.35), (16.0, 0.5, 1.35)]
for i, (x, z, y) in enumerate(fire_points):
    plain('Effects', 'Fire%d' % i, 'Marker3D', x, y, z)

res('res://scenes/world/portal.gdshader', 'Shader')
nodes.append('[node name="Portal" type="MeshInstance3D" parent="Effects"]\n'
             'transform = %s\nmesh = SubResource("PortalQuad")\nmaterial_override = SubResource("PortalMaterial")\n'
             'cast_shadow = 0\nmetadata/no_batch = true\n' % transform(0, 3.05, GATE_Z + 0.15))
nodes.append('[node name="PortalGlow" type="OmniLight3D" parent="Effects"]\n'
             'transform = %s\nlight_color = Color(0.66, 0.45, 1, 1)\nlight_energy = 3.0\nomni_range = 11.0\n'
             % transform(0, 2.6, GATE_Z + 3.0))

# ============================================================
# МЕЖІ: невидима стіна по колу, щоб герой не пішов у ліс
# ============================================================
nodes.append('[node name="Bounds" type="StaticBody3D" parent="."]\n')
SEGMENTS = 28
BOUND_RADIUS = 34.0
segment_length = 2 * math.pi * BOUND_RADIUS / SEGMENTS + 1.2
for k in range(SEGMENTS):
    angle_deg = k * 360.0 / SEGMENTS
    x, z = polar(angle_deg, BOUND_RADIUS)
    yaw = math.radians(-angle_deg)
    nodes.append('[node name="Edge%d" type="CollisionShape3D" parent="Bounds"]\ntransform = %s\n'
                 'shape = SubResource("EdgeShape")\n' % (k, transform(x, 2.0, z, yaw)))

# ============================================================
# ТЕКСТУРИ ЗЕМЛІ
# ============================================================
os.makedirs(os.path.join(PROJECT, 'assets', 'textures', 'town'), exist_ok=True)
dirt_img = dirt.filter(ImageFilter.GaussianBlur(3))
stone_img = stone.filter(ImageFilter.GaussianBlur(2))
shade_img = shade.filter(ImageFilter.GaussianBlur(10))
mask = Image.merge('RGB', (dirt_img, stone_img, shade_img))
mask.save(os.path.join(PROJECT, 'assets', 'textures', 'town', 'town_paths.png'))

# Безшовний шум для деталей трави й каменю.
N = 256
base = [[random.random() for _ in range(32)] for _ in range(32)]


def smooth_noise(u, v, grid):
    size = len(grid)
    x0, y0 = int(u) % size, int(v) % size
    x1, y1 = (x0 + 1) % size, (y0 + 1) % size
    fx, fy = u - int(u), v - int(v)
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = grid[y0][x0] * (1 - fx) + grid[y0][x1] * fx
    b = grid[y1][x0] * (1 - fx) + grid[y1][x1] * fx
    return a * (1 - fy) + b * fy


noise = Image.new('L', (N, N))
pixels = noise.load()
for y in range(N):
    for x in range(N):
        value = 0.0
        amplitude = 0.5
        frequency = 32.0 / N * 2
        for octave in range(4):
            value += smooth_noise(x * frequency, y * frequency, base) * amplitude
            amplitude *= 0.5
            frequency *= 2
        pixels[x, y] = int(max(0, min(255, value / 0.9375 * 255)))
noise.save(os.path.join(PROJECT, 'assets', 'textures', 'town', 'town_noise.png'))

# ============================================================
# ЗАПИС СЦЕНИ
# ============================================================
res('res://scenes/world/base_island.gd', 'Script')
res('res://scenes/world/player_3d.tscn')
res('res://scenes/world/camera_rig.tscn')
res('res://scenes/world/town_ground.gdshader', 'Shader')
res('res://assets/textures/town/town_paths.png', 'Texture2D')
res('res://assets/textures/town/town_noise.png', 'Texture2D')

header = ['[gd_scene format=3]\n']
for path, kind in ext_order:
    header.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, ext[path]))
header.append('')

sub = '''[sub_resource type="ProceduralSkyMaterial" id="Sky_mat"]
sky_top_color = Color(0.3, 0.52, 0.84, 1)
sky_horizon_color = Color(0.74, 0.82, 0.9, 1)
ground_bottom_color = Color(0.32, 0.38, 0.33, 1)
ground_horizon_color = Color(0.74, 0.82, 0.9, 1)
sun_angle_max = 20.0

[sub_resource type="Sky" id="Sky_day"]
sky_material = SubResource("Sky_mat")

[sub_resource type="Environment" id="Environment_day"]
background_mode = 2
sky = SubResource("Sky_day")
ambient_light_source = 3
ambient_light_color = Color(0.62, 0.66, 0.72, 1)
ambient_light_energy = 0.75
tonemap_mode = 2
fog_enabled = true
fog_mode = 1
fog_light_color = Color(0.72, 0.8, 0.88, 1)
fog_density = 0.9
fog_sky_affect = 0.25
fog_depth_begin = 45.0
fog_depth_end = 175.0
fog_depth_curve = 1.3

[sub_resource type="PlaneMesh" id="GroundPlane"]
size = Vector2(320, 320)
subdivide_width = 64
subdivide_depth = 64

[sub_resource type="ShaderMaterial" id="GroundMaterial"]
shader = ExtResource("%s")
shader_parameter/path_mask = ExtResource("%s")
shader_parameter/detail = ExtResource("%s")

[sub_resource type="BoxShape3D" id="GroundShape"]
size = Vector3(90, 1, 90)

[sub_resource type="BoxShape3D" id="EdgeShape"]
size = Vector3(%s, 4, 1)

[sub_resource type="CylinderShape3D" id="ZoneShape"]
height = 6.0
radius = 3.6

[sub_resource type="QuadMesh" id="PortalQuad"]
size = Vector2(4.4, 5.9)

[sub_resource type="ShaderMaterial" id="PortalMaterial"]
shader = ExtResource("%s")
''' % (ext['res://scenes/world/town_ground.gdshader'], ext['res://assets/textures/town/town_paths.png'],
       ext['res://assets/textures/town/town_noise.png'], fmt(segment_length),
       ext['res://scenes/world/portal.gdshader'])

root = '''[node name="BaseIsland" type="Node3D"]
script = ExtResource("%s")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_day")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.8191, -0.3304, 0.4691, 0, 0.8175, 0.5760, -0.5736, -0.4718, 0.6699, 0, 30, 0)
light_color = Color(1, 0.96, 0.88, 1)
light_energy = 1.15
shadow_enabled = true

[node name="Ground" type="StaticBody3D" parent="."]

[node name="GroundMesh" type="MeshInstance3D" parent="Ground"]
mesh = SubResource("GroundPlane")
surface_material_override/0 = SubResource("GroundMaterial")
metadata/no_batch = true

[node name="GroundShape" type="CollisionShape3D" parent="Ground"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)
shape = SubResource("GroundShape")
''' % ext['res://scenes/world/base_island.gd']

tail = '''[node name="Player" parent="." instance=ExtResource("%s")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.1, 24)

[node name="CameraRig" parent="." instance=ExtResource("%s")]
target_path = NodePath("../Player")

[node name="HUD" type="CanvasLayer" parent="."]

[node name="MenuButton" type="Button" parent="HUD"]
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -132.0
offset_top = 16.0
offset_right = -16.0
offset_bottom = 64.0
grow_horizontal = 0
theme_override_font_sizes/font_size = 18
text = "Меню"

[node name="GoldLabel" type="Label" parent="HUD"]
offset_left = 16.0
offset_top = 54.0
offset_right = 420.0
offset_bottom = 84.0
theme_override_colors/font_color = Color(1, 0.86, 0.4, 1)
theme_override_font_sizes/font_size = 20
text = "Золото: 0"

[node name="ActionButton" type="Button" parent="HUD"]
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -170.0
offset_top = -110.0
offset_right = 170.0
offset_bottom = -34.0
grow_horizontal = 2
grow_vertical = 0
theme_override_font_sizes/font_size = 26
text = "Будівля"

[node name="HintLabel" type="Label" parent="HUD"]
offset_left = 16.0
offset_top = 16.0
offset_right = 640.0
offset_bottom = 70.0
theme_override_font_sizes/font_size = 18
text = "Джойстик — рух. Підійди до будівлі, щоб зайти. Вхід у данж — на півночі."
''' % (ext['res://scenes/world/player_3d.tscn'], ext['res://scenes/world/camera_rig.tscn'])

text = '\n'.join(header) + '\n' + sub + '\n' + root + '\n' + '\n'.join(nodes) + '\n' + tail
open(os.path.join(PROJECT, 'scenes', 'world', 'base_island.tscn'), 'w', encoding='utf-8', newline='\n').write(text)
print('сцена записана: вузлів', len(nodes), 'ресурсів', len(ext))
