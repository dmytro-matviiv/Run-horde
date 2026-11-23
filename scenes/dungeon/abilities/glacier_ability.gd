extends EnemyAbility

## ЛЬОДОВИК (Ярл Вічної Зими). Позаду героя виростає крижана стіна на
## всю залу — з одним проходом (gap метрів) — і повзе крізь залу (speed).
## Спершу смуга на підлозі показує, де стіна і де прохід (warn). Стіна
## зачепила — шкода й відкидає далі за її ходом. Шукай прохід і
## проскакуй у нього, поки стіна не наїхала.
## Налаштування: width, gap, back (м позаду героя), travel, speed, warn, damage.

const COLOR := Color(0.6, 0.85, 1.0, 0.85)
const THICK := 0.8
const HEIGHT := 2.4

var _dir := Vector3.FORWARD
var _side := Vector3.RIGHT
var _origin := Vector3.ZERO
var _gap_at := 0.0
var _moved := 0.0
var _warn_left := 0.0
var _moving := false
var _hit := false
var _walls: Array = []
var _lines: Array = []

func _init() -> void:
	id = "glacier"
	cooldown = 18.0

func try_use(_distance: float) -> bool:
	if _moving or _warn_left > 0.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.8)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_clear()
	var yaw := float(randi() % 4) * PI * 0.5
	_dir = Vector3(sin(yaw), 0.0, cos(yaw))
	_side = Vector3(_dir.z, 0.0, -_dir.x)
	var hero_flat := Vector3(hero.global_position.x, DungeonBuilder.FLOOR_TOP, hero.global_position.z)
	_origin = hero_flat - _dir * float(config.get("back", 6.0))
	_gap_at = randf_range(-4.0, 4.0)
	_moved = 0.0
	_hit = false
	var width := float(config.get("width", 24.0))
	var gap := float(config.get("gap", 2.6))
	# Дві половини стіни (ліворуч і праворуч від проходу) — два бруски.
	for k in 2:
		var sign := -1.0 if k == 0 else 1.0
		var inner := _gap_at + sign * gap * 0.5
		var outer := sign * width * 0.5
		var length := absf(outer - inner)
		var middle := (inner + outer) * 0.5
		var line := CombatVfx.make_line_telegraph(COLOR, length, THICK + 0.4, "chevrons", false)
		# (смуга лишається: так видно, де прохід, ще до того, як стіна виросте)
		world().add_child(line)
		line.global_position = _origin + _side * middle + Vector3.UP * 0.05
		line.rotation.y = atan2(_side.x, _side.z)
		_lines.append(line)
		# Стіна — ряд гострих крижаних уламків (шейдер криги) з морозним
		# туманом біля основи. Довжина — уздовж _side.
		var wall := BossFx.ice_wall(length, HEIGHT)
		world().add_child(wall)
		wall.global_position = _origin + _side * middle + Vector3.UP * (-HEIGHT)
		wall.rotation.y = atan2(_side.x, _side.z)
		_walls.append(wall)
	_warn_left = float(config.get("warn", 1.2))

func tick(delta: float) -> void:
	super.tick(delta)
	if _warn_left > 0.0:
		_warn_left -= delta
		var warn := float(config.get("warn", 1.2))
		var t := clampf(1.0 - _warn_left / warn, 0.0, 1.0)
		for line in _lines:
			if is_instance_valid(line):
				CombatVfx.set_param(line, &"progress", t)
		# Стіна виростає з підлоги.
		for wall: Node3D in _walls:
			wall.global_position.y = DungeonBuilder.FLOOR_TOP - HEIGHT * (1.0 - t)
		if _warn_left <= 0.0:
			for line in _lines:
				if is_instance_valid(line):
					line.queue_free()
			_lines.clear()
			_moving = true
		return
	if not _moving:
		return
	var step := float(config.get("speed", 3.2)) * delta
	_moved += step
	for wall: Node3D in _walls:
		wall.global_position += _dir * step
	var hero := player()
	if hero != null and is_instance_valid(hero) and not _hit:
		var offset := hero.global_position - (_origin + _dir * _moved)
		offset.y = 0.0
		var along := offset.dot(_dir)
		var across := offset.dot(_side)
		var gap := float(config.get("gap", 2.6))
		if absf(along) <= THICK * 0.5 + 0.35 and absf(across - _gap_at) > gap * 0.5 - 0.3 \
				and absf(across) <= float(config.get("width", 24.0)) * 0.5:
			if hero.take_damage(damage()):
				_hit = true
				CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, true)
				if hero.has_method("knock_down"):
					hero.knock_down(_dir * 9.0, 0.45)
	if _moved >= float(config.get("travel", 16.0)):
		_clear()

func on_death() -> void:
	_clear()

func _clear() -> void:
	_moving = false
	_warn_left = 0.0
	for line in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()
	for wall: Node3D in _walls:
		if is_instance_valid(wall):
			CombatVfx.smoke_puff(world(), wall.global_position, Color(0.85, 0.95, 1.0), 1.6)
			wall.queue_free()
	_walls.clear()
