extends EnemyAbility

## ОТОЧЕННЯ (Сніговий вовк). Вовк не біжить на героя навпростець: забігає
## по колу (radius) і кружляє time секунд, гарчачи, поки решта зграї
## займає інші боки. Тоді одразу стрибає (wolf_pounce) — збоку чи зі
## спини. Тож зграя нападає звідусіль, а не чергою спереду.
## Налаштування: radius, time, speed.

var _time_left := 0.0
var _dir := 1.0

func _init() -> void:
	id = "wolf_circle"
	cooldown = 8.0
	instant = true

func try_use(distance: float) -> bool:
	if _time_left > 0.0 or distance > 9.0 or distance < 1.5:
		return false
	# Кружляє, лише коли поруч є ще хтось зі зграї.
	var mates := 0
	for node in enemy.get_parent().get_children():
		var other := node as Enemy3D
		if other != null and other != enemy and other.is_alive() and other.display_name == enemy.display_name \
				and other.global_position.distance_to(enemy.global_position) < 12.0:
			mates += 1
	if mates == 0:
		return false
	start_cooldown()
	_time_left = float(config.get("time", 1.8)) * randf_range(0.8, 1.3)
	_dir = 1.0 if randf() < 0.5 else -1.0
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	if _time_left <= 0.0 or not enemy.is_alive():
		return
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		_time_left = 0.0
		return
	_time_left -= delta
	var radius := float(config.get("radius", 3.6))
	var off := enemy.global_position - hero.global_position
	off.y = 0.0
	var d := maxf(off.length(), 0.1)
	var angle := atan2(off.z, off.x) + _dir * float(config.get("speed", 5.5)) / radius * delta
	# Плавно на коло потрібного радіуса й по ньому.
	var r := move_toward(d, radius, 4.0 * delta)
	var next := hero.global_position + Vector3(cos(angle), 0.0, sin(angle)) * r
	next.y = enemy.global_position.y
	var rows: Variant = hero.get_parent().get("_map_rows")
	var cell := DungeonBuilder.cell_of(next)
	if rows is Array and not DungeonBuilder.is_walkable(rows, cell.x, cell.y):
		_dir = -_dir
		return
	enemy.global_position = next
	enemy.face_point(next + Vector3(-sin(angle), 0.0, cos(angle)) * _dir)
	enemy.call("_play", "Run")
	if _time_left <= 0.0:
		# З кола — одразу в стрибок.
		for ability in enemy.abilities:
			if ability.id == "wolf_pounce":
				ability.set("_left", 0.0)

func is_busy() -> bool:
	return _time_left > 0.0
