# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/dungeon/abilities/enemy_abilities.gd", [
    ('''	"leap": preload("res://scenes/dungeon/abilities/leap_ability.gd"),
''', '''	"leap": preload("res://scenes/dungeon/abilities/leap_ability.gd"),
	"lunge": preload("res://scenes/dungeon/abilities/lunge_ability.gd"),
'''),
])
patch("scenes/dungeon/abilities/lunge_ability.gd", [
    ('''	_show_glow(windup)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)''', '''	_show_glow(windup)
	# Замах можуть збити сильним ударом — тоді смуга сама зникне.
	enemy.get_tree().create_timer(windup + 0.3, false).timeout.connect(_clear_line)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)'''),
])
patch("scenes/dungeon/enemy_3d.gd", [
    ('''var definition: Dictionary = {}
''', '''var definition: Dictionary = {}
## Зграя ("pack" в описі): поруч щонайменше count таких самих (та сама
## назва) у радіусі radius — б'є швидше в attack_speed разів. Під
## ногами тоді жевріє червоне коло: видно, що зграю краще розбити.
var _pack_factor := 1.0
var _pack_left := 0.0
var _pack_marker: MeshInstance3D
'''),
    ('''	_tick_status(delta)
''', '''	_tick_status(delta)
	if definition.has("pack"):
		_pack_left -= delta
		if _pack_left <= 0.0:
			_pack_left = 0.5
			_update_pack()
'''),
    ('''func _pace() -> float:
	if _frozen_left > 0.0:
		return 0.0
	return _slow_factor if _slow_left > 0.0 else 1.0''', '''func _pace() -> float:
	if _frozen_left > 0.0:
		return 0.0
	return (_slow_factor if _slow_left > 0.0 else 1.0) * _pack_factor

## Скільки поруч таких самих ворогів — і чи діє бонус зграї.
func _update_pack() -> void:
	var pack: Dictionary = definition.pack
	var radius := float(pack.get("radius", 7.0))
	var needed := int(pack.get("count", 2))
	var name := String(definition.get("name", ""))
	var near := 0
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or other == self or not other.is_alive():
			continue
		if String(other.definition.get("name", "")) != name:
			continue
		if other.global_position.distance_to(global_position) <= radius:
			near += 1
			if near >= needed:
				break
	var active := near >= needed
	_pack_factor = float(pack.get("attack_speed", 1.15)) if active else 1.0
	if active and _pack_marker == null:
		_pack_marker = CombatVfx.make_ground_marker(Color(1.0, 0.15, 0.1, 0.45), 0.55 + target_height * 0.15)
		_pack_marker.set_instance_shader_parameter(&"progress", 1.0)
		add_child(_pack_marker)
		_pack_marker.position = Vector3(0, 0.05, 0)
	if _pack_marker != null:
		_pack_marker.visible = active'''),
])
patch("scenes/dungeon/dungeon_levels.gd", [
    ('''				{"name": "Орк", "model": "res://assets/models/monsters/Orc Enemy.glb", "kind": "melee", "hp": 30.0, "damage": 8.0, "speed": 2.8, "height": 1.7, "xp": 3},''',
     '''				# Орк-рубака (модель гравця): швидкий, ходить парами. Ривок-замах
				# (lunge) — з 4 м присідає, тесак червоніє, стрибок з ударом; зграя
				# (pack) — поруч ще двоє рубак, і кожен б'є на 15% швидше.
				# Скелет і анімації — D:/RuneHorde_work/scripts/blender/prep_rodin_mob.py.
				{"name": "Орк-рубака", "model": "res://assets/models/monsters/orc_cleaver.glb", "kind": "melee",
					"hp": 26.0, "damage": 7.0, "speed": 3.4, "height": 1.85, "xp": 3, "group": 2,
					"attack_anims": ["Weapon"],
					"special_anims": {"lunge": ["Windup"]},
					"abilities": [{"id": "lunge", "cooldown": 4.0, "first": 1.0, "trigger": 4.0, "windup": 0.5, "hop": 0.45, "radius": 1.6, "damage": 1.4}],
					"pack": {"radius": 7.0, "count": 2, "attack_speed": 1.15}},'''),
])
print("patched")
