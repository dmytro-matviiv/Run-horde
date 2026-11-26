extends EnemyAbility

## ВОГНЯНИЙ СТОВП (Жрець Полум'я). Жрець відхиляється назад і
## витягується вгору, здіймаючи руки, — під героєм розжарюється коло лави
## (warn), що світлішає. Тоді з нього б'є стовп вогню: хто в колі —
## отримує шкоду й горить (burn). Зійди з розжареного кола.
## Налаштування: windup, warn, radius, burn, damage.

const COLOR := Color(1.0, 0.5, 0.12)

var _pools: Array = []

func _init() -> void:
	id = "flame_pillar"
	cooldown = 8.0

func try_use(distance: float) -> bool:
	if distance > float(config.get("range", 11.0)):
		return false
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return false
	start_cooldown()
	var windup := float(config.get("windup", 0.6))
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	BossFx.gesture(enemy.get("_model") as Node3D, 18.0, 0.12, windup, 0.4)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var radius := float(config.get("radius", 1.8))
	var spot := hero.global_position
	spot.y = DungeonBuilder.FLOOR_TOP + 0.04
	var pool := BossFx.floor_disc(BossFx.lava_material(0.0, 0.0), radius)
	world().add_child(pool)
	pool.global_position = spot
	CombatVfx.lightning(world(), [enemy.global_position + Vector3.UP * enemy.target_height,
		spot + Vector3.UP * 0.3], COLOR, 0.12)
	_pools.append({"node": pool, "spot": spot, "left": float(config.get("warn", 1.0))})

func tick(delta: float) -> void:
	super.tick(delta)
	var warn := float(config.get("warn", 1.0))
	for i in range(_pools.size() - 1, -1, -1):
		var p: Dictionary = _pools[i]
		p.left = float(p.left) - delta
		var node: MeshInstance3D = p.node
		if is_instance_valid(node):
			var t := clampf(1.0 - float(p.left) / warn, 0.0, 1.0)
			BossFx.set_heat(node, t, 0.35 + 0.6 * t)
		if float(p.left) > 0.0:
			continue
		_pools.remove_at(i)
		_erupt(p)

func _erupt(p: Dictionary) -> void:
	var spot: Vector3 = p.spot
	var radius := float(config.get("radius", 1.8))
	BossFx.fire_column(world(), spot, radius, 4.0, 0.7)
	CombatVfx.shockwave(world(), spot, radius, COLOR, 0.3)
	var node: MeshInstance3D = p.node
	if is_instance_valid(node):
		var tween := node.create_tween()
		tween.tween_method(func(v: float) -> void: BossFx.set_heat(node, v, v), 1.0, 0.0, 1.0)
		tween.tween_callback(node.queue_free)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var off: Vector3 = hero.global_position - spot
	off.y = 0.0
	if off.length() <= radius and hero.take_damage(damage()):
		CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, true)
		if hero.has_method("ignite"):
			hero.ignite(damage() * 0.08, float(config.get("burn", 3.0)))

func on_death() -> void:
	for p: Dictionary in _pools:
		if is_instance_valid(p.node):
			(p.node as Node).queue_free()
	_pools.clear()
