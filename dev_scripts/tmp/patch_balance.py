# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/world/player_3d.gd", [
    ("const RUN_SPEED := 5.4", "const RUN_SPEED := 4.6"),
])

patch("scenes/dungeon/dungeon.gd", [
    ('''var _hp_scale := 1.0
''', '''var _hp_scale := 1.0
## Звичайні вороги (не боси) міцніші: з 1-2 ударів падати не мають.
const MOB_HP_FACTOR := 1.7
'''),
    ('''		enemy.configure(definition, _hp_scale, _damage_scale)''',
     '''		enemy.configure(definition, _hp_scale * MOB_HP_FACTOR, _damage_scale)'''),
])

patch("scenes/dungeon/abilities/lob_ability.gd", [
    ('''			marker.set_instance_shader_parameter(&"progress", value), 0.0, 0.4, WINDUP)
		enemy.get_tree().create_timer(WINDUP + 0.4, false).timeout.connect(_clear_aim)
		enemy.begin_special(id, WINDUP, Color(_color(), 0.0), 0.1)
	else:
		enemy.begin_special(id, WINDUP, Color(_color(), 0.85), 1.2)''', '''			marker.set_instance_shader_parameter(&"progress", value), 0.0, 0.4, _windup())
		enemy.get_tree().create_timer(_windup() + 0.4, false).timeout.connect(_clear_aim)
		enemy.begin_special(id, _windup(), Color(_color(), 0.0), 0.1)
	else:
		enemy.begin_special(id, _windup(), Color(_color(), 0.85), 1.2)'''),
    ('''func _clear_aim() -> void:''', '''## Замах кидка ("windup" в описі, інакше WINDUP).
func _windup() -> float:
	return float(config.get("windup", WINDUP))

func _clear_aim() -> void:'''),
])

# Стрибок з ударом приголомшує героя ("stun" в описі, с).
patch("scenes/dungeon/abilities/lunge_ability.gd", [
    ('''		hero.take_damage(damage())''', '''		if hero.take_damage(damage()) and config.has("stun") and hero.has_method("stun"):
			hero.stun(float(config.stun))'''),
])
patch("scenes/dungeon/abilities/leap_ability.gd", [
    ('''		player().take_damage(damage() * 1.4)''', '''		if player().take_damage(damage() * 1.4) and player().has_method("stun"):
			player().stun(float(config.get("stun", 0.5)))'''),
])

patch("scenes/dungeon/dungeon_levels.gd", [
    ('''"trigger": 4.0, "windup": 0.5, "hop": 0.55, "radius": 1.6, "damage": 1.4}''',
     '''"trigger": 4.0, "windup": 0.35, "hop": 0.5, "radius": 1.6, "damage": 1.4, "stun": 0.5}'''),
    ('''{"id": "grasp", "cooldown": 8.0, "first": 3.0, "count": 2, "radius": 1.0, "tell": 1.0, "hold": 1.0, "damage": 0.5}''',
     '''{"id": "grasp", "cooldown": 8.0, "first": 3.0, "count": 2, "radius": 1.0, "tell": 0.55, "hold": 1.0, "damage": 0.5}'''),
    ('''"aim_first": true, "arc": 1.4,''', '''"aim_first": true, "arc": 1.4, "windup": 0.4,'''),
])
print("patched")
