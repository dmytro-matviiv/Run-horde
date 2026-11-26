extends EnemyAbility

## КРИЖАНА КЛІТКА (Володар Крижаної Безодні, фаза 2+) — проти втечі.
## Герой далі за min — лицар встромляє меч у підлогу, під героєм
## розповзається іній (warn), і довкола нього виростає коло крижаних
## шпилів радіусом radius. Вийти з кола не можна time секунд, а лицар
## одразу стрибає всередину (leap, якщо є). Вибирайся перекатами від
## його удару, а не тікай.
## Налаштування: min, warn, radius, time.

const COLOR := Color(0.6, 0.9, 1.0)

var _warn_left := -1.0
var _cage_left := 0.0
var _center := Vector3.ZERO
var _frost: MeshInstance3D
var _walls: Array = []

func _init() -> void:
	id = "ice_cage"
	cooldown = 16.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 5.0)) or _warn_left > 0.0 or _cage_left > 0.0:
		return false
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.6)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_center = hero.global_position
	_center.y = DungeonBuilder.FLOOR_TOP
	_warn_left = float(config.get("warn", 0.7))
	var radius := float(config.get("radius", 3.4))
	_frost = BossFx.floor_disc(BossFx.ice_material(Color(0.8, 0.95, 1.0, 0.7)), radius)
	CombatVfx.set_param(_frost, &"alpha", 0.0)
	world().add_child(_frost)
	_frost.global_position = _center + Vector3.UP * 0.03
	CombatVfx.lightning(world(), [enemy.global_position + Vector3.UP * 0.2, _center + Vector3.UP * 0.2], COLOR, 0.14)

func tick(delta: float) -> void:
	super.tick(delta)
	if _warn_left > 0.0:
		_warn_left -= delta
		CombatVfx.set_param(_frost, &"alpha", clampf(1.0 - _warn_left / float(config.get("warn", 0.7)), 0.0, 1.0))
		if _warn_left <= 0.0:
			_raise()
		return
	if _cage_left <= 0.0:
		return
	_cage_left -= delta
	var hero := player()
	if hero != null and is_instance_valid(hero) and hero.has_method("leash"):
		hero.leash(_center, float(config.get("radius", 3.4)) - 0.5, 0.2, false)
	if _cage_left <= 0.0:
		_shatter()

func _raise() -> void:
	var radius := float(config.get("radius", 3.4))
	_cage_left = float(config.get("time", 4.0))
	# Шпилі виростають колом (стіни по 1,6 м, повернуті вздовж кола).
	var count := 12
	for i in count:
		var angle := TAU * i / count
		var wall := BossFx.ice_wall(1.9, 2.0)
		world().add_child(wall)
		wall.global_position = _center + Vector3(cos(angle), 0.0, sin(angle)) * radius + Vector3.DOWN * 2.2
		wall.rotation.y = -angle
		var tween := wall.create_tween()
		tween.tween_interval(i * 0.015)
		tween.tween_property(wall, "global_position:y", _center.y, 0.18).set_ease(Tween.EASE_OUT)
		_walls.append(wall)
	CombatVfx.shockwave(world(), _center, radius, COLOR, 0.3)
	var hero := player()
	# Лицар одразу стрибає в клітку.
	for ability in enemy.abilities:
		if ability.id == "leap" and hero != null and is_instance_valid(hero):
			ability.set("_left", 0.0)

func _shatter() -> void:
	for wall: Node3D in _walls:
		if not is_instance_valid(wall):
			continue
		CombatVfx.smoke_puff(world(), wall.global_position + Vector3.UP * 0.8, Color(0.85, 0.95, 1.0), 1.0)
		var tween := wall.create_tween()
		tween.tween_property(wall, "scale", Vector3(1.0, 0.05, 1.0), 0.25)
		tween.tween_callback(wall.queue_free)
	_walls.clear()
	if _frost != null and is_instance_valid(_frost):
		_frost.queue_free()
	_frost = null

func on_death() -> void:
	_warn_left = -1.0
	_cage_left = 0.0
	_shatter()
