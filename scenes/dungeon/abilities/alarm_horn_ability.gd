extends EnemyAbility

## ВАРТОВИЙ РІГ (Зимна Цитадель). Побачив героя ближче за range — ріг
## набирає повітря (windup — довгий: встигни розбити) і сурмить. Усі
## вороги в радіусі call метрів прокидаються й біжать на героя, на time
## секунд швидші (haste). Розбий ріг першим — інакше збіжиться вся зала.
## Налаштування: range, windup, call, time, haste.

const COLOR := Color(0.55, 0.8, 1.0)

func _init() -> void:
	id = "alarm_horn"
	cooldown = 16.0

var _blow_left := 0.0
var _ring: MeshInstance3D

## Ріг — тотем: звичайних замахів не має, тож набирає повітря сам.
func tick(delta: float) -> void:
	super.tick(delta)
	var windup := float(config.get("windup", 1.8))
	if _blow_left > 0.0:
		_blow_left -= delta
		if _ring != null and is_instance_valid(_ring):
			CombatVfx.set_param(_ring, &"progress", clampf(1.0 - _blow_left / windup, 0.0, 1.0))
		enemy._model.scale = Vector3.ONE * (1.0 + 0.06 * sin(_blow_left * 30.0))
		if _blow_left <= 0.0:
			enemy._model.scale = Vector3.ONE
			_clear_ring()
			resolve()
		return
	if not ready_to_use():
		return
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	# Тотем не оновлює погляд сам (стоїть) — дивимось променем щоразу.
	if hero.global_position.distance_to(enemy.global_position) > float(config.get("range", 10.0)) or not enemy._has_line_of_sight():
		return
	start_cooldown()
	_blow_left = windup
	_ring = CombatVfx.make_telegraph(Color(COLOR, 0.8), 1.6, PI, false)
	enemy.add_child(_ring)
	_ring.position = Vector3.UP * 0.05

func _clear_ring() -> void:
	if _ring != null and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null

func on_death() -> void:
	_blow_left = 0.0
	_clear_ring()

func resolve() -> void:
	var reach := float(config.get("call", 24.0))
	var time := float(config.get("time", 10.0))
	var haste := float(config.get("haste", 1.35))
	CombatVfx.shockwave(world(), enemy.global_position, 6.0, COLOR, 0.6)
	CombatVfx.shockwave(world(), enemy.global_position, 10.0, Color(COLOR, 0.5), 0.9)
	var called := 0
	for node in enemy.get_parent().get_children():
		var other := node as Enemy3D
		if other == null or other == enemy or not other.is_alive() or other.stationary:
			continue
		if other.global_position.distance_to(enemy.global_position) > reach:
			continue
		called += 1
		other.alert()
		other.hunting = true
		if other.has_meta("horn_speed"):
			continue
		other.set_meta("horn_speed", other.move_speed)
		other.move_speed *= haste
		CombatVfx.impact(world(), other.global_position + Vector3.UP * other.target_height, COLOR, false)
		var target := other
		enemy.get_tree().create_timer(time).timeout.connect(func() -> void:
			if is_instance_valid(target) and target.has_meta("horn_speed"):
				target.move_speed = float(target.get_meta("horn_speed"))
				target.remove_meta("horn_speed"))
	enemy.set_meta("horn_called", called)
