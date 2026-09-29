# Текстура верху скелі навколо залів данжу (assets/textures/rock_top.png):
# безшовний сірий шум із тріщинами. Колір дає тема рівня в грі, тож
# картинка сіра. Запуск (потрібен Python з Pillow):
#   python tools/build_rock_texture.py
import math
import os
import random

from PIL import Image

SIZE = 128
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'textures', 'rock_top.png')

random.seed(20260929)


def value_noise(period):
    """Безшовний шум: випадкова сітка period x period, згладжена між вузлами."""
    grid = [[random.random() for _ in range(period)] for _ in range(period)]
    cell = SIZE / period
    out = [[0.0] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        gy = y / cell
        y0 = int(gy) % period
        y1 = (y0 + 1) % period
        ty = gy - int(gy)
        ty = ty * ty * (3 - 2 * ty)
        for x in range(SIZE):
            gx = x / cell
            x0 = int(gx) % period
            x1 = (x0 + 1) % period
            tx = gx - int(gx)
            tx = tx * tx * (3 - 2 * tx)
            top = grid[y0][x0] * (1 - tx) + grid[y0][x1] * tx
            bottom = grid[y1][x0] * (1 - tx) + grid[y1][x1] * tx
            out[y][x] = top * (1 - ty) + bottom * ty
    return out


def cracks(count):
    """Тріщини між "брилами": там, де дві найближчі точки майже рівновіддалені."""
    points = [(random.random() * SIZE, random.random() * SIZE) for _ in range(count)]
    out = [[0.0] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            d1 = d2 = 1e9
            for px, py in points:
                dx = abs(x - px)
                dy = abs(y - py)
                dx = min(dx, SIZE - dx)
                dy = min(dy, SIZE - dy)
                d = math.sqrt(dx * dx + dy * dy)
                if d < d1:
                    d1, d2 = d, d1
                elif d < d2:
                    d2 = d
            out[y][x] = d2 - d1
    return out


octaves = [(4, 0.5), (8, 0.25), (16, 0.15), (32, 0.1)]
layers = [(value_noise(p), a) for p, a in octaves]
edges = cracks(9)

image = Image.new('RGB', (SIZE, SIZE))
pixels = image.load()
for y in range(SIZE):
    for x in range(SIZE):
        v = sum(layer[y][x] * a for layer, a in layers)
        shade = 0.7 + 0.3 * v
        # Тріщина — темна смуга в 2-3 пікселі з м'яким краєм.
        crack = min(1.0, edges[y][x] / 3.0)
        shade *= 0.72 + 0.28 * crack
        c = int(max(0, min(255, shade * 255)))
        pixels[x, y] = (c, c, c)

image.save(OUT)
print('saved', OUT)
