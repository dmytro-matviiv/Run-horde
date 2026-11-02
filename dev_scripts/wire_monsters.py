# -*- coding: utf-8 -*-
"""Прив'язує відрендерені 3D-спрайти до описів ворогів.

Кожен ворог отримує вигляд спереду й ззаду: коли він іде вгору (від
гравця), гра сама покаже спину — це вже вміє SpriteAnimator.
"""
import os
import re

os.chdir(r'D:\Claude code\idle survivor_like')

# Дві моделі × три кольори дають шість облич; боси відрізняються ще й
# розміром (radius у їхніх описах більший), тож повтор не впадає в око.
MAPPING = {
    'bat': 'imp_red',
    'skeleton': 'puglin_red',
    'archer': 'puglin_green',
    'golem': 'imp_blue',
    'bomber_spider': 'imp_green',
    'boss_bone_king': 'puglin_blue',
    'boss_golem_destroyer': 'imp_blue',
}

for enemy, sprite in MAPPING.items():
    path = 'data/enemies/%s.tres' % enemy
    text = open(path, encoding='utf-8').read()

    # Прибираємо старі посилання на картинки, щоб не плодити дублікати.
    text = re.sub(r'\[ext_resource type="Texture2D"[^\]]*\]\n', '', text)
    text = re.sub(r'^(texture|texture_back) = ExtResource\("\d+"\)\n', '', text, flags=re.M)

    header, body = text.split('[resource]', 1)
    header = header.rstrip('\n')
    header += '\n[ext_resource type="Texture2D" path="res://assets/sprites/enemy_%s.png" id="2"]' % sprite
    header += '\n[ext_resource type="Texture2D" path="res://assets/sprites/enemy_%s_back.png" id="3"]\n\n' % sprite
    header = re.sub(r'load_steps=\d+', 'load_steps=4', header)

    body = body.rstrip('\n') + '\ntexture = ExtResource("2")\ntexture_back = ExtResource("3")\n'
    open(path, 'w', encoding='utf-8', newline='\n').write(header + '[resource]' + body)
    print('%-22s -> %s' % (enemy, sprite))

# Старі картинки кажана й скелета більше не потрібні.
for old in ('assets/sprites/enemy_bat.png', 'assets/sprites/enemy_skeleton.png'):
    for suffix in ('', '.import'):
        if os.path.exists(old + suffix):
            os.remove(old + suffix)
            print('прибрано', old + suffix)
