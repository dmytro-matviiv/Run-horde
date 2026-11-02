# -*- coding: utf-8 -*-
"""Карти трьох мега-босів: вхід -> короткий коридор -> одна велика зала
(бос + вихід разом, як у "crypts"). boss_arena = рівно ця зала."""
import sys
sys.path.insert(0, r"D:\Claude code\idle survivor_like\tools")
from gen_dungeon_maps import Grid, emit


def mega(w, h, arena, entry, corridor_x, extra_mobs=()):
    g = Grid(w, h)
    ax, ay, aw, ah = g.carve_room(*arena)
    ex, ey, ew, eh = g.carve_room(*entry)
    g.carve_corridor_v(ey + 1, ay + ah - 1, corridor_x, 2)
    for sym, x, y in extra_mobs:
        g.set(x, y, sym)
    g.set(ex + ew // 2, ey + eh // 2, 'S')
    g.set(ax + aw // 2 - 3, ay + ah // 2, 'B')
    g.set(ax + aw // 2 + 3, ay + ah // 2, 'E')
    return g, Rect(ax, ay, aw, ah)


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


# L5: Провісник Загибелі
g5, r5 = mega(38, 30, (9, 2, 20, 14), (16, 24, 6, 5), 19,
              extra_mobs=[])
print("=== L5 boss_arena", r5)
check_connected(g5)
emit("mega5", g5)

# L10: Володар Крижаної Безодні
g10, r10 = mega(42, 32, (9, 2, 24, 16), (18, 25, 6, 6), 21,
                extra_mobs=[])
print("=== L10 boss_arena", r10)
check_connected(g10)
emit("mega10", g10)

# L15: Тіньовий Володар
g15, r15 = mega(46, 34, (9, 2, 28, 18), (19, 27, 6, 6), 22,
                extra_mobs=[])
print("=== L15 boss_arena", r15)
check_connected(g15)
emit("mega15", g15)
