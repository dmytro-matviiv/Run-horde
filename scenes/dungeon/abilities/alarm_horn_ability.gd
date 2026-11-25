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
var _label: Label3D
var _hint: Label3D

## Ріг — тотем: звичайних замахів не має, тож набирає повітря сам.
func tick(delta: float) -> void:
	super.tick(delta)
	var windup := float(config.get("windup", 1.8))
	if _hint == null:
		_hint = _make_label("Вартовий ріг — кличе всю залу", 46)
		enemy.add_child(_hint)
		_hint.position = Vector3.UP * (enemy.target_height + 0.5)
	if _blow_left > 0.0:
		_blow_left -= delta
		var t := clampf(1.0 - _blow_left / windup, 0.0, 1.0)
		if _ring != null and is_instance_valid(_ring):
			CombatVfx.set_param(_ring, &"progress", t)
		# Над рогом — смужка, як довго ще набирає повітря: встигни розбити.
		if _label != null and is_instance_valid(_label):
			var bars := int(round(t * 10.0))
			_label.text = "СУРМИТЬ " + "█".repeat(bars) + "░".repeat(10 - bars)
		enemy._model.scale = Vector3.ONE * (1.0 + 0.06 * sin(_blow_left * 30.0))
		if _blow_left <= 0.0:
			enemy._model.scale = Vector3.ONE
			_clear_ring()
			_clear_label()
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
	_label = _make_label("СУРМИТЬ ░░░░░░░░░░", 64)
	enemy.add_child(_label)
	_label.position = Vector3.UP * (enemy.target_height + 1.1)
	CombatVfx.flash_model(enemy._model, COLOR, windup)
	_ring = CombatVfx.make_telegraph(Color(COLOR, 0.8), 1.6, PI, false)
	enemy.add_child(_ring)
	_ring.position = Vector3.UP * 0.05

func _clear_ring() -> void:
	if _ring != null and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null

func _make_label(text: String, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.005
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = COLOR.lerp(Color.WHITE, 0.3)
	return label

func _clear_label() -> void:
	if _label != null and is_instance_valid(_label):
		_label.queue_free()
	_label = null

func on_death() -> void:
	_blow_left = 0.0
	_clear_ring()
	_clear_label()
	if _hint != null and is_instance_valid(_hint):
		_hint.queue_free()

func resolve() -> void:
	var reach := float(config.get("call", 24.0))
	var time := float(config.get("time", 10.0))
	var haste := float(config.get("haste", 1.35))
	# Звукова хвиля: кілька кілець розходяться по залі одне за одним.
	var parent_id := world().get_instance_id()
	for k in 4:
		var origin := enemy.global_position
		enemy.get_tree().create_timer(0.18 * k, false).timeout.connect(func() -> void:
			var parent := instance_from_id(parent_id) as Node
			if parent != null and is_instance_valid(parent):
				CombatVfx.shockwave(parent, origin, 5.0 + 5.0 * k, Color(COLOR, 0.8 - 0.15 * k), 0.7))
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.2)
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
		# Над покликаним — знак тривоги, а сам він б'є сильніше (power).
		var mark := _make_label("!", 150)
		mark.modulate = Color(1.0, 0.85, 0.3)
		other.add_child(mark)
		mark.position = Vector3.UP * (other.target_height + 0.6)
		other.damage *= float(config.get("power", 1.25))
		var trail := CombatVfx.make_trail(COLOR, 0.4)
		trail.amount = 8
		other.add_child(trail)
		trail.position = Vector3.UP * 0.4
		other.set_meta("horn_marks", [mark, trail])
		var target_id := other.get_instance_id()
		var power := float(config.get("power", 1.25))
		enemy.get_tree().create_timer(time).timeout.connect(func() -> void:
			var target := instance_from_id(target_id) as Enemy3D
			if target != null and is_instance_valid(target) and target.has_meta("horn_speed"):
				target.move_speed = float(target.get_meta("horn_speed"))
				target.damage /= power
				target.remove_meta("horn_speed")
				for mark_node in target.get_meta("horn_marks", []):
					if is_instance_valid(mark_node):
						mark_node.queue_free()
				target.remove_meta("horn_marks"))
	enemy.set_meta("horn_called", called)
