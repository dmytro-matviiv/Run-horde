# -*- coding: utf-8 -*-
"""Складає GDScript-текст п'яти нових рівнів (4-8) і вставляє його в
LEVELS перед закриваючою дужкою масиву. Карти беруться з map_*.txt
(див. gen_dungeon_maps.py)."""
import io
import os

ROOT = r"D:\Claude code\idle survivor_like"
MAPS_DIR = r"D:\RuneHorde_work\logs"


def load_map(name):
    return io.open(os.path.join(MAPS_DIR, "map_%s.txt" % name), encoding="utf-8").read().rstrip("\n")


M = "res://assets/models/monsters/"

# --- допоміжні описи істот, яких кличуть здібності ---
SKELETON = ('{"name": "Кістяк", "model": "%sOrc Enemy.glb", "kind": "melee", "hp": 14.0, "damage": 6.0, '
            '"speed": 3.2, "height": 1.5, "xp": 1, "tint": Color(0.9, 0.88, 0.8), "no_elite": true}') % M
GOLD_PYLON = ('{"name": "Золотий пілон", "model": "%sSquidle.glb", "kind": "totem", "hp": 45.0, "damage": 0.0, '
              '"speed": 0.0, "height": 1.3, "xp": 2, "tint": Color(1.0, 0.85, 0.4), "glow": Color(0.5, 0.35, 0.05), '
              '"no_elite": true, "abilities": [{"id": "ward", "factor": 0.0, "range": 9.0, "links": 1, "target": "boss"}]}') % M

LEVELS = []

# ============================================================== L4
LEVELS.append({
    "id": "bone_yard",
    "arenas": "[Rect2i(4, 10, 16, 10), Rect2i(22, 10, 16, 10)]",
    "title": "Кістяний Погост",
    "subtitle": "Цвинтар за містом ожив. Привиди, кістяні чаклуни й Кістяний Володар, що підіймає мертвих.",
    "difficulty": 4,
    "stats": '{"hp": 2.9, "damage": 2.1, "gold": 3.2}',
    "theme": '''{
			"stone": Color(0.55, 0.58, 0.5),
			"floor": Color(0.6, 0.62, 0.56),
			"fog": Color(0.15, 0.18, 0.14), "fog_density": 0.03,
			"ambient": Color(0.4, 0.48, 0.4), "ambient_energy": 1.4,
			"torch": Color(0.55, 1.0, 0.55),
			"background": Color(0.03, 0.04, 0.03),
			"decor": "graveyard",
		}''',
    "enemies": '''{
			"m": [
				{"name": "Кладовищенський привид", "model": "%sGhost Skull.glb", "kind": "melee", "hp": 40.0, "damage": 11.0, "speed": 3.4, "height": 1.6, "hover": 0.6, "xp": 5,
					"tint": Color(0.75, 0.85, 1.0), "glow": Color(0.3, 0.5, 0.6), "abilities": ["blink"]},
			],
			"r": [
				{"name": "Кістяний чаклун", "model": "%sWizard.glb", "kind": "ranged", "hp": 32.0, "damage": 9.0, "speed": 2.3, "height": 1.8, "xp": 6,
					"tint": Color(0.6, 0.55, 0.7), "projectile": {"color": Color(0.6, 0.9, 0.5), "speed": 9.0, "volley": 2},
					"abilities": [{"id": "raise_dead", "cooldown": 10.0, "first": 5.0, "summon": %s, "count": 2, "max": 3}]},
			],
			"w": [
				{"name": "Кістяний хробак", "model": "%sGreen Spiky Blob.glb", "kind": "melee", "hp": 13.0, "damage": 5.0, "speed": 4.6, "height": 0.9, "xp": 1, "group": 4,
					"tint": Color(0.8, 0.8, 0.72), "attack_range": 1.4, "cooldown": 0.8},
			],
			"x": [
				{"name": "Розкладена плоть", "model": "%sPink Blob.glb", "kind": "exploder", "hp": 20.0, "damage": 26.0, "speed": 4.1, "height": 1.2, "xp": 3,
					"tint": Color(0.75, 0.82, 0.6)},
			],
			"t": [
				{"name": "Кістяний тотем", "model": "%sOrc Enemy.glb", "kind": "totem", "hp": 60.0, "damage": 0.0, "speed": 0.0, "height": 1.8, "xp": 4,
					"tint": Color(0.85, 0.82, 0.7), "glow": Color(0.2, 0.3, 0.15), "no_elite": true,
					"abilities": [{"id": "ward", "factor": 0.15, "range": 7.0, "links": 3}]},
			],
		}''' % (M, M, SKELETON, M, M, M),
    "boss": '''{"name": "Кістяний Володар", "model": "%sTribal.glb",
			"hp": 420.0, "damage": 20.0, "speed": 3.0, "height": 3.6, "xp": 70,
			"tint": Color(0.88, 0.86, 0.78), "glow": Color(0.25, 0.55, 0.35),
			"abilities": [
				{"id": "raise_dead", "cooldown": 9.0, "first": 3.0, "summon": %s, "count": 3, "max": 5},
				{"id": "ring_slam", "cooldown": 8.0, "first": 5.0, "radius": 11.0, "speed": 7.5, "color": Color(0.4, 0.9, 0.5)},
			]}''' % (M, SKELETON),
    "map": load_map("crypts_deep"),
})

# ============================================================== L5
LEVELS.append({
    "id": "forge",
    "arenas": "[Rect2i(2, 12, 16, 10), Rect2i(26, 12, 16, 10)]",
    "title": "Кузня Присмерку",
    "subtitle": "Підземна кузня палає день і ніч. Розпечені іскри, залізні тарани й Володар Горна.",
    "difficulty": 5,
    "stats": '{"hp": 3.7, "damage": 2.5, "gold": 4.0}',
    "theme": '''{
			"stone": Color(0.55, 0.42, 0.38),
			"floor": Color(0.5, 0.4, 0.35),
			"fog": Color(0.25, 0.1, 0.06), "fog_density": 0.035,
			"ambient": Color(0.6, 0.35, 0.25), "ambient_energy": 1.6,
			"torch": Color(1.0, 0.5, 0.2),
			"background": Color(0.08, 0.03, 0.02),
			"decor": "forge",
		}''',
    "enemies": '''{
			"m": [
				{"name": "Коваль-раб", "model": "%sOrc Enemy.glb", "kind": "melee", "hp": 42.0, "damage": 12.0, "speed": 2.9, "height": 1.8, "xp": 5,
					"tint": Color(0.6, 0.5, 0.48), "glow": Color(0.3, 0.1, 0.05)},
			],
			"r": [
				{"name": "Вогняний біс", "model": "%sBlue Demon.glb", "kind": "ranged", "hp": 30.0, "damage": 9.0, "speed": 2.5, "height": 1.6, "xp": 6,
					"tint": Color(1.0, 0.55, 0.3), "glow": Color(0.4, 0.1, 0.02), "projectile": {"color": Color(1.0, 0.5, 0.15), "speed": 9.5, "volley": 1},
					"abilities": [{"id": "lob", "cooldown": 6.0, "first": 4.0, "radius": 1.8, "pool": 3.0, "color": Color(1.0, 0.45, 0.1)}]},
			],
			"w": [
				{"name": "Розпечена іскра", "model": "%sGreen Spiky Blob.glb", "kind": "melee", "hp": 13.0, "damage": 6.0, "speed": 4.8, "height": 0.8, "xp": 1, "group": 4,
					"tint": Color(1.0, 0.6, 0.2), "glow": Color(0.5, 0.15, 0.0), "attack_range": 1.3, "cooldown": 0.7},
			],
			"c": [
				{"name": "Залізний таран", "model": "%sYeti.glb", "kind": "charger", "hp": 90.0, "damage": 19.0, "speed": 2.9, "height": 2.1, "xp": 8,
					"tint": Color(0.35, 0.32, 0.3)},
			],
			"x": [
				{"name": "Вибуховий дух горна", "model": "%sHywirl.glb", "kind": "exploder", "hp": 24.0, "damage": 30.0, "speed": 4.6, "height": 1.2, "hover": 0.5, "xp": 4,
					"tint": Color(1.0, 0.4, 0.15), "glow": Color(0.5, 0.1, 0.02)},
			],
		}''' % (M, M, M, M, M),
    "boss": '''{"name": "Володар Горна", "model": "%sGlub Evolved.glb",
			"hp": 520.0, "damage": 22.0, "speed": 3.2, "height": 3.8, "xp": 85,
			"tint": Color(1.0, 0.35, 0.15), "glow": Color(0.6, 0.15, 0.02),
			"abilities": [
				{"id": "lob", "cooldown": 5.5, "first": 2.5, "radius": 2.2, "damage": 1.3, "pool": 3.5, "color": Color(1.0, 0.4, 0.1), "count": 3},
				{"id": "leap", "cooldown": 8.0, "first": 6.0, "radius_mult": 1.3},
			]}''' % M,
    "map": load_map("forge"),
})

# ============================================================== L6
LEVELS.append({
    "id": "vault",
    "arenas": "[Rect2i(4, 8, 18, 12), Rect2i(26, 10, 16, 10)]",
    "title": "Скарбниця Тіней",
    "subtitle": "Золота скарбниця під горою. Вартові-големи, золоті оси й Володар Скарбниці за пілонами.",
    "difficulty": 6,
    "stats": '{"hp": 4.6, "damage": 2.9, "gold": 4.8}',
    "theme": '''{
			"stone": Color(0.85, 0.72, 0.4),
			"floor": Color(0.8, 0.68, 0.4),
			"fog": Color(0.2, 0.16, 0.06), "fog_density": 0.02,
			"ambient": Color(0.75, 0.62, 0.35), "ambient_energy": 1.8,
			"torch": Color(1.0, 0.85, 0.4),
			"background": Color(0.06, 0.05, 0.02),
			"decor": "vault",
		}''',
    "enemies": '''{
			"m": [
				{"name": "Вартовий скарбниці", "model": "%sNinja.glb", "kind": "melee", "hp": 48.0, "damage": 13.0, "speed": 3.6, "height": 1.7, "xp": 6,
					"tint": Color(0.9, 0.78, 0.35), "glow": Color(0.3, 0.22, 0.05)},
			],
			"r": [
				{"name": "Золотий страж", "model": "%sSquidle.glb", "kind": "ranged", "hp": 34.0, "damage": 10.0, "speed": 2.4, "height": 1.5, "hover": 0.6, "xp": 7,
					"tint": Color(1.0, 0.85, 0.4), "projectile": {"color": Color(1.0, 0.85, 0.3), "speed": 10.0, "volley": 2}},
			],
			"w": [
				{"name": "Золота оса", "model": "%sArmabee Evolved.glb", "kind": "melee", "hp": 15.0, "damage": 7.0, "speed": 5.0, "height": 0.7, "hover": 0.8, "xp": 1, "group": 4,
					"tint": Color(1.0, 0.82, 0.3), "attack_range": 1.3, "cooldown": 0.7},
			],
			"x": [
				{"name": "Скарбний привид", "model": "%sGhost Skull.glb", "kind": "exploder", "hp": 26.0, "damage": 32.0, "speed": 4.3, "height": 1.3, "hover": 0.6, "xp": 4,
					"tint": Color(1.0, 0.9, 0.5), "glow": Color(0.4, 0.3, 0.05)},
			],
			"t": [
				{"name": "Вартовий-голем", "model": "%sGoleling Evolved.glb", "kind": "totem", "hp": 80.0, "damage": 0.0, "speed": 0.0, "height": 2.0, "hover": 0.2, "xp": 5,
					"tint": Color(0.85, 0.72, 0.4), "glow": Color(0.3, 0.22, 0.05), "no_elite": true,
					"abilities": [{"id": "ward", "factor": 0.2, "range": 7.0, "links": 2}]},
			],
		}''' % (M, M, M, M, M),
    "boss": '''{"name": "Володар Скарбниці", "model": "%sDemon-LnfIziKv4o.glb",
			"hp": 650.0, "damage": 24.0, "speed": 2.9, "height": 4.0, "xp": 100,
			"tint": Color(1.0, 0.82, 0.35), "glow": Color(0.45, 0.32, 0.05),
			"abilities": [
				{"id": "pylons", "cooldown": 1.0, "first": 3.0, "count": 3, "pylon": %s},
				{"id": "radial_volley", "cooldown": 7.0, "first": 5.0, "count": 16, "speed": 8.5, "color": Color(1.0, 0.85, 0.3)},
			]}''' % (M, GOLD_PYLON),
    "map": load_map("vault"),
})

# ============================================================== L7
LEVELS.append({
    "id": "village",
    "arenas": "[Rect2i(4, 22, 20, 10), Rect2i(24, 8, 18, 10)]",
    "title": "Спустошене Село",
    "subtitle": "Село, спалене розбійниками. Дикі вепри, вороняча зграя й Ватажок розбійників.",
    "difficulty": 7,
    "stats": '{"hp": 5.6, "damage": 3.3, "gold": 5.6}',
    "theme": '''{
			"stone": Color(0.6, 0.58, 0.52),
			"floor": Color(0.55, 0.5, 0.42),
			"fog": Color(0.12, 0.13, 0.1), "fog_density": 0.032,
			"ambient": Color(0.45, 0.48, 0.42), "ambient_energy": 1.5,
			"torch": Color(1.0, 0.7, 0.35),
			"background": Color(0.05, 0.06, 0.05),
			"decor": "village",
		}''',
    "enemies": '''{
			"m": [
				{"name": "Розбійник", "model": "%sOrc Enemy.glb", "kind": "melee", "hp": 55.0, "damage": 15.0, "speed": 3.4, "height": 1.8, "xp": 7,
					"tint": Color(0.55, 0.42, 0.3), "abilities": [{"id": "leap", "cooldown": 7.0, "first": 4.0, "radius_mult": 0.8}]},
			],
			"r": [
				{"name": "Розбійник-лучник", "model": "%sNinja.glb", "kind": "ranged", "hp": 36.0, "damage": 11.0, "speed": 2.7, "height": 1.6, "xp": 7,
					"tint": Color(0.3, 0.4, 0.28), "projectile": {"color": Color(0.7, 0.55, 0.3), "speed": 11.0, "volley": 1}},
			],
			"w": [
				{"name": "Здичавілий щур", "model": "%sGreen Spiky Blob.glb", "kind": "melee", "hp": 14.0, "damage": 6.0, "speed": 5.2, "height": 0.7, "xp": 1, "group": 5,
					"tint": Color(0.4, 0.35, 0.3), "attack_range": 1.2, "cooldown": 0.6},
			],
			"c": [
				{"name": "Дикий вепр", "model": "%sYeti.glb", "kind": "charger", "hp": 100.0, "damage": 21.0, "speed": 3.1, "height": 1.6, "xp": 9,
					"tint": Color(0.5, 0.35, 0.22)},
			],
			"x": [
				{"name": "Вороняча зграя", "model": "%sHywirl.glb", "kind": "exploder", "hp": 26.0, "damage": 33.0, "speed": 4.9, "height": 1.1, "hover": 0.6, "xp": 4,
					"tint": Color(0.2, 0.2, 0.22)},
			],
		}''' % (M, M, M, M, M),
    "boss": '''{"name": "Ватажок розбійників", "model": "%sBlue Demon.glb",
			"hp": 800.0, "damage": 27.0, "speed": 3.3, "height": 3.6, "xp": 130,
			"tint": Color(0.5, 0.15, 0.15), "glow": Color(0.3, 0.05, 0.05),
			"abilities": [
				{"id": "blink", "cooldown": 7.0, "first": 4.0},
				{"id": "web", "cooldown": 6.5, "first": 6.0, "count": 3, "slow": 0.45, "slow_time": 3.0},
			]}''' % M,
    "map": load_map("village_ruins"),
})

# ============================================================== L8
LEVELS.append({
    "id": "abyss",
    "arenas": "[Rect2i(2, 14, 18, 12), Rect2i(28, 14, 18, 12)]",
    "title": "Безодня Рун",
    "subtitle": "Розлам, звідки тхне чужим світом. Демони Безодні, малі дракони й Володар Рун.",
    "difficulty": 8,
    "stats": '{"hp": 6.8, "damage": 3.8, "gold": 6.6}',
    "theme": '''{
			"stone": Color(0.42, 0.35, 0.55),
			"floor": Color(0.3, 0.24, 0.42),
			"fog": Color(0.08, 0.04, 0.14), "fog_density": 0.04,
			"ambient": Color(0.35, 0.25, 0.55), "ambient_energy": 1.7,
			"torch": Color(0.7, 0.35, 1.0),
			"background": Color(0.02, 0.01, 0.05),
			"decor": "abyss",
		}''',
    "enemies": '''{
			"m": [
				{"name": "Демон Безодні", "model": "%sDemon-LnfIziKv4o.glb", "kind": "melee", "hp": 75.0, "damage": 20.0, "speed": 3.3, "height": 2.2, "xp": 9,
					"tint": Color(0.55, 0.3, 0.75), "glow": Color(0.25, 0.05, 0.4)},
			],
			"r": [
				{"name": "Рунний чаклун", "model": "%sWizard.glb", "kind": "ranged", "hp": 45.0, "damage": 14.0, "speed": 2.5, "height": 1.9, "xp": 9,
					"tint": Color(0.45, 0.3, 0.7), "glow": Color(0.2, 0.05, 0.35), "projectile": {"color": Color(0.7, 0.3, 1.0), "speed": 11.0, "volley": 2},
					"abilities": [{"id": "lob", "cooldown": 6.5, "first": 5.0, "radius": 2.0, "pool": 3.0, "color": Color(0.6, 0.2, 0.9)}]},
			],
			"w": [
				{"name": "Тіньова оса", "model": "%sArmabee Evolved.glb", "kind": "melee", "hp": 18.0, "damage": 8.0, "speed": 5.2, "height": 0.7, "hover": 0.8, "xp": 1, "group": 4,
					"tint": Color(0.5, 0.25, 0.7), "glow": Color(0.25, 0.05, 0.4), "attack_range": 1.3, "cooldown": 0.65},
			],
			"c": [
				{"name": "Малий Дракон Безодні", "model": "%sDragon Evolved.glb", "kind": "charger", "hp": 140.0, "damage": 26.0, "speed": 3.4, "height": 2.8, "hover": 0.5, "xp": 12,
					"tint": Color(0.3, 0.15, 0.4), "glow": Color(0.35, 0.1, 0.55)},
			],
			"t": [
				{"name": "Спалене Серце", "model": "%sMushroom King.glb", "kind": "totem", "hp": 110.0, "damage": 0.0, "speed": 0.0, "height": 2.4, "xp": 6,
					"tint": Color(0.4, 0.2, 0.55), "glow": Color(0.3, 0.08, 0.45), "no_elite": true,
					"abilities": [{"id": "ward", "factor": 0.25, "range": 8.0, "links": 3}]},
			],
		}''' % (M, M, M, M, M),
    "boss": '''{"name": "Володар Рун", "model": "%sGoleling Evolved.glb",
			"hp": 1000.0, "damage": 30.0, "speed": 2.8, "height": 4.4, "hover": 0.3, "xp": 180,
			"tint": Color(0.45, 0.22, 0.6), "glow": Color(0.5, 0.15, 0.8),
			"abilities": [
				{"id": "beams", "cooldown": 11.0, "first": 3.0, "count": 3, "length": 13.0, "time": 3.5, "turn": 1.1, "color": Color(0.8, 0.3, 1.0)},
				{"id": "ring_slam", "cooldown": 8.5, "first": 6.0, "radius": 13.0, "speed": 8.0, "color": Color(0.7, 0.25, 1.0)},
				{"id": "radial_volley", "cooldown": 9.0, "first": 9.0, "phase": 2, "count": 18, "speed": 9.0, "color": Color(0.75, 0.3, 1.0)},
			]}''' % M,
    "map": load_map("abyss"),
})


def render(level):
    return '''	{
		"id": &"%s",
		"arenas": %s,
		"title": "%s",
		"subtitle": "%s",
		"difficulty": %d,
		"stats": %s,
		"theme": %s,
		"enemies": %s,
		"boss": %s,
		"map": [
%s
		],
	},
''' % (level["id"], level["arenas"], level["title"], level["subtitle"], level["difficulty"],
       level["stats"], level["theme"], level["enemies"], level["boss"], level["map"])


out = "\n".join(render(lv) for lv in LEVELS)

path = os.path.join(ROOT, "scenes", "dungeon", "dungeon_levels.gd")
text = io.open(path, encoding="utf-8").read()
marker = "\n]\n\nstatic func get_level(index: int) -> Dictionary:"
assert text.count(marker) == 1, "marker not found once"
text = text.replace(marker, "\n" + out + "]\n\nstatic func get_level(index: int) -> Dictionary:")
io.open(path, "w", encoding="utf-8", newline="\n").write(text)
print("inserted", len(LEVELS), "levels into", path)
