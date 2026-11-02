# -*- coding: utf-8 -*-
"""Чотири нові прості данжі (майбутні рівні 11-14): пряма "хребтова"
топологія — один вертикальний коридор проходить крізь усі кімнати по
черзі (бос -> засідка1 -> проміжна -> вхід), друга засідка відгалужується
вбік. Коридор між двома кімнатами будується З ЇХНІХ РЕАЛЬНИХ меж
(connect_v/connect_h), а не "на око" координатами — так неможливо
лишити розрив між суміжними кімнатами."""
import sys
sys.path.insert(0, r"D:\Claude code\idle survivor_like\tools")
from gen_dungeon_maps import Grid, emit


def connect_v(g, room_top, room_bottom, x):
    tx, ty, tw, th = room_top
    bx, by, bw, bh = room_bottom
    assert tx <= x <= tx + tw - 2 and bx <= x <= bx + bw - 2, (room_top, room_bottom, x)
    g.carve_corridor_v(ty + th - 1, by, x, 2)


def connect_h(g, room_left, room_right, y):
    lx, ly, lw, lh = room_left
    rx, ry, rw, rh = room_right
    assert ly <= y <= ly + lh - 2 and ry <= y <= ry + rh - 2, (room_left, room_right, y)
    g.carve_corridor_h(lx + lw - 1, rx, y, 2)


def check_connected(g):
    rows = g.rows()
    h = len(rows)
    w = len(rows[0])
    start = None
    walkable = set('.SBEmrwxct')
    for y in range(h):
        for x in range(w):
            if rows[y][x] == 'S':
                start = (x, y)
    assert start is not None, "no S marker"
    seen = {start}
    stack = [start]
    while stack:
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and rows[ny][nx] in walkable:
                seen.add((nx, ny))
                stack.append((nx, ny))
    total_walkable = sum(1 for y in range(h) for x in range(w) if rows[y][x] in walkable)
    ok = len(seen) == total_walkable
    print("CONNECTED:", ok, "(%d/%d reached)" % (len(seen), total_walkable))
    return ok


class Rect:
    def __init__(self, x, y, w, h):
        self.x, self.y, self.w, self.h = x, y, w, h

    def __repr__(self):
        return "Rect2i(%d, %d, %d, %d)" % (self.x, self.y, self.w, self.h)


def build(name, w, h, spine_x, boss, a1, mid, entry, a2, a2_row, mobs, boss_off, e_off):
    g = Grid(w, h)
    r_boss = g.carve_room(*boss)
    r_a1 = g.carve_room(*a1)
    r_mid = g.carve_room(*mid)
    r_entry = g.carve_room(*entry)
    r_a2 = g.carve_room(*a2)
    connect_v(g, boss, a1, spine_x)
    connect_v(g, a1, mid, spine_x)
    connect_v(g, mid, entry, spine_x)
    connect_h(g, a1, a2, a2_row)
    for sym, x, y in mobs:
        g.set(x, y, sym)
    ex, ey, ew, eh = entry
    g.set(ex + ew // 2, ey + eh // 2, 'S')
    bx, by, bw, bh = boss
    g.set(bx + bw // 2 - boss_off, by + bh // 2, 'B')
    g.set(bx + bw // 2 + e_off, by + bh // 2, 'E')
    print("=== %s ===" % name)
    ok = check_connected(g)
    emit(name, g)
    print("ARENAS", [Rect(*a1), Rect(*a2)])
    return ok


ok = True

# L11: Потонулі Сади
ok &= build("normal11", 40, 42, 20,
            boss=(10, 2, 20, 7), a1=(11, 11, 18, 10), mid=(14, 23, 12, 6), entry=(15, 31, 10, 5),
            a2=(30, 13, 9, 8), a2_row=15,
            mobs=[('m', 15, 15), ('w', 24, 15), ('m', 33, 16), ('m', 18, 26), ('x', 22, 26)],
            boss_off=3, e_off=4)

# L12: Зимна Цитадель Півночі
ok &= build("normal12", 42, 44, 21,
            boss=(11, 2, 20, 7), a1=(12, 11, 18, 11), mid=(15, 24, 12, 6), entry=(16, 32, 10, 6),
            a2=(31, 13, 9, 9), a2_row=15,
            mobs=[('m', 16, 15), ('c', 25, 16), ('w', 34, 17), ('t', 19, 27), ('m', 23, 27)],
            boss_off=3, e_off=4)

# L13: Пекельна Кузня Глибин
ok &= build("normal13", 44, 46, 22,
            boss=(12, 2, 20, 7), a1=(13, 11, 19, 12), mid=(16, 25, 12, 6), entry=(17, 33, 10, 6),
            a2=(33, 13, 10, 10), a2_row=15,
            mobs=[('m', 17, 15), ('x', 27, 16), ('r', 37, 17), ('m', 19, 28), ('r', 24, 28), ('m', 22, 27)],
            boss_off=3, e_off=4)

# L14: Прірва Забутих Богів
ok &= build("normal14", 46, 48, 23,
            boss=(13, 2, 20, 8), a1=(14, 12, 20, 12), mid=(17, 26, 12, 6), entry=(18, 34, 10, 6),
            a2=(35, 14, 10, 11), a2_row=16,
            mobs=[('m', 18, 16), ('m', 22, 18), ('w', 30, 16), ('r', 38, 18), ('c', 33, 19),
                  ('m', 21, 29), ('t', 25, 29)],
            boss_off=3, e_off=5)

print("ALL CONNECTED:", ok)
