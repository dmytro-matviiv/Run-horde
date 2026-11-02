extends EnemyAbility

## ПІДНЯТТЯ (Склепний чаклун): б'є посохом об підлогу — під героєм і
## поруч проступають зелені кола, за мить з них виринають кістяні руки.
## Хто лишився в колі — руки тримають його на місці (hold секунд). Встиг
## відкотитись чи відійти — промах.
##
## Налаштування: count (скільки рук), radius, tell (с до появи), hold (с),
## spread (м — наскільки друга рука від героя).

const COLOR := Color(0.45, 1.0, 0.45, 0.9)
const BONE_SCENE := preload("res://assets/models/graveyard/bone.glb")
const WINDUP := 0.6

func _init() -> void:
	id = "grasp"
	cooldown = 8.0

func try_use(distance: float) -> bool:
	if distance > float(config.get("range", 12.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	var hero := player()
	var spots: Array[Vector3] = [hero.global_position]
	var count := int(config.get("count", 2))
	var spread := float(config.get("spread", 1.8))
	for i in range(1, count):
		var angle := randf() * TAU
		spots.append(hero.global_position + Vector3(cos(angle), 0.0, sin(angle)) * spread)
	for spot in spots:
		_raise(spot)
	enemy.begin_special(id, WINDUP, Color(COLOR, 0.0), 0.1)
	return true

func _raise(spot: Vector3) -> void:
	var radius := float(config.get("radius", 1.0))
	var tell := float(config.get("tell", 1.0))
	var hold := float(config.get("hold", 1.0))
	var center := Vector3(spot.x, DungeonBuilder.FLOOR_TOP + 0.05, spot.z)
	var marker := CombatVfx.make_telegraph(COLOR, radius, PI, true)
	world().add_child(marker)
	marker.global_position = center
	var hero := player()
	var tween := marker.create_tween()
	tween.tween_method(func(value: float) -> void:
		CombatVfx.set_param(marker, &"progress", value), 0.0, 1.0, tell)
	tween.tween_callback(func() -> void:
		marker.queue_free()
		var hand := _make_hand()
		world().add_child(hand)
		hand.global_position = center
		CombatVfx.impact_decal(world(), center, radius * 0.7, COLOR, 0.3)
		var grabbed := false
		if is_instance_valid(hero):
			var offset := hero.global_position - center
			offset.y = 0.0
			if offset.length() <= radius and hero.has_method("root") and hero.root(hold):
				grabbed = true
				hero.take_damage(damage() * 0.5)
		# Руки виринають, тримають (або хапають порожнечу) і ховаються.
		hand.scale = Vector3(1.0, 0.05, 1.0)
		var rise := hand.create_tween()
		rise.tween_property(hand, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.tween_interval(hold if grabbed else 0.35)
		rise.tween_property(hand, "scale", Vector3(1.0, 0.02, 1.0), 0.25)
		rise.tween_callback(hand.queue_free))

## Кістяна "долоня": п'ять кісток, що стирчать з підлоги віялом, як пальці.
func _make_hand() -> Node3D:
	var hand := Node3D.new()
	for i in 5:
		var angle := TAU * i / 5.0
		var finger: Node3D = BONE_SCENE.instantiate()
		hand.add_child(finger)
		finger.position = Vector3(cos(angle), 0.0, sin(angle)) * 0.32
		# Кістка стоїть сторч і хилиться всередину, наче пальці стискаються.
		finger.rotation = Vector3(0.0, -angle, 0.0)
		finger.rotate_object_local(Vector3.FORWARD, deg_to_rad(70.0))
		finger.rotate(Vector3(-sin(angle), 0.0, cos(angle)), deg_to_rad(-20.0))
		finger.scale = Vector3.ONE * 1.6
	return hand
