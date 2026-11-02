# -*- coding: utf-8 -*-
P = "D:/Claude code/idle survivor_like/scenes/dungeon/dungeon_levels.gd"
s = open(P, encoding="utf-8").read()
i = s.find('"id": &"citadel"')
start = s.find('\t\t"enemies": {', i)
end = s.find('\t\t"map": [', start)
assert i > 0 and start > i and end > start
NEW = '''		# Вороги крижаної цитаделі — моделі гравця (D:/Вороги, завдання в Tusk.txt).
		# Скелети й анімації: scripts/blender/prep_rodin_mob.py (зброя жорстко на
		# кисті) і rig_sentinel.py (вартовий — свій скелет, меч не розмазується).
		"enemies": {
			# Ожилий вартовий — пастка: стоїть кам'яною статуєю (і на місці
			# частини справжніх статуй), оживає, коли герой поруч, — б'є з
			# розвороту; широкий розмах мечем; гине — розлітається уламками.
			"m": [
				{"name": "Ожилий вартовий", "model": "res://assets/models/monsters/ice_sentinel.glb", "kind": "melee",
					"hp": 40.0, "damage": 12.0, "speed": 2.6, "height": 2.3, "xp": 6,
					"attack_range": 2.6, "attack_arc": 75.0, "attack_anims": ["Weapon"],
					"dormant": {"wake": 3.5, "spin_radius": 3.0, "spin_damage": 1.2, "visor_height": 0.9, "visor_forward": 0.1},
					"abilities": [{"id": "shatter", "radius": 2.6, "delay": 0.5, "damage": 1.0}]},
			],
			# Морозний таранник — таранний біг (1 с цілиться, світла смуга),
			# відкидає далеко; об стіну чи статую — застрягає на 2 с і отримує
			# подвійну шкоду; при першій зустрічі — підкат, що збиває з ніг на 2 с.
			"c": [
				{"name": "Морозний таранник", "model": "res://assets/models/monsters/frost_troll.glb", "kind": "charger",
					"hp": 60.0, "damage": 15.0, "speed": 3.0, "height": 2.2, "xp": 7,
					"attack_anims": ["Weapon", "Weapon2"],
					"charge": {"cooldown": 6.0, "windup": 1.0, "wall_stun": 2.0, "stun_damage": 2.0, "knockdown": 0.5,
						"push": 13.0, "anim": "Charge", "windup_anim": "Idle", "color": Color(0.8, 0.95, 1.0, 0.85)},
					"special_anims": {"slide_tackle": ["Slide"]},
					"abilities": [{"id": "slide_tackle", "first": 0.0, "min": 3.5, "max": 9.0, "speed": 12.0, "time": 0.7,
						"down": 2.0, "damage": 0.8, "windup": 0.3}]},
			],
			# Крижаний голем — "танк": спершу жовтий щит (поки цілий — здоров'я
			# не міняється), морозна аура (поруч на 25% повільніше), удар об
			# землю — крижане кільце, що вмерзає на 1 с. Вогонь розтоплює щит, і
			# далі голем отримує на 30% більше.
			"t": [
				{"name": "Крижаний голем", "model": "res://assets/models/monsters/ice_golem.glb", "kind": "tank",
					"hp": 140.0, "damage": 14.0, "speed": 1.7, "height": 2.5, "xp": 9, "no_elite": true,
					"attack_anims": ["Weapon"],
					"ice_shield": {"ratio": 0.7, "melt_vuln": 1.3},
					"frost_aura": {"radius": 3.2, "slow": 0.75},
					"special_anims": {"ring_slam": ["Slam"]},
					"abilities": [{"id": "ring_slam", "cooldown": 7.0, "first": 3.0, "radius": 7.0, "speed": 6.0,
						"freeze": 1.0, "windup": 0.8, "color": Color(0.6, 0.9, 1.0)}]},
			],
			# Інейна чаклунка — пріоритетна ціль: віяло з 3 крижаних списів
			# (від них ховаються за колоною), крижана стіна між собою й героєм
			# (обійти чи розбити), раз за бій — крижаний панцир на союзника (3 с
			# без шкоди).
			"r": [
				{"name": "Інейна чаклунка", "model": "res://assets/models/monsters/frost_witch.glb", "kind": "ranged",
					"hp": 30.0, "damage": 8.0, "speed": 2.4, "height": 1.9, "xp": 7,
					"projectile": {"color": Color(0.6, 0.92, 1.0), "speed": 12.0, "volley": 3, "shape": "spear"},
					"special_anims": {"ice_wall": ["Cast"], "ice_armor": ["Support"]},
					"abilities": [
						{"id": "ice_wall", "cooldown": 10.0, "first": 4.0, "hp": 14.0, "width": 3.2, "lifetime": 8.0},
						{"id": "ice_armor", "first": 2.0, "range": 10.0, "seconds": 3.0}]},
			],
			"x": [
				{"name": "Крижаний вихор", "model": "res://assets/models/monsters/Hywirl.glb", "kind": "exploder", "hp": 22.0, "damage": 28.0, "speed": 4.6, "height": 1.3, "hover": 0.6, "xp": 4},
			],
		},
		# Інейний Дракон (модель гравця; зайвий "кіготь" біля правого ока
		# прибрано, смерть домальовано — add_dragon_death.py). Три фази:
		#   1 (100-65%): крижане дихання конусом (у пащі яскравішає світло —
		#     сигнал ухилитись; вмерзає на 1.5 с), удар хвостом позаду й збоку;
		#   2 (65-30%): злітає — тіні-кола, бурульки падають і лишаються
		#     колонами (ховають від дихання); за 10 с приземляється з ударом по
		#     колу й 3 с оглушений;
		#   3 (<30%): вічна зима — лід нашаровується на героя (вмерзає, якщо
		#     стояти), сходить лише біля світлої руни, руни спалахують по черзі;
		#     дихає частіше, б'є крилами (зносить до країв). Гине — колони
		#     тріскаються, руни згасають одна за одною.
		"boss": {"name": "Інейний Дракон", "model": "res://assets/models/monsters/frost_dragon.glb", "style": "frost_dragon",
			"hp": 700.0, "damage": 18.0, "speed": 3.0, "height": 3.4, "xp": 60,
			"no_hazard_rain": true, "phase_thresholds": [0.65, 0.3], "phase_lock": true, "frenzy_cooldown": 0.7,
			"attack_anims": ["Weapon"],
			"special_anims": {"frost_breath": ["Breath"], "tail_sweep": ["Tail"], "wing_gust": ["Wing"]},
			"abilities": [
				{"id": "frost_breath", "cooldown": 8.0, "first": 3.0, "range": 9.0, "arc": 32.0, "windup": 1.1,
					"freeze": 1.5, "damage": 1.2, "fast_cooldown": 4.5},
				{"id": "tail_sweep", "cooldown": 5.0, "first": 4.0, "radius": 4.8, "arc": 115.0, "windup": 0.7, "damage": 1.0},
				{"id": "sky_fall", "phase": 2, "until": 2, "cooldown": 26.0, "first": 0.5, "flight": 10.0, "height": 6.0,
					"every": 1.0, "radius": 1.3, "land_radius": 5.0, "stun": 3.0, "damage": 1.0, "max_pillars": 8},
				{"id": "eternal_winter", "phase": 3, "first": 0.3, "runes": 4, "ring": 6.0, "switch": 6.0, "rune_radius": 1.8,
					"build_move": 0.07, "build_still": 0.22, "melt": 0.7, "freeze": 1.5},
				{"id": "wing_gust", "phase": 3, "cooldown": 7.0, "first": 2.0, "range": 10.0, "push": 11.0, "windup": 0.6},
			]},
'''
s = s[:start] + NEW + s[end:]
open(P, "w", encoding="utf-8", newline="\n").write(s)
print("ok")
