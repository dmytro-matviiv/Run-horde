# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/dungeon/dungeon_builder.gd", [
    ('''static func portal_wall(map_rows: Array, start: Vector2i) -> Dictionary:
	const MAX_STEPS := 14
	var best := {}
	var best_score := INF
	var directions := {Vector2i(0, -1): 0.0, Vector2i(-1, 0): 3.0, Vector2i(1, 0): 3.0, Vector2i(0, 1): 8.0}
	for dir: Vector2i in directions:''', '''## skip — "inward" стіни, яку брати не можна (саркофаги боса не стають на
## стіну, де потім відкриється портал).
static func portal_wall(map_rows: Array, start: Vector2i, skip: Vector3 = Vector3.ZERO) -> Dictionary:
	const MAX_STEPS := 14
	var best := {}
	var best_score := INF
	var directions := {Vector2i(0, -1): 0.0, Vector2i(-1, 0): 3.0, Vector2i(1, 0): 3.0, Vector2i(0, 1): 8.0}
	for dir: Vector2i in directions:
		if skip != Vector3.ZERO and Vector3(-dir.x, 0.0, -dir.y).is_equal_approx(skip):
			continue'''),
])

patch("scenes/dungeon/enemy_3d.gd", [
    ('''	var blocked := _shield_blocks()''', '''	# Бос із "phase_lock": удар не перескакує фазу — здоров'я зупиняється на
	# порозі наступної фази, решта шкоди згорає.
	if phases != null and definition.get("phase_lock", false):
		var thresholds: Array = definition.get("phase_thresholds", BossPhases.THRESHOLDS)
		if phases.phase - 1 < thresholds.size():
			var floor_hp := max_hp * float(thresholds[phases.phase - 1])
			amount = clampf(current_hp - floor_hp, 0.0, amount)
	var blocked := _shield_blocks()'''),
    ('''static func _make_stun_stars() -> Node3D:''', '''static func make_stun_stars() -> Node3D:
	return _make_stun_stars()

static func _make_stun_stars() -> Node3D:'''),
])

patch("scenes/world/player_3d.gd", [
    ('''var _knock_left := 0.0
''', '''var _knock_left := 0.0
## Оглушення (бос): зірочки над головою, ні кроку, ні удару, ні перекату.
var _stun_stars: Node3D
'''),
    ('''## Воскресіння за відео (данж)''', '''## Оглушити на seconds секунд (або доки не зніме end_stun). Перекат не
## рятує — це не удар, а сила боса.
func stun(seconds: float) -> void:
	if _dead:
		return
	_roll_left = 0.0
	_knock_left = maxf(_knock_left, seconds)
	_knock_velocity = Vector3.ZERO
	_attack_step = -1
	_abort_attacks()
	if _stun_stars == null:
		_stun_stars = Enemy3D.make_stun_stars()
		add_child(_stun_stars)
		_stun_stars.position = Vector3(0, 2.1, 0)
		var spin := _stun_stars.create_tween().set_loops()
		spin.tween_property(_stun_stars, "rotation:y", TAU, 0.9).from(0.0)
	_stun_stars.visible = true

func end_stun() -> void:
	_knock_left = 0.0
	if _stun_stars != null:
		_stun_stars.visible = false

## Воскресіння за відео (данж)'''),
    ('''	if _knock_left > 0.0:
		_knock_left -= delta''', '''	if _knock_left > 0.0:
		_knock_left -= delta
		if _knock_left <= 0.0 and _stun_stars != null:
			_stun_stars.visible = false'''),
])
print("patched")
