# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/dungeon/enemy_3d.gd", [
    ('''var _knockback := Vector3.ZERO
''', '''var _knockback := Vector3.ZERO
## Розштовхування: вороги не стоять один в одному. Вектор, куди
## відсунутись від сусідів, рахується раз на SEPARATION_INTERVAL.
var _separation := Vector3.ZERO
var _separation_left := 0.0
const SEPARATION_INTERVAL := 0.15
const SEPARATION_SPEED := 3.0
## Втеча (палій): обраний напрямок, що не впирається в стіну.
var _flee_dir := Vector3.ZERO
var _flee_left := 0.0
const FLEE_LOOK := 2.5
## Таран: поки замахується, довертається за героєм (рад/с); останні
## CHARGE_LOCK секунд — уже ні, щоб можна було відскочити.
const CHARGE_AIM_SPEED := 2.6
const CHARGE_LOCK := 0.25
'''),
    ('''	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	_path_step = false''', '''	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	_path_step = false
	_separate(delta)

## Сусіди надто близько — відсуваємось (з фізикою: не в стіну й не в стіл).
## Бос і важкі ("tank") не відсуваються — від них відсуваються інші.
func _separate(delta: float) -> void:
	_separation_left -= delta
	if _separation_left <= 0.0:
		_separation_left = SEPARATION_INTERVAL
		_separation = Vector3.ZERO
		if kind != Kind.BOSS and not tank and not stationary:
			var mine := body_radius()
			for node in get_tree().get_nodes_in_group(&"enemies"):
				var other := node as Enemy3D
				if other == null or other == self or not other.is_alive() or other.is_sleeping():
					continue
				var offset := global_position - other.global_position
				offset.y = 0.0
				var reach := mine + other.body_radius()
				var distance := offset.length()
				if distance >= reach:
					continue
				if distance < 0.01:
					offset = Vector3(randf() - 0.5, 0.0, randf() - 0.5)
					distance = 0.01
				_separation += offset / distance * (reach - distance) / reach
	if _separation.is_zero_approx() or not _grounded:
		return
	move_and_collide(_separation.limit_length(1.0) * SEPARATION_SPEED * delta)

## Радіус тіла (як у капсули, яку ставить данж).
func body_radius() -> float:
	return clampf(maxf(target_height, 1.0) * 0.28, 0.35, 0.9)

## Куди тікати від героя: прямо геть, а якщо там близько стіна — під кутом.
func _pick_flee_direction() -> Vector3:
	var away := global_position - _player.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.8
	for degrees in [0.0, 35.0, -35.0, 70.0, -70.0, 105.0, -105.0]:
		var direction := away.rotated(Vector3.UP, deg_to_rad(degrees))
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * FLEE_LOOK, 1)
		query.exclude = [get_rid()]
		if space.intersect_ray(query).is_empty():
			return direction
	return Vector3.ZERO'''),
    ('''		var away := global_position - _player.global_position
		away.y = 0.0
		away = away.normalized()
		var speed := move_speed * float(flee.get("speed", 1.3))
		velocity.x = move_toward(velocity.x, away.x * speed, 20.0 * delta)
		velocity.z = move_toward(velocity.z, away.z * speed, 20.0 * delta)
		_face(away, 14.0)
		_play("Run")
		return''', '''		_flee_left -= delta
		if _flee_left <= 0.0:
			_flee_left = 0.3
			_flee_dir = _pick_flee_direction()
		# Загнали в кут — тікати нікуди, тоді б'ється (кидає далі).
		if not _flee_dir.is_zero_approx():
			var speed := move_speed * float(flee.get("speed", 1.3))
			velocity.x = move_toward(velocity.x, _flee_dir.x * speed, 20.0 * delta)
			velocity.z = move_toward(velocity.z, _flee_dir.z * speed, 20.0 * delta)
			_face(_flee_dir, 14.0)
			_play("Run")
			return'''),
    ('''		1:
			velocity.x = 0.0
			velocity.z = 0.0
			if _telegraph != null:
				_telegraph.set_instance_shader_parameter(&"progress", 1.0 - _charge_left / CHARGE_WINDUP)''', '''		1:
			velocity.x = 0.0
			velocity.z = 0.0
			# Цілиться: довертає таран за героєм, доки не "замкнувся".
			if _charge_left > CHARGE_LOCK:
				var to_player := _player.global_position - global_position
				to_player.y = 0.0
				if to_player.length() > 0.3:
					var current := atan2(_charge_dir.x, _charge_dir.z)
					var wanted := atan2(to_player.x, to_player.z)
					var angle := rotate_toward(current, wanted, CHARGE_AIM_SPEED * delta)
					_charge_dir = Vector3(sin(angle), 0.0, cos(angle))
					_model.rotation.y = angle
					if _telegraph != null:
						var length := CHARGE_SPEED * CHARGE_TIME
						_telegraph.position = Vector3(0, 0.05, 0) + _charge_dir * length * 0.5
						_telegraph.rotation.y = angle
			if _telegraph != null:
				_telegraph.set_instance_shader_parameter(&"progress", 1.0 - _charge_left / CHARGE_WINDUP)'''),
])
print("patched")
