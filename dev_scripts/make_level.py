# -*- coding: utf-8 -*-
"""Малює карту першого данжу й записує її у scenes/dungeon/dungeon_levels.gd.

Карту зручніше будувати кодом, ніж вручну рахувати символи: тут видно
задум (вхід, зали, бічні кімнати, коридори з поворотами, зала боса), а
рядки однакової довжини виходять самі.
"""
import os

W, H = 40, 34
grid = [["#"] * W for _ in range(H)]


def room(x0, z0, x1, z1):
    for z in range(z0, z1 + 1):
        for x in range(x0, x1 + 1):
            grid[z][x] = "."


def put(x, z, symbol):
    grid[z][x] = symbol


# --- вхідна зала: тут ворогів немає ---
room(16, 27, 23, 32)

# --- коридор на північ із поворотом ---
room(19, 22, 20, 27)
room(12, 22, 20, 23)     # поворот ліворуч
room(12, 18, 13, 23)     # і знову на північ

# --- велика зала ---
room(6, 12, 33, 18)

# --- бічні кімнати ---
room(2, 13, 6, 17)       # ліва комора
room(33, 13, 37, 17)     # права варта

# --- коридор до боса ---
room(19, 6, 20, 12)

# --- зала боса й вихід за нею ---
room(11, 2, 28, 8)

# --- мітки ---
put(19, 30, "S")          # вхід

# вороги: у великій залі й бічних кімнатах, подалі від входу
for x, z in [(10, 15), (16, 14), (23, 16), (29, 15), (13, 17), (26, 13)]:
    put(x, z, "m")
for x, z in [(4, 15), (35, 15), (8, 13), (31, 17)]:
    put(x, z, "r")

# ще кілька в коридорі й перед залою боса
for x, z in [(12, 20), (19, 9)]:
    put(x, z, "m")
put(20, 7, "r")

put(19, 5, "B")           # бос
put(19, 3, "E")           # вихід за ним

rows = ["".join(row) for row in grid]

header = '''extends RefCounted
class_name DungeonLevels

## Намальовані рівні данжу. Один символ = клітинка 2x2 метри:
##   #  непрохідне    .  підлога    S  вхід (тут ворогів немає)
##   m  ворог ближнього бою         r  стрілець
##   B  бос           E  вихід
##
## Рівень навмисно з поворотами, бічними кімнатами й довгими коридорами:
## саме на кутах видно, чи вміють вороги обходити стіни, а не впиратись
## у них. Вхідна зала стоїть окремо й далеко від першої групи ворогів —
## гравець має спокійно вибрати здібність, перш ніж почнеться бій.

const LEVELS := [
	{
		"title": "Забуті склепи",
		"map": [
'''

body = "".join('\t\t\t"%s",\n' % row for row in rows)

footer = '''		],
	},
]

static func get_level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]

static func get_level_count() -> int:
	return LEVELS.size()
'''

path = r'D:\Claude code\idle survivor_like\scenes\dungeon\dungeon_levels.gd'
open(path, 'w', encoding='utf-8', newline='\n').write(header + body + footer)

walkable = sum(row.count(".") + row.count("m") + row.count("r") for row in rows)
print("карта %dx%d, прохідних клітинок %d" % (W, H, walkable))
for row in rows:
    print("   " + row)
