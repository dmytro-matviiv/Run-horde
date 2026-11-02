# -*- coding: utf-8 -*-
"""Генерує ASCII-карти для 5 нових рівнів данжу — детерміновано (фіксоване
насіння), у тому самому стилі, що й рівні 1-3: ланцюжок кімнат, з'єднаних
короткими коридорами, вхід (S) у маленькій кімнаті, боса (B) у великій
кімнаті нагорі, вихід (E) поруч із босом. Друкує GDScript-масив рядків
для вставки в dungeon_levels.gd, плюс координати Rect2i кімнат-арен.
"""
import random


class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.cells = [['#'] * w for _ in range(h)]

    def carve_room(self, x, y, w, h):
        for j in range(y, y + h):
            for i in range(x, x + w):
                self.cells[j][i] = '.'
        return (x, y, w, h)

    def carve_corridor_h(self, x0, x1, y, width=2):
        x0, x1 = sorted((x0, x1))
        for i in range(x0, x1 + 1):
            for dy in range(width):
                self.cells[y + dy][i] = '.'

    def carve_corridor_v(self, y0, y1, x, width=2):
        y0, y1 = sorted((y0, y1))
        for j in range(y0, y1 + 1):
            for dx in range(width):
                self.cells[j][x + dx] = '.'

    def set(self, x, y, ch):
        self.cells[y][x] = ch

    def rows(self):
        return [''.join(row) for row in self.cells]


def build_level(seed, w, h, room_specs, corridors, markers, start, boss, exit_pt):
    """room_specs: [(x,y,w,h), ...]; corridors: [(kind, a,b,fixed), ...];
    markers: [(symbol, x, y), ...]."""
    g = Grid(w, h)
    rooms = [g.carve_room(*spec) for spec in room_specs]
    for kind, a, b, fixed in corridors:
        if kind == 'h':
            g.carve_corridor_h(a, b, fixed)
        else:
            g.carve_corridor_v(a, b, fixed)
    for sym, x, y in markers:
        g.set(x, y, sym)
    g.set(start[0], start[1], 'S')
    g.set(boss[0], boss[1], 'B')
    g.set(exit_pt[0], exit_pt[1], 'E')
    return g, rooms


def emit(name, g):
    print("LEVELMAP", name)
    for row in g.rows():
        print('\t\t\t"%s",' % row)


# ---------------------------------------------------------------- L4
# Кістяний Погост: пряма вісь південь->північ, кімнати обабіч коридору.
g = Grid(42, 40)
r_entry = g.carve_room(17, 32, 8, 6)
r_a = g.carve_room(6, 22, 14, 8)
r_b = g.carve_room(24, 22, 12, 8)
r_c = g.carve_room(4, 10, 16, 10)   # арена 1
r_d = g.carve_room(22, 10, 16, 10)  # арена 2
r_boss = g.carve_room(11, 2, 20, 7)
g.carve_corridor_v(20, 33, 19, 2)   # entry -> hub
g.carve_corridor_h(6, 19, 25, 2)
g.carve_corridor_h(21, 35, 25, 2)
g.carve_corridor_v(10, 24, 19, 2)
g.carve_corridor_v(10, 24, 30, 2)
g.carve_corridor_v(2, 11, 20, 2)
markers4 = [
    ('m', 10, 26), ('m', 30, 26), ('r', 20, 28),
    ('m', 8, 15), ('m', 12, 17), ('w', 16, 14), ('w', 17, 16),
    ('r', 26, 14), ('x', 33, 16), ('t', 30, 13),
    ('r', 18, 22),
]
g4, rooms4 = build_level(4, 42, 40, [], [], [], (20, 34), (20, 5), (30, 5))
# (порожній виклик — карту вже вирізано вище; використовуємо g напряму)
for sym, x, y in markers4:
    g.set(x, y, sym)
g.set(20, 34, 'S')
g.set(19, 4, 'B')
g.set(28, 4, 'E')
emit("crypts_deep", g)
print("ARENAS", [r_c, r_d])

# ---------------------------------------------------------------- L5
g5 = Grid(44, 42)
r_entry = g5.carve_room(18, 34, 8, 6)
r_hub = g5.carve_room(14, 24, 16, 8)
r_west = g5.carve_room(2, 12, 16, 10)   # арена
r_east = g5.carve_room(26, 12, 16, 10)  # арена
r_boss = g5.carve_room(13, 2, 18, 8)
g5.carve_corridor_v(16, 35, 21, 2)
g5.carve_corridor_v(11, 25, 9, 2)
g5.carve_corridor_v(11, 25, 33, 2)
g5.carve_corridor_h(9, 22, 16, 2)
g5.carve_corridor_h(21, 34, 16, 2)
g5.carve_corridor_v(2, 17, 21, 2)
markers5 = [
    ('m', 10, 20), ('m', 27, 27), ('r', 21, 30),
    ('r', 8, 18), ('x', 12, 15), ('w', 6, 16), ('w', 5, 19),
    ('c', 32, 15), ('x', 38, 18), ('m', 30, 20),
    ('r', 20, 24),
]
for sym, x, y in markers5:
    g5.set(x, y, sym)
g5.set(21, 36, 'S')
g5.set(20, 5, 'B')
g5.set(28, 5, 'E')
emit("forge", g5)
print("ARENAS", [r_west, r_east])

# ---------------------------------------------------------------- L6
g6 = Grid(46, 44)
r_entry = g6.carve_room(19, 36, 8, 6)
r_a = g6.carve_room(6, 24, 14, 8)
r_b = g6.carve_room(26, 24, 14, 8)
r_vault = g6.carve_room(4, 8, 18, 12)   # арена (велика скарбниця)
r_side = g6.carve_room(26, 10, 16, 10)  # арена 2
r_boss = g6.carve_room(14, 2, 18, 6)
g6.carve_corridor_v(22, 37, 22, 2)
g6.carve_corridor_h(8, 22, 27, 2)
g6.carve_corridor_h(23, 33, 27, 2)
g6.carve_corridor_v(12, 25, 12, 2)
g6.carve_corridor_v(12, 25, 32, 2)
g6.carve_corridor_v(2, 12, 22, 2)
markers6 = [
    ('m', 11, 29), ('r', 32, 29), ('m', 18, 29),
    ('r', 10, 17), ('w', 14, 14), ('w', 8, 20), ('x', 18, 12),
    ('t', 32, 16), ('r', 36, 19), ('m', 30, 13),
    ('m', 22, 25),
]
for sym, x, y in markers6:
    g6.set(x, y, sym)
g6.set(22, 38, 'S')
g6.set(22, 4, 'B')
g6.set(29, 4, 'E')
emit("vault", g6)
print("ARENAS", [r_vault, r_side])

# ---------------------------------------------------------------- L7
g7 = Grid(46, 44)
r_entry = g7.carve_room(19, 36, 8, 6)
r_square = g7.carve_room(4, 22, 20, 10)  # арена (сільська площа)
r_inn = g7.carve_room(28, 22, 14, 8)
r_mill = g7.carve_room(6, 8, 14, 10)
r_barn = g7.carve_room(24, 8, 18, 10)    # арена 2
r_boss = g7.carve_room(15, 2, 18, 6)
g7.carve_corridor_v(22, 37, 22, 2)
g7.carve_corridor_h(6, 22, 26, 2)
g7.carve_corridor_h(23, 34, 26, 2)
g7.carve_corridor_v(12, 23, 12, 2)
g7.carve_corridor_v(12, 23, 32, 2)
g7.carve_corridor_v(2, 12, 22, 2)
markers7 = [
    ('m', 22, 30), ('r', 10, 27), ('m', 32, 26), ('w', 14, 24), ('w', 18, 28),
    ('r', 10, 12), ('c', 32, 12), ('x', 28, 14), ('m', 36, 16), ('m', 8, 15),
    ('r', 22, 22),
]
for sym, x, y in markers7:
    g7.set(x, y, sym)
g7.set(22, 38, 'S')
g7.set(23, 4, 'B')
g7.set(30, 4, 'E')
emit("village_ruins", g7)
print("ARENAS", [r_square, r_barn])

# ---------------------------------------------------------------- L8
g8 = Grid(48, 46)
r_entry = g8.carve_room(20, 38, 8, 6)
r_hub = g8.carve_room(14, 28, 20, 8)
r_west = g8.carve_room(2, 14, 18, 12)   # арена
r_east = g8.carve_room(28, 14, 18, 12)  # арена
r_final = g8.carve_room(6, 12, 14, 10, ) if False else None
r_boss = g8.carve_room(15, 2, 18, 8)
g8.carve_corridor_v(19, 39, 23, 2)
g8.carve_corridor_v(15, 29, 10, 2)
g8.carve_corridor_v(15, 29, 36, 2)
g8.carve_corridor_h(10, 24, 19, 2)
g8.carve_corridor_h(25, 37, 19, 2)
g8.carve_corridor_v(2, 20, 23, 2)
markers8 = [
    ('m', 11, 20), ('m', 33, 31), ('r', 23, 33), ('r', 20, 30), ('m', 27, 30),
    ('r', 8, 20), ('w', 12, 17), ('c', 16, 22), ('t', 6, 24),
    ('c', 36, 20), ('w', 32, 17), ('x', 40, 22), ('m', 30, 24),
]
for sym, x, y in markers8:
    g8.set(x, y, sym)
g8.set(23, 40, 'S')
g8.set(23, 5, 'B')
g8.set(31, 5, 'E')
emit("abyss", g8)
print("ARENAS", [r_west, r_east])
