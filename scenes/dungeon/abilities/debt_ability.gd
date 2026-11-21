extends EnemyAbility

## БОРГ (Лихвар, Скарбниця Тіней). Лихвар записує героя в книгу: над
## головою героя золоте кільце з відліком (time с). Вдарив Лихваря до
## кінця — борг сплачено, нічого не буде. Не встиг — борг стягується:
## велика шкода (damage — частка шкоди Лихваря). Лихвар загинув — борг
## згорає. Так стрільця не вийде ігнорувати.

const COLOR := Color(1.0, 0.8, 0.25)

var _left_time := 0.0
var _mark: Node3D
var _label: Label3D

func _init() -> void:
	id = "debt"
	cooldown = 10.0

func try_use(distance: float) -> bool:
	if _left_time > 0.0 or distance < float(config.get("min", 3.0)) or distance > float(config.get("max", 12.0)) \
			or not enemy.sees_player():
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.8)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_left_time = float(config.get("time", 5.0))
	_mark = Node3D.new()
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.32
	torus.outer_radius = 0.42
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = CombatVfx.get_glow_material(COLOR)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.add_child(ring)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 96
	_label.pixel_size = 0.004
	_label.modulate = COLOR
	_label.outline_size = 18
	_label.no_depth_test = true
	_label.position.y = 0.35
	_mark.add_child(_label)
	hero.add_child(_mark)
	_mark.position = Vector3.UP * 2.3
	CombatVfx.glow_orb(world(), enemy.global_position + Vector3.UP * enemy.target_height * 0.7, hero, 2.3, COLOR, 0.4)

func tick(delta: float) -> void:
	super.tick(delta)
	if _left_time <= 0.0:
		return
	_left_time -= delta
	if _label != null and is_instance_valid(_label):
		_label.text = str(ceili(_left_time))
	if _mark != null and is_instance_valid(_mark):
		_mark.rotation.y += delta * 3.0
	if _left_time <= 0.0:
		var hero := player()
		if hero != null and is_instance_valid(hero):
			hero.take_damage(damage())
			CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, true)
			CombatVfx.shockwave(world(), hero.global_position, 1.6, COLOR, 0.35)
		_clear()

## Вдарили Лихваря — борг сплачено.
func on_damaged() -> void:
	if _left_time <= 0.0:
		return
	var hero := player()
	if hero != null and is_instance_valid(hero):
		CombatVfx.shockwave(world(), hero.global_position, 1.2, Color(0.6, 1.0, 0.5, 0.8), 0.3)
	_left_time = 0.0
	_clear()

func on_death() -> void:
	_left_time = 0.0
	_clear()

func _clear() -> void:
	if _mark != null and is_instance_valid(_mark):
		_mark.queue_free()
	_mark = null
	_label = null
