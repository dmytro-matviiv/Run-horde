# -*- coding: utf-8 -*-
"""Пише scenes/dungeon/dungeon_levels.gd: три рівні з темами, ворогами й картами."""
import re

PROJECT = r'D:\Claude code\idle survivor_like'
old = open(PROJECT + r'\scenes\dungeon\dungeon_levels.gd', encoding='utf-8').read()
level1_map = re.search(r'"map": \[\n(.*?)\n\t\t\],', old, re.S).group(1)
level2_map = open(r'D:\RuneHorde_work\logs\level2_map.txt', encoding='utf-8').read()
level3_map = open(r'D:\RuneHorde_work\logs\level3_map.txt', encoding='utf-8').read()

M = 'res://assets/models/monsters/'

text = '''extends RefCounted
class_name DungeonLevels

## РІВНІ ДАНЖУ. Кожен — окремий світ зі своїм виглядом, ворогами й
## босом, і кожен наступний відкривається лише після попереднього.
##
## Карта — кілька рядків тексту, один символ = клітинка 2x2 метри:
##   #  стіна       .  підлога     S  вхід (тут ворогів немає)
##   B  бос         E  вихід (відчиняється після боса)
##   m  ворог ближнього бою         r  стрілець
##   w  рій — одразу кілька дрібних швидких ворогів
##   x  вибуховий — біжить до героя й вибухає
##   c  таран — розганяється по прямій
##   t  голем — повільний, дуже міцний, б'є по площі
##
## ТЕМА фарбує ті самі модулі стін у свій колір, міняє туман, світло й
## дрібні прикраси. Для телефона це нічого не коштує: копії матеріалів
## робляться один раз на рівень, а кількість команд малювання та сама.
##
## ВОРОГИ описані для кожного символу окремо, тож один і той самий
## символ "m" в різних рівнях — різні істоти.
##   kind      — поведінка (melee, ranged, exploder, charger, tank);
##   hp/damage — базові числа, далі множаться на силу рівня (stats);
##   speed, height (зріст у метрах), hover (скільки ширяє над землею),
##   group     — скільки з'являється на одній мітці (рій);
##   projectile — колір, швидкість і кількість снарядів у залпі.

const LEVELS := [
	{
		"id": &"crypts",
		"title": "Забуті склепи",
		"subtitle": "Старі гробниці під містом. Орки, слизні й чаклуни.",
		"difficulty": 1,
		"stats": {"hp": 1.0, "damage": 1.0, "gold": 1.0},
		"theme": {
			"stone": Color(1.0, 1.0, 1.0),
			"floor": Color(1.0, 1.0, 1.0),
			"fog": Color(0.09, 0.07, 0.08), "fog_density": 0.02,
			"ambient": Color(0.45, 0.4, 0.42), "ambient_energy": 1.6,
			"torch": Color(1.0, 0.72, 0.38),
			"background": Color(0.035, 0.03, 0.05),
			"decor": "crypt",
		},
		"enemies": {
			"m": [
				{"name": "Орк", "model": "%(M)sOrc Enemy.glb", "kind": "melee", "hp": 30.0, "damage": 8.0, "speed": 2.8, "height": 1.7, "xp": 3},
				{"name": "Шипастий слиз", "model": "%(M)sGreen Spiky Blob.glb", "kind": "melee", "hp": 30.0, "damage": 8.0, "speed": 2.8, "height": 1.5, "xp": 3},
				{"name": "Черепок", "model": "%(M)sGhost Skull.glb", "kind": "melee", "hp": 26.0, "damage": 8.0, "speed": 3.1, "height": 1.5, "hover": 0.5, "xp": 3},
			],
			"r": [
				{"name": "Чаклун", "model": "%(M)sWizard.glb", "kind": "ranged", "hp": 22.0, "damage": 6.0, "speed": 2.2, "height": 1.7, "xp": 4,
					"projectile": {"color": Color(0.75, 0.35, 1.0), "speed": 10.0, "volley": 1}},
			],
		},
		"boss": {"name": "Демон Склепів", "model": "%(M)sDemon-LnfIziKv4o.glb", "style": "demon",
			"hp": 220.0, "damage": 16.0, "speed": 3.2, "height": 3.4, "xp": 25},
		"map": [
%(L1)s
		],
	},
	{
		"id": &"fungal",
		"title": "Грибні нетрі",
		"subtitle": "Печери, де дихає отрутою грибниця. Рої, слизні, що вибухають, і Грибний Король.",
		"difficulty": 2,
		"stats": {"hp": 1.55, "damage": 1.3, "gold": 1.6},
		"theme": {
			"stone": Color(0.7, 0.9, 0.76),
			"floor": Color(0.72, 0.86, 0.72),
			"fog": Color(0.04, 0.11, 0.08), "fog_density": 0.028,
			"ambient": Color(0.35, 0.56, 0.45), "ambient_energy": 1.5,
			"torch": Color(0.55, 1.0, 0.62),
			"background": Color(0.02, 0.05, 0.04),
			"decor": "fungal",
		},
		"enemies": {
			"m": [
				{"name": "Грибовик", "model": "%(M)sMushnub Evolved.glb", "kind": "melee", "hp": 34.0, "damage": 9.0, "speed": 2.9, "height": 1.7, "xp": 3},
			],
			"w": [
				{"name": "Грибочок", "model": "%(M)sMushnub.glb", "kind": "melee", "hp": 11.0, "damage": 4.0, "speed": 4.4, "height": 0.9, "xp": 1, "group": 3,
					"attack_range": 1.5, "cooldown": 0.9},
			],
			"x": [
				{"name": "Токсичний слиз", "model": "%(M)sPink Blob.glb", "kind": "exploder", "hp": 18.0, "damage": 24.0, "speed": 4.0, "height": 1.2, "xp": 3},
			],
			"r": [
				{"name": "Плювальник", "model": "%(M)sSquidle.glb", "kind": "ranged", "hp": 24.0, "damage": 7.0, "speed": 2.4, "height": 1.4, "hover": 0.7, "xp": 4,
					"projectile": {"color": Color(0.45, 1.0, 0.3), "speed": 8.0, "volley": 2}},
			],
		},
		"boss": {"name": "Грибний Король", "model": "%(M)sMushroom King.glb", "style": "summoner",
			"hp": 260.0, "damage": 17.0, "speed": 3.0, "height": 3.4, "xp": 35,
			"summon": {"name": "Грибочок", "model": "%(M)sMushnub.glb", "kind": "melee", "hp": 11.0, "damage": 4.0, "speed": 4.4, "height": 0.9, "xp": 1,
				"attack_range": 1.5, "cooldown": 0.9}},
		"map": [
%(L2)s
		],
	},
	{
		"id": &"citadel",
		"title": "Крижана цитадель",
		"subtitle": "Мерзла фортеця. Тарани, кам'яні големи, крижані чаклуни і Дракон.",
		"difficulty": 3,
		"stats": {"hp": 2.2, "damage": 1.7, "gold": 2.4},
		"theme": {
			"stone": Color(0.74, 0.86, 1.0),
			"floor": Color(0.8, 0.9, 1.0),
			"fog": Color(0.1, 0.14, 0.2), "fog_density": 0.022,
			"ambient": Color(0.5, 0.6, 0.8), "ambient_energy": 1.7,
			"torch": Color(0.6, 0.85, 1.0),
			"background": Color(0.04, 0.06, 0.1),
			"decor": "citadel",
		},
		"enemies": {
			"m": [
				{"name": "Ніндзя-вартовий", "model": "%(M)sNinja.glb", "kind": "melee", "hp": 34.0, "damage": 9.0, "speed": 3.8, "height": 1.7, "xp": 4,
					"cooldown": 1.0},
			],
			"c": [
				{"name": "Єті-таран", "model": "%(M)sYeti.glb", "kind": "charger", "hp": 70.0, "damage": 16.0, "speed": 2.6, "height": 2.2, "xp": 6},
			],
			"t": [
				{"name": "Кам'яний голем", "model": "%(M)sGoleling Evolved.glb", "kind": "tank", "hp": 150.0, "damage": 14.0, "speed": 1.8, "height": 2.4, "hover": 0.3, "xp": 8},
			],
			"r": [
				{"name": "Крижаний чаклун", "model": "%(M)sBlue Demon.glb", "kind": "ranged", "hp": 30.0, "damage": 7.0, "speed": 2.3, "height": 1.9, "xp": 5,
					"projectile": {"color": Color(0.5, 0.85, 1.0), "speed": 11.0, "volley": 3}},
			],
			"x": [
				{"name": "Хуртовинний дух", "model": "%(M)sHywirl.glb", "kind": "exploder", "hp": 22.0, "damage": 28.0, "speed": 4.6, "height": 1.3, "hover": 0.6, "xp": 4},
			],
		},
		"boss": {"name": "Крижаний Дракон", "model": "%(M)sDragon Evolved.glb", "style": "dragon",
			"hp": 320.0, "damage": 18.0, "speed": 3.4, "height": 4.0, "hover": 0.8, "xp": 50,
			"projectile": {"color": Color(0.55, 0.9, 1.0), "speed": 12.0, "volley": 5}},
		"map": [
%(L3)s
		],
	},
]

static func get_level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]

static func get_level_count() -> int:
	return LEVELS.size()

## Хто трапляється на рівні — для картки на екрані вибору рівня.
static func get_enemy_names(index: int) -> Array:
	var level := get_level(index)
	var names: Array = []
	for symbol: String in level.enemies:
		for enemy: Dictionary in level.enemies[symbol]:
			if not names.has(enemy.name):
				names.append(enemy.name)
	return names
''' % {'M': M, 'L1': level1_map, 'L2': level2_map, 'L3': level3_map}

open(PROJECT + r'\scenes\dungeon\dungeon_levels.gd', 'w', encoding='utf-8', newline='\n').write(text)
print('рівні записано')
