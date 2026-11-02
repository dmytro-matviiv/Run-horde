# -*- coding: utf-8 -*-
"""Карти данжів 2 і 3. Клітинка = 2 м.

Символи: # стіна . підлога S вхід E вихід B бос
         m ближній бій  r стрілець  w рій  x вибуховий  c таран  t голем
"""
from collections import deque


def make(width, height):
    return [['#'] * width for _ in range(height)]


def room(grid, x0, z0, x1, z1):
    for z in range(z0, z1 + 1):
        for x in range(x0, x1 + 1):
            grid[z][x] = '.'


def put(grid, x, z, symbol):
    assert grid[z][x] != '#', ('у стіні', x, z, symbol)
    grid[z][x] = symbol


def check(grid, name):
    height, width = len(grid), len(grid[0])
    start = next((x, z) for z in range(height) for x in range(width) if grid[z][x] == 'S')
    seen = {start}
    queue = deque([start])
    while queue:
        x, z = queue.popleft()
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, nz = x + dx, z + dz
            if 0 <= nx < width and 0 <= nz < height and grid[nz][nx] != '#' and (nx, nz) not in seen:
                seen.add((nx, nz))
                queue.append((nx, nz))
    floor = {(x, z) for z in range(height) for x in range(width) if grid[z][x] != '#'}
    assert floor == seen, '%s: недосяжні клітинки %s' % (name, sorted(floor - seen)[:10])
    # Краї карти — стіна: інакше стіни по межі не збудуються.
    for x in range(width):
        assert grid[0][x] == '#' and grid[height - 1][x] == '#', name
    for z in range(height):
        assert grid[z][0] == '#' and grid[z][width - 1] == '#', name
    enemies = sum(1 for row in grid for c in row if c in 'mrwxct')
    print('%s: %dx%d, підлоги %d клітинок, точок ворогів %d' % (name, width, height, len(floor), enemies))


def dump(grid):
    return '\n'.join('\t\t\t"%s",' % ''.join(row) for row in grid)


# ============================================================
# РІВЕНЬ 2 — "Грибні нетрі": звивисті печери, рої й вибухові слизні
# ============================================================
g = make(48, 44)
room(g, 3, 33, 11, 40)          # вхідна печера
room(g, 12, 36, 19, 37)         # прохід на схід
room(g, 20, 30, 30, 40)         # печера А
room(g, 24, 22, 25, 29)         # прохід на північ
room(g, 15, 12, 37, 21)         # велика печера Б
room(g, 38, 16, 41, 17)         # прохід у бічну печеру
room(g, 42, 11, 46, 25)         # бічна печера В
room(g, 17, 6, 18, 11)          # прохід на північний захід
room(g, 5, 2, 19, 9)            # печера Г
room(g, 20, 4, 27, 5)           # прохід до боса
room(g, 28, 1, 46, 10)          # лігво Грибного Короля

put(g, 7, 38, 'S')
# Печера А: перші рої — далеко від входу.
put(g, 24, 32, 'w'); put(g, 28, 38, 'w'); put(g, 22, 35, 'm'); put(g, 29, 31, 'x')
# Велика печера Б: усе разом.
put(g, 19, 14, 'x'); put(g, 34, 20, 'x'); put(g, 36, 13, 'r'); put(g, 17, 20, 'r')
put(g, 26, 16, 'm'); put(g, 30, 20, 'm'); put(g, 24, 13, 'w'); put(g, 32, 15, 'w')
# Бічна печера В: засідка вибухових слизнів.
put(g, 44, 13, 'x'); put(g, 44, 23, 'x'); put(g, 45, 18, 'w'); put(g, 43, 19, 'm')
# Печера Г: плювальники й рій.
put(g, 7, 3, 'r'); put(g, 15, 8, 'r'); put(g, 11, 4, 'w'); put(g, 17, 3, 'm'); put(g, 9, 7, 'x')
# Лігво: бос і вихід за ним.
put(g, 38, 5, 'B'); put(g, 45, 5, 'E'); put(g, 31, 9, 'r')
check(g, 'Грибні нетрі')
level2 = dump(g)

# ============================================================
# РІВЕНЬ 3 — "Крижана цитадель": зали для таранів, крила з големами
# ============================================================
g = make(50, 50)
room(g, 20, 42, 29, 47)         # вхідна зала
room(g, 23, 37, 26, 41)         # прохід
room(g, 18, 25, 31, 36)         # зала таранів
room(g, 7, 22, 42, 24)          # поперечна галерея
room(g, 3, 8, 14, 21)           # західне крило (големи)
room(g, 35, 8, 46, 21)          # східне крило (чаклуни)
room(g, 23, 19, 26, 21)         # прохід у велику залу
room(g, 17, 10, 32, 18)         # велика зала
room(g, 15, 13, 16, 14)         # з'єднання із західним крилом
room(g, 33, 13, 34, 14)         # з'єднання зі східним крилом
room(g, 24, 6, 25, 9)           # прохід до тронної зали
room(g, 12, 1, 37, 5)           # тронна зала Дракона

put(g, 24, 45, 'S')
# Зала таранів: простір, щоб було де розігнатись і де ухилитись.
put(g, 21, 28, 'c'); put(g, 28, 30, 'c'); put(g, 24, 27, 'm'); put(g, 30, 34, 'm')
# Західне крило: големи й ніндзя.
put(g, 7, 12, 't'); put(g, 11, 18, 't'); put(g, 5, 16, 'm'); put(g, 12, 10, 'm'); put(g, 9, 9, 'x')
# Східне крило: крижані чаклуни.
put(g, 38, 10, 'r'); put(g, 44, 12, 'r'); put(g, 40, 18, 'r'); put(g, 45, 20, 'x'); put(g, 37, 15, 'm')
# Велика зала: усе найгірше разом.
put(g, 20, 12, 'c'); put(g, 29, 16, 'c'); put(g, 25, 14, 't'); put(g, 18, 17, 'r'); put(g, 31, 11, 'x')
# Тронна зала: Дракон, а вихід за ним.
put(g, 25, 3, 'B'); put(g, 36, 3, 'E'); put(g, 14, 2, 'm'); put(g, 14, 4, 'r')
check(g, 'Крижана цитадель')
level3 = dump(g)

open(r'D:\RuneHorde_work\logs\level2_map.txt', 'w', encoding='utf-8').write(level2)
open(r'D:\RuneHorde_work\logs\level3_map.txt', 'w', encoding='utf-8').write(level3)
print(level2.replace('\t', '')[:0])
