# 4-й данж (Кістяний Погост) — вороги й бос гравця; 3-й данж — слабший голем.
import sys
P = r"D:\Claude code\idle survivor_like\scenes\dungeon\dungeon_levels.gd"
s = open(P, encoding="utf-8").read()


def rep(old, new):
    global s
    n = s.count(old)
    if n != 1:
        sys.exit("NOT FOUND x%d: %r" % (n, old[:90]))
    s = s.replace(old, new)


# --- 3-й данж: голем був засильний ---
rep('''				{"name": "Крижаний голем", "model": "res://assets/models/monsters/ice_golem.glb", "kind": "tank",
					"hp": 140.0, "damage": 14.0, "speed": 1.7, "height": 2.5, "xp": 9, "no_elite": true,
					"attack_anims": ["Weapon"],
					"ice_shield": {"ratio": 0.7, "melt_vuln": 1.3},
					"frost_aura": {"radius": 3.2, "slow": 0.75},
					"special_anims": {"ring_slam": ["Slam"]},
					"abilities": [{"id": "ring_slam", "cooldown": 7.0, "first": 3.0, "radius": 7.0, "speed": 6.0,
						"freeze": 1.0, "windup": 0.8, "color": Color(0.6, 0.9, 1.0)}]},''',
    '''				{"name": "Крижаний голем", "model": "res://assets/models/monsters/ice_golem.glb", "kind": "tank",
					"hp": 100.0, "damage": 12.0, "speed": 1.7, "height": 2.5, "xp": 9, "no_elite": true,
					"attack_anims": ["Weapon"],
					"ice_shield": {"ratio": 0.5, "melt_vuln": 1.3},
					"frost_aura": {"radius": 2.8, "slow": 0.82},
					"special_anims": {"ring_slam": ["Slam"]},
					"abilities": [{"id": "ring_slam", "cooldown": 8.0, "first": 3.5, "radius": 7.0, "speed": 6.0,
						"freeze": 0.6, "windup": 0.95, "color": Color(0.6, 0.9, 1.0)}]},''')

# --- спільні описи для 4-го данжу (до LEVELS: на них посилаються прийоми) ---
rep('''const LEVELS := [
''', '''## Кістяний Погост: кого кличуть прийоми (чаклун і бос — скелетів; бос —
## ще й тотеми, що його бережуть, і свій череп у купі кісток).
const BONE_SKELETON := {"name": "Кістяк", "model": "res://assets/models/monsters/Orc Enemy.glb", "kind": "melee",
	"hp": 12.0, "damage": 5.0, "speed": 3.2, "height": 1.5, "xp": 1, "tint": Color(0.9, 0.88, 0.8), "no_elite": true}
const BONE_TOTEM_SHIELD := {"seconds": 3.0, "cooldown": 3.0}
const BONE_WARD_TOTEM := {"name": "Кістяний тотем", "model": "res://assets/models/monsters/bone_totem.glb", "kind": "totem",
	"hp": 40.0, "damage": 0.0, "speed": 0.0, "height": 2.3, "xp": 3, "no_elite": true, "bone_shield": BONE_TOTEM_SHIELD,
	"abilities": [{"id": "ward", "target": "boss", "factor": 0.5, "range": 40.0, "links": 1, "color": Color(0.45, 1.0, 0.5)},
		{"id": "empower", "radius": 8.0, "bonus": 1.25, "regen": 0.015, "links": 6}]}
const BONE_SKULL := {"name": "Череп Володаря", "model": "res://assets/models/graveyard/skull.glb", "kind": "totem",
	"hp": 28.0, "damage": 0.0, "speed": 0.0, "height": 0.75, "hover": 0.25, "xp": 0, "no_elite": true,
	"glow": Color(0.3, 0.9, 0.35)}

const LEVELS := [
''')

start = s.index('''	{
		"id": &"bone_yard",''')
end = s.index('''	{
		"id": &"herald_of_doom",''')
MAP = [
    "##########################################",
    "##########################################",
    "###########....................###########",
    "###########....................###########",
    "###########........B........E..###########",
    "###########....................###########",
    "###########....................###########",
    "###########....................###########",
    "###########....................###########",
    "####################..####################",
    "####..................................####",
    "####..................................####",
    "####.................#................####",
    "####.......t.........#........t.......####",
    "####............w....#....r...........####",
    "####....m............#................####",
    "####.............x...#...........x....####",
    "####........m........#......w.........####",
    "####.................#................####",
    "####......r..........#.........m......####",
    "###################..#########..##########",
    "###################..#########..##########",
    "######............r..###............######",
    "######...............###.....w......######",
    "######.....w.........###............######",
    "######..............................######",
    "######....m...................m.....######",
    "######...............###.....x......######",
    "######..............r###............######",
    "######...............###............######",
    "###################..#####################",
    "###################..#####################",
    "#################........#################",
    "#################........#################",
    "#################...S....#################",
    "#################........#################",
    "#################........#################",
    "#################........#################",
    "##########################################",
    "##########################################",
]
assert all(len(r) == 42 for r in MAP), [len(r) for r in MAP]
map_text = "".join('\t\t\t"%s",\n' % r for r in MAP)
block = '''	{
		"id": &"bone_yard",
		"arenas": [Rect2i(4, 10, 16, 10), Rect2i(22, 10, 16, 10)],
		"title": "Кістяний Погост",
		"subtitle": "Цвинтар за містом ожив. Привиди крізь стіни, хробаки з-під землі, кістяні чаклуни й Кістяний Володар.",
		"difficulty": 4,
		"stats": {"hp": 2.8, "damage": 2.0, "gold": 3.2},
		"theme": {
			"stone": Color(0.55, 0.58, 0.5),
			"floor": Color(0.6, 0.62, 0.56),
			"fog": Color(0.15, 0.18, 0.14), "fog_density": 0.03,
			"ambient": Color(0.4, 0.48, 0.4), "ambient_energy": 1.4,
			"torch": Color(0.55, 1.0, 0.55),
			"background": Color(0.03, 0.04, 0.03),
			"decor": "graveyard",
		},
		# Вороги кладовища — моделі гравця (D:/Вороги, завдання в Tusk.txt).
		# Скелети й анімації (D:/RuneHorde_work/scripts/blender): чаклун —
		# rig_bone_warlock.py (свій скелет, посох твердий, стик розрізано);
		# привид, хробак, плоть — rig_rodin_custom.py + anims_*.py (свої
		# анімації на скелеті Rodin, ланцюг привида — окремий меш); тотем —
		# prep_prop.py (нерухомий).
		"enemies": {
			# Кладовищенський привид — літає крізь стіни й надгробки (з'являється
			# з несподіваних боків); холодний дотик — 3 с удари героя на 30%
			# повільніші; зникнення — 2 с видно лише ланцюг, що пливе до героя,
			# тоді виринає за спиною й б'є.
			"m": [
				{"name": "Кладовищенський привид", "model": "res://assets/models/monsters/grave_ghost.glb", "kind": "melee",
					"hp": 30.0, "damage": 9.0, "speed": 3.0, "height": 1.8, "hover": 0.35, "xp": 5,
					"phasing": true, "attack_range": 1.9, "attack_anims": ["Weapon"],
					"chill": {"factor": 0.7, "seconds": 3.0},
					"abilities": [{"id": "vanish", "cooldown": 9.0, "first": 4.0, "fade": 2.0, "min": 3.0, "max": 11.0}]},
			],
			# Кістяний чаклун — пріоритетна ціль: раз на 8 с піднімає 2 скелети
			# (поки живий — знову й знову); зелена кістяна стріла летить по
			# прямій (відкотись); герой надто близько — провалюється в могилу й
			# виринає в іншому кінці кладовища.
			"r": [
				{"name": "Кістяний чаклун", "model": "res://assets/models/monsters/bone_warlock.glb", "kind": "ranged",
					"hp": 28.0, "damage": 8.0, "speed": 2.3, "height": 1.95, "xp": 7, "no_elite": true,
					"projectile": {"color": Color(0.5, 1.0, 0.45), "speed": 11.0, "volley": 1, "shape": "spear"},
					"special_anims": {"raise_dead": ["Cast"]},
					"abilities": [
						{"id": "grave_escape", "cooldown": 9.0, "first": 0.0, "trigger": 3.5, "min": 9.0, "reach": 16.0},
						{"id": "raise_dead", "cooldown": 8.0, "first": 2.0, "count": 2, "max": 4, "summon": BONE_SKELETON}]},
			],
			# Кістяний хробак — під землею (видно лише горбик ґрунту, не вдарити);
			# під героєм за 1 с тріскається коло — вистрибує й підкидає; потім 2 с
			# стоїть на поверхні й кусає — лише тоді його можна бити.
			"w": [
				{"name": "Кістяний хробак", "model": "res://assets/models/monsters/bone_worm.glb", "kind": "melee",
					"hp": 30.0, "damage": 10.0, "speed": 4.0, "height": 1.5, "xp": 5,
					"anchored": true, "attack_range": 2.2, "attack_arc": 60.0, "attack_anims": ["Weapon"],
					"abilities": [{"id": "tunnel", "radius": 1.6, "warn": 1.0, "surface": 2.0, "toss": 0.8, "rest": 0.8, "damage": 1.2}]},
			],
			# Розкладена плоть — повільний "танк": довкола отруйна хмара (бий
			# здалеку); гине з вибухом — шкодить і іншим ворогам (добий біля
			# них), лишає отруйну калюжу на 4 с.
			"x": [
				{"name": "Розкладена плоть", "model": "res://assets/models/monsters/rotting_flesh.glb", "kind": "melee",
					"hp": 70.0, "damage": 10.0, "speed": 1.6, "height": 2.0, "xp": 6, "tank": true,
					"attack_range": 2.0, "attack_anims": ["Weapon"],
					"abilities": [{"id": "poison_cloud", "radius": 2.4, "every": 0.5, "damage": 0.15},
						{"id": "death_blast", "radius": 3.0, "delay": 0.45, "damage": 1.2, "mob_share": 0.5,
							"pool": 4.0, "pool_radius": 2.2, "pool_damage": 0.25}]},
			],
			# Кістяний тотем — нерухома підтримка: вороги в 8 м б'ють на 25%
			# сильніше й потроху лікуються (зелені нитки); ударили — 3 с
			# кістяний щит, що ковтає перший наступний удар (бий серією).
			# Сам не б'є, але його треба знищувати першим.
			"t": [
				{"name": "Кістяний тотем", "model": "res://assets/models/monsters/bone_totem.glb", "kind": "totem",
					"hp": 45.0, "damage": 0.0, "speed": 0.0, "height": 2.3, "xp": 5, "no_elite": true,
					"bone_shield": BONE_TOTEM_SHIELD,
					"abilities": [{"id": "empower", "radius": 8.0, "bonus": 1.25, "regen": 0.015, "links": 6}]},
			],
		},
		# Кістяний Володар (модель гравця; свій скелет і анімації —
		# scripts/blender/rig_bone_lord.py: коса тверда на окремій кістці, у
		# кидку ховається, а летить окрема модель props/bone_scythe.glb). Фази:
		#   1 (100-65%): широкий укіс 180° перед собою (перекат назад або за
		#     спину); кидок коси бумерангом — ранить і туди, і назад;
		#   2 (65-30%): армія мертвих — встромляє косу, по краях арени 3
		#     тотеми й скелети; поки стоїть хоч один тотем — бос отримує лише
		#     половину шкоди;
		#   3 (<30%): вічний повелитель — уперше впавши, розсипається купою
		#     кісток і за 5 с встає з 30% здоров'я, якщо не розбити світний
		#     череп у купі; б'є частіше, після кожного удару — кістяні шипи.
		"boss": {"name": "Кістяний Володар", "model": "res://assets/models/monsters/bone_lord.glb", "style": "bone_lord",
			"hp": 520.0, "damage": 17.0, "speed": 2.8, "height": 3.4, "xp": 70, "turn_factor": 0.6,
			"no_hazard_rain": true, "phase_thresholds": [0.65, 0.3], "phase_lock": true, "frenzy_cooldown": 0.7,
			"attack_anims": ["Weapon"], "attack_arc": 70.0,
			"special_anims": {"scythe_sweep": ["Sweep"], "scythe_throw": ["Throw"]},
			"abilities": [
				{"id": "eternal_lord", "phase": 3, "rise": 5.0, "revive": 0.3, "skull": BONE_SKULL},
				{"id": "army_of_dead", "phase": 2, "until": 2, "first": 0.5, "totems": 3, "skeletons": 4, "plant": 2.2,
					"totem": BONE_WARD_TOTEM, "skeleton": BONE_SKELETON},
				{"id": "scythe_sweep", "cooldown": 6.5, "first": 3.0, "radius": 4.6, "arc": 90.0, "windup": 0.9,
					"damage": 1.3, "push": 6.0},
				{"id": "scythe_throw", "cooldown": 9.0, "first": 6.0, "min": 4.5, "range": 12.0, "windup": 0.6, "out": 0.8,
					"width": 1.6, "hit_radius": 1.2, "damage": 1.1, "prop": "res://assets/models/props/bone_scythe.glb"},
				{"id": "bone_spikes", "phase": 3, "length": 9.0, "width": 1.3, "tell": 0.55, "damage": 0.9},
			]},
		"map": [
''' + map_text + '''		],
	},

'''
s = s[:start] + block + s[end:]
open(P, "w", encoding="utf-8").write(s)
print("OK levels")
