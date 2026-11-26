extends EnemyAbility

## КРИЖАНИЙ РИВОК (Володар Крижаної Безодні) — проти втечі. Герой далі
## за min — лицар ставить меч перед собою, і до героя (туди, куди той
## біжить) по підлозі намерзає крижана доріжка (windup). Тоді він
## ковзає нею, як по катку, і рубає всіх на шляху й поруч із кінцем.
## Доріжка лишається на trail секунд: хто на неї ступить — ковзає.
## Ухиляйся вбік від доріжки, а не назад.
## Налаштування: min, windup, lead, slide, trail, damage.

const COLOR := Color(0.6, 0.9, 1.0)

var _strip: MeshInstance3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _dir := Vector3.FORWARD
var _windup := 0.7
var _wind_left := -1.0
var _slide_left := -1.0
var _hit := false
var _trails: Array = []

func _init() -> void:
	id = "frost_charge"
	cooldown = 6.0

## У фазі 3 лицар ривками частіше (rage — частка перезарядки).
func start_cooldown() -> void:
	super.start_cooldown()
	if enemy.phases != null and enemy.phases.phase >= 3:
		_left *= float(config.get("rage", 0.6))

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 6.0)) or _wind_left > 0.0 or _slide_left > 0.0:
		return false
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return false
	start_cooldown()
	_windup = float(config.get("windup", 0.7))
	_from = enemy.global_position
	# Ціль — на випередження: туди, де герой буде, коли лицар доїде.
	var target := hero.global_position
	if hero is CharacterBody3D:
		var run := (hero as CharacterBody3D).velocity
		run.y = 0.0
		target += run * float(config.get("lead", 0.6))
	var to := target - _from
	to.y = 0.0
	_dir = to.normalized() if to.length() > 0.1 else -enemy.global_basis.z
	_to = _from + _dir * clampf(to.length() + 1.0, 2.0, 18.0)
	_to = _walkable_end(_from, _to)
	var length := _from.distance_to(_to)
	_strip = BossFx.floor_plane(BossFx.ice_material(Color(0.7, 0.92, 1.0, 0.85)), Vector2(1.6, length))
	CombatVfx.set_param(_strip, &"alpha", 0.0)
	world().add_child(_strip)
	_strip.global_position = Vector3(_from.x, DungeonBuilder.FLOOR_TOP + 0.04, _from.z) + _dir * length * 0.5
	_strip.rotation.y = atan2(_dir.x, _dir.z)
	enemy.face_point(_to)
	enemy.begin_special(id, _windup, Color(COLOR, 0.0), 0.1)
	_wind_left = _windup
	CombatVfx.smoke_puff(world(), _from + Vector3.UP * 0.4, Color(0.85, 0.95, 1.0), 1.4)
	return true

## Доріжка не йде крізь стіни: зупиняється на останній прохідній клітинці.
func _walkable_end(from: Vector3, to: Vector3) -> Vector3:
	var hero := player()
	var rows: Variant = hero.get_parent().get("_map_rows") if hero != null and is_instance_valid(hero) else null
	if not rows is Array:
		return to
	var steps := int(from.distance_to(to) / 0.5)
	var last := from
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / steps)
		var cell := DungeonBuilder.cell_of(point)
		if not DungeonBuilder.is_walkable(rows, cell.x, cell.y):
			break
		last = point
	return last

func tick(delta: float) -> void:
	super.tick(delta)
	if _wind_left > 0.0:
		_wind_left -= delta
		if _strip != null and is_instance_valid(_strip):
			var t := clampf(1.0 - _wind_left / _windup, 0.0, 1.0)
			CombatVfx.set_param(_strip, &"alpha", t)
	elif _slide_left > 0.0:
		_slide_left -= delta
		var t := 1.0 - clampf(_slide_left / float(config.get("slide", 0.35)), 0.0, 1.0)
		var point := _from.lerp(_to, t)
		enemy.global_position = Vector3(point.x, enemy.global_position.y, point.z)
		_check_hit(point)
		if _slide_left <= 0.0:
			_finish()
	elif _strip != null and _wind_left > -1.0:
		# Ривок збили (оглушення) — доріжка тане.
		_wind_left -= delta
		if _wind_left < -0.6:
			_wind_left = -1.0
			_melt(_strip, 0.4)
			_strip = null
	_tick_trails(delta)

func resolve() -> void:
	_wind_left = -1.0
	_slide_left = float(config.get("slide", 0.35))
	_hit = false
	var sparks := CombatVfx.make_trail(COLOR, 0.4)
	enemy.add_child(sparks)
	sparks.position = Vector3.UP * 0.3
	enemy.get_tree().create_timer(0.6).timeout.connect(sparks.queue_free)

func _check_hit(point: Vector3) -> void:
	if _hit:
		return
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var off := hero.global_position - point
	off.y = 0.0
	if off.length() < 1.6:
		_hit = true
		if hero.take_damage(damage()):
			CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, true)
			if hero.has_method("knock_down"):
				hero.knock_down(_dir * 7.0, 0.35)

func _finish() -> void:
	CombatVfx.shockwave(world(), _to, 2.2, COLOR, 0.3)
	CombatVfx.smoke_puff(world(), _to + Vector3.UP * 0.4, Color(0.85, 0.95, 1.0), 1.8)
	var hero := player()
	if hero != null and is_instance_valid(hero):
		_check_hit(_to)
		enemy.face_point(hero.global_position)
	# Доріжка лишається слизькою.
	if _strip != null and is_instance_valid(_strip):
		CombatVfx.set_param(_strip, &"alpha", 0.7)
		_trails.append({"node": _strip, "from": _from, "to": _to, "left": float(config.get("trail", 6.0))})
	_strip = null

func _tick_trails(delta: float) -> void:
	if _trails.is_empty():
		return
	var hero := player()
	for i in range(_trails.size() - 1, -1, -1):
		var trail: Dictionary = _trails[i]
		trail.left = float(trail.left) - delta
		if hero != null and is_instance_valid(hero) and hero.has_method("set_slick"):
			var a: Vector3 = trail.from
			var b: Vector3 = trail.to
			var ab := b - a
			ab.y = 0.0
			var ap := hero.global_position - a
			ap.y = 0.0
			var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
			if (ap - ab * t).length() < 0.85:
				hero.set_slick(0.5)
		if float(trail.left) <= 0.0:
			_melt(trail.node, 1.0)
			_trails.remove_at(i)

func _melt(node: Variant, seconds: float) -> void:
	if not node is Node3D or not is_instance_valid(node):
		return
	var strip := node as Node3D
	var tween := strip.create_tween()
	tween.tween_property(strip, "scale:x", 0.01, seconds)
	tween.tween_callback(strip.queue_free)

func is_busy() -> bool:
	return _slide_left > 0.0

func on_death() -> void:
	if _strip != null and is_instance_valid(_strip):
		_strip.queue_free()
	for trail: Dictionary in _trails:
		if is_instance_valid(trail.node):
			(trail.node as Node).queue_free()
	_trails.clear()
