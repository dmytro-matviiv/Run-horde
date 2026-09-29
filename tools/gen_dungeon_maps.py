# -*- coding: utf-8 -*-
"""Генерує ASCII-карти данжу: ланцюжок прямокутних кімнат, з'єднаних
короткими коридорами шириною 2 клітинки, — той самий стиль, що й
рукописні рівні 1-3 (див. dungeon_levels.gd і DungeonBuilder для
пояснення символів карти).
#   1. Вирізати кімнати: g.carve_room(x, y, w, h) — повертає (x,y,w,h),
#      знадобиться для "arenas" (двоє кімнат-засідок) і Rect2i.
#   2. З'єднати коридорами: g.carve_corridor_h/v(a, b, лінія).
#      УВАГА — найчастіша помилка: сусідні коридори мають ПЕРЕТИНАТИСЯ
#      бодай на 1 клітинку, інакше рівень розпадається на острови (щоб
#      перевірити — прогнати build_new_levels.py: він лише вставляє
#      готовий текст, зв'язність краще звірити окремим flood-fill з S).
#   3. Розкидати мітки ворогів (літери "mrwxct"), S (вхід), B (бос),
#      E (вихід) — g.set(x, y, символ).
#   4. emit(назва, g) друкує готовий GDScript-масив рядків; ARENAS —
#      Rect2i двох кімнат для "arenas" у dungeon_levels.gd.
# Результат вставляє tools/build_new_levels.py (одноразовий, не в
# репозиторії) або вручну — скопіювати виведені рядки в "map": [...].
"""


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


def emit(name, g):
    print("LEVELMAP", name)
    for row in g.rows():
        print('\t\t\t"%s",' % row)


# ---------------------------------------------------------------- приклад
# Мінімальна карта для нового рівня: вхідна кімната внизу, дві зали
# (одна — засідка) по боках, боса нагорі. Скопіюй і підправ під свій
# рівень; ARENAS бере рівно ті кімнати, що мають стати засідками.
g = Grid(42, 40)
r_entry = g.carve_room(17, 32, 8, 6)
r_arena = g.carve_room(4, 10, 16, 10)
r_side = g.carve_room(22, 10, 16, 10)
r_boss = g.carve_room(11, 2, 20, 7)
g.carve_corridor_v(20, 33, 19, 2)
g.carve_corridor_h(6, 19, 25, 2)
g.carve_corridor_h(21, 35, 25, 2)
g.carve_corridor_v(10, 24, 19, 2)
g.carve_corridor_v(10, 24, 30, 2)
g.carve_corridor_v(2, 11, 20, 2)
for sym, x, y in [('m', 10, 26), ('m', 30, 26), ('r', 20, 28), ('m', 8, 15), ('w', 16, 14)]:
    g.set(x, y, sym)
g.set(20, 34, 'S')
g.set(19, 4, 'B')
g.set(28, 4, 'E')
if __name__ == '__main__':
    emit("example", g)
    print("ARENAS", [r_arena, r_side])
