# -*- coding: utf-8 -*-
"""Ворожі попередження -> арт гравця (CombatVfx.make_telegraph / make_line_telegraph),
тріщини після удару (impact_decal), смуги під променями боса."""
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/dungeon/enemy_3d.gd", [
    ('''		_show_telegraph(SLAM_RADIUS, PI, SLAM_COLOR)
	else:
		_show_telegraph(_melee_reach(), deg_to_rad(55.0), TELEGRAPH_COLOR)''',
     '''		_show_telegraph(SLAM_RADIUS, PI, SLAM_COLOR, true)
	else:
		_show_telegraph(_melee_reach(), deg_to_rad(55.0), TELEGRAPH_COLOR)'''),
    ('''	_show_telegraph(EXPLODE_RADIUS, PI, EXPLODE_COLOR)''',
     '''	_show_telegraph(EXPLODE_RADIUS, PI, EXPLODE_COLOR, true)'''),
    ('''	_show_telegraph(radius, PI, color)
''', '''	_show_telegraph(radius, PI, color, true)
'''),
    ('''func _show_telegraph(radius: float, half_arc: float, color: Color) -> void:
	_hide_telegraph()
	_telegraph = CombatVfx.make_ground_marker(color, radius, half_arc)''',
     '''## Попередження удару на підлозі (арт гравця, див. CombatVfx.make_telegraph).
## embers — іскри з краю: лише для важких ударів, звичайних в орді багато.
func _show_telegraph(radius: float, half_arc: float, color: Color, embers: bool = false) -> void:
	_hide_telegraph()
	_telegraph = CombatVfx.make_telegraph(color, radius, half_arc, embers)'''),
    ('''	_telegraph = CombatVfx.make_line_marker(CHARGE_COLOR, length, 1.8)''',
     '''	_telegraph = CombatVfx.make_line_telegraph(CHARGE_COLOR, length, 1.8, "chevrons", true)'''),
    ('''		CombatVfx.shockwave(get_parent(), global_position, SLAM_RADIUS, SLAM_COLOR, 0.35)
''', '''		CombatVfx.shockwave(get_parent(), global_position, SLAM_RADIUS, SLAM_COLOR, 0.35)
		CombatVfx.impact_decal(get_parent(), global_position, SLAM_RADIUS * 0.8, SLAM_COLOR)
'''),
    ('''	CombatVfx.shockwave(parent, global_position, EXPLODE_RADIUS, EXPLODE_COLOR, 0.35)
''', '''	CombatVfx.shockwave(parent, global_position, EXPLODE_RADIUS, EXPLODE_COLOR, 0.35)
	CombatVfx.impact_decal(parent, global_position, EXPLODE_RADIUS * 0.8, EXPLODE_COLOR)
'''),
])

patch("scenes/dungeon/abilities/leap_ability.gd", [
    ('''	_marker = CombatVfx.make_ground_marker(COLOR, radius)''',
     '''	_marker = CombatVfx.make_telegraph(COLOR, radius, PI, true)'''),
    ('''	CombatVfx.shockwave(world(), _target, radius, COLOR, 0.35)
''', '''	CombatVfx.shockwave(world(), _target, radius, COLOR, 0.35)
	CombatVfx.impact_decal(world(), _target, radius * 0.8, COLOR)
'''),
])

patch("scenes/dungeon/abilities/meteor_storm_ability.gd", [
    ('''	var marker := CombatVfx.make_ground_marker(Color(COLOR, 0.85), radius)''',
     '''	var marker := CombatVfx.make_telegraph(Color(COLOR, 0.9), radius, PI, true)'''),
    ('''		CombatVfx.shockwave(world(), spot, radius, COLOR, 0.3)
''', '''		CombatVfx.shockwave(world(), spot, radius, COLOR, 0.3)
		CombatVfx.impact_decal(world(), spot, radius * 0.75, COLOR, 0.3)
'''),
])

patch("scenes/dungeon/abilities/burrow_ability.gd", [
    ('''	_marker = CombatVfx.make_ground_marker(Color(DUST, 0.9), RADIUS)''',
     '''	_marker = CombatVfx.make_telegraph(Color(DUST, 0.9), RADIUS, PI, true)'''),
    ('''	CombatVfx.shockwave(world(), _target, RADIUS, DUST, 0.35)
''', '''	CombatVfx.shockwave(world(), _target, RADIUS, DUST, 0.35)
	CombatVfx.impact_decal(world(), _target, RADIUS * 0.8, DUST)
'''),
])

patch("scenes/dungeon/hazards/lob_shell.gd", [
    ('''	_marker = CombatVfx.make_ground_marker(Color(_color, 0.85), _radius)''',
     '''	_marker = CombatVfx.make_telegraph(Color(_color, 0.9), _radius, PI, true)'''),
    ('''	CombatVfx.shockwave(world, _to, _radius, _color, 0.35)
''', '''	CombatVfx.shockwave(world, _to, _radius, _color, 0.35)
	CombatVfx.impact_decal(world, _to, _radius * 0.8, _color, 0.3)
'''),
])

patch("scenes/dungeon/boss_phases.gd", [
    ('''	var marker := CombatVfx.make_ground_marker(Color(color, 0.85), HAZARD_RADIUS)''',
     '''	var marker := CombatVfx.make_telegraph(Color(color, 0.9), HAZARD_RADIUS, PI, true)'''),
    ('''		CombatVfx.shockwave(parent, center, HAZARD_RADIUS, color, 0.3)
''', '''		CombatVfx.shockwave(parent, center, HAZARD_RADIUS, color, 0.3)
		CombatVfx.impact_decal(parent, center, HAZARD_RADIUS * 0.8, color, 0.3)
'''),
])

patch("scenes/dungeon/elite_affixes.gd", [
    ('''	var marker := CombatVfx.make_ground_marker(color, BLAST_RADIUS)''',
     '''	var marker := CombatVfx.make_telegraph(color, BLAST_RADIUS, PI, true)'''),
    ('''		CombatVfx.shockwave(parent, center, BLAST_RADIUS, color, 0.35)
''', '''		CombatVfx.shockwave(parent, center, BLAST_RADIUS, color, 0.35)
		CombatVfx.impact_decal(parent, center, BLAST_RADIUS * 0.8, color)
'''),
])

# Промені боса: під кожним — смуга з арту на підлозі (видно, куди
# зараз повернеться промінь), спершу заливається — попередження.
patch("scenes/dungeon/hazards/hazard_beams.gd", [
    ('''var _beams: Array[MeshInstance3D] = []
''', '''var _beams: Array[MeshInstance3D] = []
var _strips: Array[MeshInstance3D] = []
'''),
    ('''		add_child(beam)
		_beams.append(beam)
	_place()''', '''		add_child(beam)
		_beams.append(beam)
		var strip := CombatVfx.make_line_telegraph(_color, _length, _width * 2.2, "flames")
		add_child(strip)
		_strips.append(strip)
	_place()'''),
    ('''## Промені йдуть від боса на висоті грудей; поки попередження — тонкі.
func _place() -> void:
	global_position = _owner.global_position + Vector3(0, 1.0, 0)
	var thickness := _width if _age >= WARN else 0.12
	for i in _count:''', '''## Промені йдуть від боса на висоті грудей; поки попередження — тонкі.
## Під кожним на підлозі — вогняна смуга: під час попередження вона
## заливається від боса до кінця, далі горить, поки б'є промінь.
func _place() -> void:
	global_position = _owner.global_position + Vector3(0, 1.0, 0)
	var thickness := _width if _age >= WARN else 0.12
	for i in _count:
		var strip := _strips[i]
		strip.rotation.y = _beam_angle(i) + PI
		strip.position = Vector3.FORWARD.rotated(Vector3.UP, _beam_angle(i)) * _length * 0.5 + Vector3(0, -0.94, 0)
		strip.set_instance_shader_parameter(&"progress", minf(_age / WARN, 1.0))'''),
])

# Прогрів: шейдер попереджень і частинки з арту — під екраном завантаження.
patch("scenes/dungeon/dungeon.gd", [
    ('''	var line := CombatVfx.make_line_marker(Color(1.0, 0.3, 0.2, 0.85), 2.0, 1.0)
	holder.add_child(line)
	line.global_position = center - Vector3(0, 0.9, 0)
''', '''	var line := CombatVfx.make_line_marker(Color(1.0, 0.3, 0.2, 0.85), 2.0, 1.0)
	holder.add_child(line)
	line.global_position = center - Vector3(0, 0.9, 0)
	var telegraph := CombatVfx.make_telegraph(Color(1.0, 0.22, 0.15, 0.85), 1.2, PI, true)
	holder.add_child(telegraph)
	telegraph.global_position = center - Vector3(0, 0.9, 0)
	var strip := CombatVfx.make_line_telegraph(Color(1.0, 0.3, 0.2, 0.85), 2.0, 1.0)
	holder.add_child(strip)
	strip.global_position = center - Vector3(0, 0.9, 0)
	CombatVfx.impact_decal(holder, center - Vector3(0, 0.9, 0), 1.0, Color(1.0, 0.45, 0.1))
'''),
])
print("patched")
