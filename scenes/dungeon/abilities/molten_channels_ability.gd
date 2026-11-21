extends EnemyAbility

## РОЗПЛАВЛЕНІ КАНАЛИ (Володар Горна). Бос гупає молотом — і підлогою
## біжать жолоби: count смуг (паралельних, через героя й обабіч нього)
## по черзі спершу світяться попередженням (warn с), потім заливаються
## металом і burn секунд печуть. Безпечні смуги між ними весь час
## зміщуються — треба переходити з однієї в іншу.
## Налаштування: count, gap (м між смугами), width, length, warn, burn,
## step (с між смугами), damage (частка за тік).

const COLOR := Color(1.0, 0.5, 0.1, 0.9)
const TICK := 0.4

var _strips: Array = []
var _tick_left := 0.0

func _init() -> void:
	id = "molten_channels"
	cooldown = 11.0

func try_use(_distance: float) -> bool:
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.7)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var count := int(config.get("count", 4))
	var gap := float(config.get("gap", 2.4))
	var width := float(config.get("width", 1.6))
	var length := float(config.get("length", 16.0))
	var step := float(config.get("step", 0.55))
	# Смуги — поперек лінії "бос — герой", щоб тікати можна було лише
	# крок у крок за хвилею.
	var along := hero.global_position - enemy.global_position
	along.y = 0.0
	along = along.normalized() if along.length() > 0.1 else Vector3.FORWARD
	if enemy.phases != null and enemy.phases.phase >= 3:
		along = along.rotated(Vector3.UP, PI * 0.5)
	var across := Vector3(-along.z, 0.0, along.x)
	var start := hero.global_position - along * gap * (count - 1) * 0.5
	var now := Time.get_ticks_msec() / 1000.0
	for i in count:
		var center := start + along * gap * i
		center.y = DungeonBuilder.FLOOR_TOP + 0.05
		var line := CombatVfx.make_line_telegraph(COLOR, length, width, "chevrons", true)
		world().add_child(line)
		line.global_position = center
		line.rotation.y = atan2(across.x, across.z)
		_strips.append({"center": center, "along": along, "width": width, "line": line,
			"on": now + float(config.get("warn", 1.0)) + i * step,
			"off": now + float(config.get("warn", 1.0)) + i * step + float(config.get("burn", 2.0)), "lit": false})

func tick(delta: float) -> void:
	super.tick(delta)
	if _strips.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	_tick_left -= delta
	var hero := player()
	var burned := false
	for strip: Dictionary in _strips.duplicate():
		var line: MeshInstance3D = strip.line
		if now >= float(strip.off):
			if is_instance_valid(line):
				line.queue_free()
			_strips.erase(strip)
			continue
		if now < float(strip.on):
			if is_instance_valid(line):
				CombatVfx.set_param(line, &"progress", clampf(1.0 - (float(strip.on) - now) / 1.0, 0.0, 1.0))
			continue
		if not strip.lit:
			strip.lit = true
			CombatVfx.shockwave(world(), strip.center, 1.2, COLOR, 0.3)
			if is_instance_valid(line):
				CombatVfx.set_param(line, &"progress", 1.0)
		if hero != null and is_instance_valid(hero) and _tick_left <= 0.0:
			var offset: Vector3 = hero.global_position - strip.center
			if absf(offset.dot(strip.along)) <= float(strip.width) * 0.5:
				burned = true
	if burned:
		_tick_left = TICK
		hero.take_damage(damage() * float(config.get("tick", 0.3)))

func on_death() -> void:
	for strip: Dictionary in _strips:
		if is_instance_valid(strip.line):
			strip.line.queue_free()
	_strips.clear()
