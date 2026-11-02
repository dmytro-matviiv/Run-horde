# -*- coding: utf-8 -*-
"""Переставляє елементи DungeonLevels.LEVELS у фінальний порядок 1-15,
розрізаючи масив на елементи-словники за глибиною дужок (а не на око) —
безпечно для таких великих багаторядкових літералів."""
import io

PATH = r"D:\Claude code\idle survivor_like\scenes\dungeon\dungeon_levels.gd"
TARGET_ORDER = [
    "crypts", "fungal", "citadel", "bone_yard", "herald_of_doom",
    "forge", "vault", "village", "abyss", "icy_abyss_lord",
    "sunken_gardens", "frozen_citadel_north", "deep_hell_forge",
    "forgotten_gods_abyss", "shadow_lord",
]

with io.open(PATH, "r", encoding="utf-8") as f:
    text = f.read()

marker = "const LEVELS := ["
start = text.index(marker) + len(marker)
# Знайти відповідну закриваючу дужку масиву, рахуючи глибину []/{} разом
# (обидва типи дужок рахуються як одна "глибина" — досить, щоб не сплутати
# внутрішні {} із кінцем зовнішнього [].
depth = 1
i = start
while depth > 0:
    ch = text[i]
    if ch in "[{":
        depth += 1
    elif ch in "]}":
        depth -= 1
    i += 1
end = i - 1  # позиція закриваючої ']' масиву
body = text[start:end]

# Розрізати body на елементи верхнього рівня: кожен елемент — від '{' до
# відповідної '}' на глибині 1.
elements = []
depth = 0
elem_start = None
for idx, ch in enumerate(body):
    if ch == '{':
        if depth == 0:
            elem_start = idx
        depth += 1
    elif ch == '}':
        depth -= 1
        if depth == 0:
            elements.append(body[elem_start:idx + 1])

print("Знайдено елементів:", len(elements))
by_id = {}
for elem in elements:
    marker_id = '"id": &"'
    j = elem.index(marker_id) + len(marker_id)
    k = elem.index('"', j)
    level_id = elem[j:k]
    by_id[level_id] = elem
    print(" -", level_id)

assert set(by_id.keys()) == set(TARGET_ORDER), (set(by_id.keys()) ^ set(TARGET_ORDER))

ordered = [by_id[i] for i in TARGET_ORDER]
new_body = "\n\n\t" + ",\n\n\t".join(ordered) + ",\n"

new_text = text[:start] + new_body + text[end:]
with io.open(PATH, "w", encoding="utf-8") as f:
    f.write(new_text)
print("Записано. Новий порядок:", TARGET_ORDER)
