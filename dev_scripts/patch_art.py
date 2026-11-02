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


# --- описи: у героя й ворога з'являється картинка ---
patch('data/heroes/hero_def.gd', [
    ("""@export var color: Color = Color(0.2, 0.8, 1)""",
     """@export var color: Color = Color(0.2, 0.8, 1)

## Спрайт героя. Поки картинки немає, малюється кольорова фігура —
## так гра лишається робочою, доки арт готовий не для всіх.
@export var texture: Texture2D"""),
])

patch('data/enemies/enemy_def.gd', [
    ("""@export var color: Color = Color(0.9, 0.2, 0.2)""",
     """@export var color: Color = Color(0.9, 0.2, 0.2)

## Спрайт ворога; якщо не заданий — малюється кольорова фігура.
@export var texture: Texture2D"""),
])

# --- сцени: додаємо вузол зі спрайтом поруч із фігурою ---
patch('scenes/run/hero.tscn', [
    ('[gd_scene load_steps=6 format=3]', '[gd_scene load_steps=6 format=3]'),
    ("""[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_body")""",
     """[node name="Art" type="Sprite2D" parent="."]
visible = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_body")"""),
])

patch('scenes/run/enemy.tscn', [
    ("""[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_enemy")""",
     """[node name="Art" type="Sprite2D" parent="."]
visible = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_enemy")"""),
])

# --- герой: показує спрайт, якщо він є ---
patch('scenes/run/hero.gd', [
    ("""@onready var sprite: Polygon2D = $Sprite""",
     """## Наскільки високим має бути спрайт героя на екрані (px). Картинки
## генеруються великими, тож масштаб рахуємо від цієї висоти, а не
## зашиваємо в кожен файл окремо.
const ART_HEIGHT := 72.0

@onready var sprite: Polygon2D = $Sprite
@onready var art: Sprite2D = $Art"""),
    ("""func apply_hero_def(def: HeroDef) -> void:
	sprite.color = def.color""",
     """func apply_hero_def(def: HeroDef) -> void:
	sprite.color = def.color
	_apply_art(def.texture)"""),
    ("""## Викликається один раз на старті рану (run.gd), до того як гравець""",
     """## Спрайт замість кольорової фігури. Якщо картинки для героя ще
## немає — лишаємо фігуру, гра від цього не ламається.
func _apply_art(texture: Texture2D) -> void:
	if texture == null:
		return
	art.texture = texture
	art.scale = Vector2.ONE * (ART_HEIGHT / float(texture.get_height()))
	art.visible = true
	sprite.visible = false

## Викликається один раз на старті рану (run.gd), до того як гравець"""),
])

# --- ворог: те саме, розмір спрайта прив'язаний до радіуса ---
patch('scenes/run/enemy.gd', [
    ("""@onready var sprite: Polygon2D = $Sprite""",
     """## Спрайт ворога малюємо трохи більшим за його фізичний радіус:
## крила, зброя й шолом виходять за межі кола зіткнень.
const ART_SIZE_FACTOR := 3.4

@onready var sprite: Polygon2D = $Sprite
@onready var art: Sprite2D = $Art"""),
    ("""	sprite.color = def.color
	sprite.polygon = _make_polygon(def.radius)""",
     """	sprite.color = def.color
	sprite.polygon = _make_polygon(def.radius)
	_apply_art(def)"""),
    ("""## disabled міняємо через set_deferred — pool_deactivate() тут
## викликається з _die()""",
     """## Один і той самий вузол із пулу щоразу грає іншого ворога, тому
## картинку (або її відсутність) переставляємо на кожен спавн.
func _apply_art(def: EnemyDef) -> void:
	if def.texture == null:
		art.visible = false
		sprite.visible = true
		return
	art.texture = def.texture
	art.scale = Vector2.ONE * (def.radius * ART_SIZE_FACTOR / float(def.texture.get_height()))
	art.visible = true
	sprite.visible = false

## disabled міняємо через set_deferred — pool_deactivate() тут
## викликається з _die()"""),
])

# --- прив'язуємо готові картинки до описів ---
art = {
    'data/heroes/runewielder.tres': 'res://assets/sprites/hero_runewielder.png',
    'data/heroes/blade_warden.tres': 'res://assets/sprites/hero_blade_warden.png',
    'data/heroes/ember_priestess.tres': 'res://assets/sprites/hero_ember_priestess.png',
    'data/heroes/void_assassin.tres': 'res://assets/sprites/hero_void_assassin.png',
    'data/enemies/bat.tres': 'res://assets/sprites/enemy_bat.png',
    'data/enemies/skeleton.tres': 'res://assets/sprites/enemy_skeleton.png',
}
for path, texture_path in art.items():
    s = open(path, encoding='utf-8').read()
    if 'texture = ExtResource("2")' in s:
        continue
    header, body = s.split('[resource]', 1)
    header = header.rstrip('\n') + '\n[ext_resource type="Texture2D" path="%s" id="2"]\n\n' % texture_path
    header = header.replace('load_steps=2', 'load_steps=3')
    body = body.rstrip('\n') + '\ntexture = ExtResource("2")\n'
    open(path, 'w', encoding='utf-8', newline='\n').write(header + '[resource]' + body)
    print('art linked', path)
