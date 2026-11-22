extends EnemyAbility

## СТІНИ ПОРОЖНЕЧІ (Володар Рун). Через усю залу хрестом проростають
## стіни з чорних кристалів (тверді, невразливі): зала ділиться на чотири
## частини на time секунд. Герой застряє в одній — разом із Володарем або
## без нього. Попередження — світні смуги перед тим, як стіни виростуть.
## Налаштування: length (м плеча хреста), step (м між кристалами), time, warn.

const COLOR := Color(0.6, 0.3, 1.0, 0.85)
const WALL_SCENE := "res://scenes/dungeon/hazards/void_crystal.tscn"

var _lines: Array = []
var _warn_left := 0.0
var _center := Vector3.ZERO
var _yaw := 0.0

func _init() -> void:
	id = "void_walls"
	cooldown = 18.0

func try_use(_distance: float) -> bool:
	if _warn_left > 0.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.7)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	_center = enemy.global_position
	_center.y = DungeonBuilder.FLOOR_TOP
	_yaw = randf() * PI
	var length := float(config.get("length", 10.0))
	for k in 2:
		var direction := Vector3(cos(_yaw + k * PI * 0.5), 0.0, sin(_yaw + k * PI * 0.5))
		var line := CombatVfx.make_line_telegraph(COLOR, length * 2.0, 0.8, "chevrons", true)
		world().add_child(line)
		line.global_position = _center + Vector3.UP * 0.05
		line.rotation.y = atan2(direction.x, direction.z)
		_lines.append(line)
	_warn_left = float(config.get("warn", 1.2))

func tick(delta: float) -> void:
	super.tick(delta)
	if _warn_left <= 0.0:
		return
	_warn_left -= delta
	for line in _lines:
		if is_instance_valid(line):
			CombatVfx.set_param(line, &"progress", clampf(1.0 - _warn_left / float(config.get("warn", 1.2)), 0.0, 1.0))
	if _warn_left <= 0.0:
		_raise()

func _raise() -> void:
	for line in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()
	var length := float(config.get("length", 10.0))
	var step := float(config.get("step", 0.9))
	var time := float(config.get("time", 6.0))
	var hero := player()
	for k in 2:
		var direction := Vector3(cos(_yaw + k * PI * 0.5), 0.0, sin(_yaw + k * PI * 0.5))
		var d := -length
		while d <= length:
			var spot := _center + direction * d
			d += step
			# Біля самого Володаря не ростуть (він стоїть у перехресті).
			if absf(d - step) < 1.2:
				continue
			# Не під героєм: стіна не замурує його всередині.
			if hero != null and is_instance_valid(hero) and Vector2(spot.x - hero.global_position.x, spot.z - hero.global_position.z).length() < 0.8:
				continue
			enemy.spawn_requested.emit(spot, {
				"name": "Кристал порожнечі", "model": WALL_SCENE, "kind": "totem",
				"hp": 1.0e6, "damage": 0.0, "speed": 0.0, "height": 1.8, "xp": 0, "no_elite": true,
				"invulnerable": true, "blocker": Vector3(step + 0.05, 2.2, 0.6), "face_yaw": atan2(direction.x, direction.z),
				"lifetime": time,
			}, null)
	CombatVfx.shockwave(world(), _center, length, COLOR, 0.5)

func on_death() -> void:
	for line in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()
	_warn_left = 0.0
