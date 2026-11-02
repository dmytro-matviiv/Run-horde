extends EnemyAbility

## МЕТЕОРИТНИЙ ШТОРМ (лише мега-боси). Небо над усією залою вкривається
## колами попередження одразу — не по черзі, як дощ небезпек фаз, а всі
## разом: після короткого спільного відліку земля здригається на весь
## екран. Безпечних місць мало й вони випадкові щоразу — доводиться
## бігти, а не просто стояти в кутку. "count" — скільки метеоритів,
## "radius" — розмір кожного, "safe" — скільки лишити явно вільними
## навколо героя (щоб перша хвиля не була невідворотною смертю).

const WARN := 1.3
const COLOR := Color(1.0, 0.35, 0.1)

func _init() -> void:
	id = "meteor_storm"
	cooldown = 14.0

func try_use(_distance: float) -> bool:
	start_cooldown()
	enemy.begin_special(id, WARN, Color(COLOR, 0.0), 0.1)   # власного кола в героя нема — метеорити самі покажуть свої
	return true

func resolve() -> void:
	var count := int(config.get("count", 10))
	var radius := float(config.get("radius", 2.0))
	# "span" — половина боку квадрата, звідки сиплються метеорити, довкола
	# боса. Під час усього відліку (WARN) бос стоїть на місці (замах), тож
	# позиція не "стрибає", поки метеорити готуються.
	var span := float(config.get("span", 7.0))
	var center := enemy.global_position
	var safe := int(config.get("safe", 2))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var hero_pos := player().global_position
	var spots: Array[Vector3] = []
	var attempts := 0
	while spots.size() < count and attempts < count * 6:
		attempts += 1
		var spot := Vector3(
			center.x + rng.randf_range(-span, span), 0.0,
			center.z + rng.randf_range(-span, span))
		# Кілька перших метеоритів свідомо не б'ють по герою одразу — є
		# куди відбігти в першу мить.
		if spots.size() < safe and spot.distance_to(hero_pos) < radius * 2.2:
			continue
		spots.append(spot)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.1)
	for spot in spots:
		_meteor(spot, radius)

func _meteor(spot: Vector3, radius: float) -> void:
	var marker := CombatVfx.make_telegraph(Color(COLOR, 0.9), radius, PI, true)
	world().add_child(marker)
	marker.global_position = Vector3(spot.x, DungeonBuilder.FLOOR_TOP + 0.05, spot.z)
	var hero := player()
	var hit_damage := damage() * 0.9
	var tween := marker.create_tween()
	tween.tween_method(func(value: float) -> void:
		CombatVfx.set_param(marker, &"progress", value), 0.0, 1.0, WARN)
	tween.tween_callback(func() -> void:
		marker.queue_free()
		CombatVfx.shockwave(world(), spot, radius, COLOR, 0.3)
		CombatVfx.impact_decal(world(), spot, radius * 0.75, COLOR, 0.3)
		CombatVfx.impact(world(), spot + Vector3.UP * 0.6, COLOR, true)
		if is_instance_valid(hero):
			var offset := hero.global_position - spot
			offset.y = 0.0
			if offset.length() <= radius:
				hero.take_damage(hit_damage))
