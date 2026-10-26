extends EnemyAbility

## КРИЖАНЕ ПОЛЕ (ульта Інейної чаклунки, як Freezing Field у Crystal
## Maiden): стає, здіймає посох — і seconds секунд довкола неї (radius)
## сипле сніг і вибухає лід: кожен вибух спершу маленьке коло, тоді удар.
## Усе поле сповільнює героя. Звичайні удари її не спиняють — лише
## суперздібність (або вибігти з поля чи вбити її).
##
## Налаштування: seconds, radius, every (с між вибухами), blast (радіус
## вибуху), warn (с попередження вибуху), slow, damage (за вибух).

const COLOR := Color(0.6, 0.9, 1.0, 0.85)
const SLOW_STEP := 0.4
## Ближче до неї лід не б'є (як у Dota): притиснутись до чаклунки — вихід.
const INNER := 1.3

var _active := false
var _time_left := 0.0
var _blast_left := 0.0
var _slow_left := 0.0
var _center := Vector3.ZERO
var _zone: MeshInstance3D
var _snow: CPUParticles3D

func _init() -> void:
	id = "freezing_field"
	cooldown = 16.0

func try_use(distance: float) -> bool:
	var radius := float(config.get("radius", 6.0))
	if distance > radius * 0.85 or not enemy.sees_player():
		return false
	start_cooldown()
	_active = true
	_time_left = float(config.get("seconds", 4.5))
	_blast_left = 0.3
	_slow_left = 0.0
	_center = enemy.global_position
	enemy.begin_channel()
	enemy.play_loop("Channel")
	_zone = CombatVfx.make_ground_marker(Color(COLOR, 0.35), radius)
	world().add_child(_zone)
	_zone.global_position = Vector3(_center.x, DungeonBuilder.FLOOR_TOP + 0.04, _center.z)
	var zone := _zone
	zone.create_tween().tween_method(func(value: float) -> void:
		if is_instance_valid(zone):
			zone.set_instance_shader_parameter(&"progress", value), 0.0, 1.0, 0.4)
	_snow = CombatVfx.make_trail(Color(0.85, 0.95, 1.0), 1.4)
	_snow.amount = 36
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(radius * 0.8, 0.2, radius * 0.8)
	_snow.gravity = Vector3(0, -2.5, 0)
	world().add_child(_snow)
	_snow.global_position = _center + Vector3.UP * 3.0
	CombatVfx.shockwave(world(), _center, radius, COLOR, 0.6)
	return true

func is_busy() -> bool:
	return _active

func tick(delta: float) -> void:
	super.tick(delta)
	if not _active:
		return
	# Суперздібність героя збила каст (Enemy3D.begin_channel).
	if enemy.channel_broken():
		_stop()
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_stop()
		return
	var hero := player()
	var radius := float(config.get("radius", 6.0))
	_slow_left -= delta
	if _slow_left <= 0.0 and hero != null and is_instance_valid(hero):
		_slow_left = SLOW_STEP
		var offset := hero.global_position - _center
		offset.y = 0.0
		if offset.length() <= radius and hero.has_method("apply_slow"):
			hero.apply_slow(float(config.get("slow", 0.6)), SLOW_STEP + 0.2)
	_blast_left -= delta
	if _blast_left <= 0.0:
		_blast_left = float(config.get("every", 0.2))
		_blast(_pick_spot(hero, radius))

## Третина вибухів цілить поруч із героєм — стояти на місці не вийде.
func _pick_spot(hero: Node3D, radius: float) -> Vector3:
	var spot := Vector3.ZERO
	for attempt in 4:
		if randf() < 0.35 and hero != null and is_instance_valid(hero):
			var angle := randf() * TAU
			spot = hero.global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf() * 1.6
		else:
			var angle := randf() * TAU
			spot = _center + Vector3(cos(angle), 0.0, sin(angle)) * lerpf(INNER, radius, sqrt(randf()))
		var offset := spot - _center
		offset.y = 0.0
		if offset.length() >= INNER and offset.length() <= radius:
			break
	return Vector3(spot.x, DungeonBuilder.FLOOR_TOP + 0.05, spot.z)

func _blast(spot: Vector3) -> void:
	var blast := float(config.get("blast", 1.1))
	var warn := float(config.get("warn", 0.55))
	var marker := CombatVfx.make_ground_marker(COLOR, blast)
	world().add_child(marker)
	marker.global_position = spot
	var hit_damage := damage()
	var parent := world()
	var hero := player()
	var tween := marker.create_tween()
	tween.tween_method(func(value: float) -> void:
		marker.set_instance_shader_parameter(&"progress", value), 0.0, 1.0, warn)
	tween.tween_callback(func() -> void:
		marker.queue_free()
		CombatVfx.impact(parent, spot + Vector3.UP * 0.3, COLOR, false)
		CombatVfx.impact_decal(parent, spot, blast * 0.7, COLOR, 0.3)
		if hero != null and is_instance_valid(hero):
			var offset := hero.global_position - spot
			offset.y = 0.0
			if offset.length() <= blast:
				hero.take_damage(hit_damage))

func _stop() -> void:
	if not _active:
		return
	_active = false
	enemy.end_channel()
	if _zone != null and is_instance_valid(_zone):
		var zone := _zone
		var fade := zone.create_tween()
		fade.tween_method(func(value: float) -> void:
			if is_instance_valid(zone):
				zone.set_instance_shader_parameter(&"progress", value), 1.0, 0.0, 0.4)
		fade.tween_callback(zone.queue_free)
	_zone = null
	if _snow != null and is_instance_valid(_snow):
		_snow.emitting = false
		_snow.get_tree().create_timer(1.5, false).timeout.connect(_snow.queue_free)
	_snow = null

func on_death() -> void:
	_stop()
