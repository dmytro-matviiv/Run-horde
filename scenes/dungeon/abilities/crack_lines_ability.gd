extends EnemyAbility

## УДАР НАДГРОБКОМ (Хранитель Склепів): замахується молотом над головою —
## на підлозі від нього розходяться віялом count смуг (до героя й обабіч),
## за мить удар об землю, і по смугах біжать тріщини. Хто на смузі —
## отримує; перекат крізь смугу рятує (невразливість перекату).
##
## Налаштування: count, spread (градуси між смугами), length, width,
## windup (с), damage (частка удару боса).

const COLOR := Color(1.0, 0.4, 0.12, 0.9)
const CRACK_COLOR := Color(1.0, 0.5, 0.2)

var _origin := Vector3.ZERO
var _directions: Array[Vector3] = []
var _lines: Array[MeshInstance3D] = []

func _init() -> void:
	id = "crack_lines"
	cooldown = 7.0

func try_use(distance: float) -> bool:
	if distance > float(config.get("length", 10.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	var windup := float(config.get("windup", 1.1))
	var length := float(config.get("length", 10.0))
	var width := float(config.get("width", 1.3))
	_origin = enemy.global_position
	var aim := player().global_position - _origin
	aim.y = 0.0
	aim = aim.normalized() if aim.length() > 0.1 else enemy.facing_vector()
	enemy.face_point(_origin + aim)
	_directions.clear()
	_clear_lines()
	var count := int(config.get("count", 3))
	var spread := deg_to_rad(float(config.get("spread", 32.0)))
	for i in count:
		var direction := aim.rotated(Vector3.UP, (i - (count - 1) * 0.5) * spread)
		_directions.append(direction)
		var line := CombatVfx.make_line_telegraph(COLOR, length, width, "flames", true)
		world().add_child(line)
		line.global_position = Vector3(_origin.x, DungeonBuilder.FLOOR_TOP + 0.05, _origin.z) + direction * length * 0.5
		line.rotation.y = atan2(direction.x, direction.z)
		var tween := line.create_tween()
		tween.tween_method(func(value: float) -> void:
			if is_instance_valid(line):
				line.set_instance_shader_parameter(&"progress", value), 0.0, 1.0, windup)
		_lines.append(line)
	# Замах можуть збити — тоді смуги зникнуть самі.
	enemy.get_tree().create_timer(windup + 0.3, false).timeout.connect(_clear_lines)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	_clear_lines()
	var length := float(config.get("length", 10.0))
	var width := float(config.get("width", 1.3))
	var parent := world()
	CombatVfx.impact_decal(parent, _origin + enemy.facing_vector() * 1.2, 1.6, CRACK_COLOR, 0.6)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.2)
	AudioManager.play(&"explosion", 0.1)
	var hero := player()
	var hit := false
	for direction in _directions:
		# Тріщини біжать від молота вздовж смуги.
		var steps := int(length / 1.6)
		for k in steps:
			var spot := _origin + direction * (1.2 + k * 1.6)
			parent.get_tree().create_timer(0.04 * k, false).timeout.connect(
				CombatVfx.impact_decal.bind(parent, spot, 0.75, CRACK_COLOR, 0.5))
		if hit or hero == null or not is_instance_valid(hero):
			continue
		var offset := hero.global_position - _origin
		offset.y = 0.0
		var along := offset.dot(direction)
		if along > 0.0 and along < length and (offset - direction * along).length() <= width * 0.5 + 0.3:
			hit = true
			hero.take_damage(damage())

func on_death() -> void:
	_clear_lines()

func _clear_lines() -> void:
	for line in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()
