# -*- coding: utf-8 -*-
"""Безшовна текстура кам'яної підлоги підземелля 256x256.

Малюємо самі, а не генеруємо нейромережею: тло має бути тьмяним і
непомітним, щоб не з'їдати очі під час бою, а безшовність нейромережа
не гарантує — стики було б видно на всьому екрані.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 256
TILE = 64
OUT = r'D:\Claude code\idle survivor_like\assets\sprites\floor_dungeon.png'

rng = np.random.default_rng(11)

# Основа: темний синьо-сірий камінь із дрібним зерном.
noise = rng.normal(128.0, 40.0, (SIZE, SIZE))
grain_image = Image.fromarray(np.uint8(np.clip(noise, 0, 255)), 'L').filter(ImageFilter.GaussianBlur(1.2))
grain = np.asarray(grain_image, dtype=np.float64) / 255.0

base = np.zeros((SIZE, SIZE, 3))
base[:, :, 0] = 0.13 + 0.05 * grain
base[:, :, 1] = 0.14 + 0.05 * grain
base[:, :, 2] = 0.19 + 0.06 * grain

image = Image.fromarray(np.uint8(np.clip(base, 0, 1) * 255))
draw = ImageDraw.Draw(image)

# Шви між плитами: кожен другий ряд зсунутий, як у справжній кладці.
seam = (70, 72, 86)
for row in range(SIZE // TILE):
    y = row * TILE
    draw.line([(0, y), (SIZE, y)], fill=seam, width=2)
    offset = (TILE // 2) if row % 2 else 0
    for col in range(SIZE // TILE + 1):
        x = (col * TILE + offset) % SIZE
        draw.line([(x, y), (x, y + TILE)], fill=seam, width=2)

# Легкі світлі відблиски на плитах, щоб камінь не був пласким.
highlight = Image.new('L', (SIZE, SIZE), 0)
hdraw = ImageDraw.Draw(highlight)
for _ in range(60):
    x, y = rng.integers(0, SIZE, 2)
    r = int(rng.integers(3, 10))
    hdraw.ellipse([x - r, y - r, x + r, y + r], fill=int(rng.integers(10, 26)))
highlight = highlight.filter(ImageFilter.GaussianBlur(3))
image = Image.composite(Image.new('RGB', (SIZE, SIZE), (150, 155, 175)), image, highlight)

image.save(OUT)
print('saved', OUT)
