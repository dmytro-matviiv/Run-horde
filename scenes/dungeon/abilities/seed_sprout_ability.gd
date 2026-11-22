extends EnemyAbility

## НАСІННЯ, ЩО ПРОРОСТАЄ (Квітка-пастка, Потонулі Сади). Квітка стріляє
## насінням недалеко (reach у "projectile"). Насінина, що промахнулась,
## падає на підлогу й за grow секунд проростає колючим кущем: він
## загороджує прохід і коле тих, хто стоїть поруч. Чим довше бій біля
## квітки — тим тісніше. Кущів від однієї квітки не більше max.
## Налаштування: grow, max, life (с живе кущ), bush_hp, bush_damage.

const COLOR := Color(0.55, 0.9, 0.3, 0.8)
const BUSH_SCENE := "res://scenes/dungeon/hazards/thorn_bush.tscn"

var _sprouts: Array = []

func _init() -> void:
	id = "seed_sprout"
	cooldown = 0.0

func on_shot_missed(position: Vector3) -> void:
	if enemy.summons_alive + _sprouts.size() >= int(config.get("max", 4)):
		return
	var spot := Vector3(position.x, DungeonBuilder.FLOOR_TOP, position.z)
	var mark := CombatVfx.make_telegraph(COLOR, 0.6, PI, false)
	world().add_child(mark)
	mark.global_position = spot + Vector3.UP * 0.05
	_sprouts.append({"spot": spot, "mark": mark, "left": float(config.get("grow", 1.2))})

func tick(delta: float) -> void:
	super.tick(delta)
	for i in range(_sprouts.size() - 1, -1, -1):
		var sprout: Dictionary = _sprouts[i]
		sprout.left -= delta
		var grow := float(config.get("grow", 1.2))
		if is_instance_valid(sprout.mark):
			CombatVfx.set_param(sprout.mark, &"progress", clampf(1.0 - sprout.left / grow, 0.0, 1.0))
		if sprout.left > 0.0:
			continue
		_sprouts.remove_at(i)
		if is_instance_valid(sprout.mark):
			sprout.mark.queue_free()
		_grow_bush(sprout.spot)

func _grow_bush(spot: Vector3) -> void:
	# Не під самим героєм: кущ не замурує його.
	var hero := player()
	if hero != null and is_instance_valid(hero) and Vector2(spot.x - hero.global_position.x, spot.z - hero.global_position.z).length() < 0.9:
		return
	CombatVfx.smoke_puff(world(), spot + Vector3.UP * 0.3, Color(0.35, 0.55, 0.2), 0.9)
	enemy.spawn_requested.emit(spot, {
		"name": "Колючий кущ", "model": BUSH_SCENE, "kind": "totem",
		"hp": float(config.get("bush_hp", 14.0)), "damage": float(config.get("bush_damage", 6.0)),
		"speed": 0.0, "height": 1.1, "xp": 0, "no_elite": true, "no_loot": true,
		"blocker": Vector3(0.9, 1.2, 0.9), "lifetime": float(config.get("life", 12.0)),
		"abilities": [{"id": "thorns", "radius": 1.05, "every": 0.8, "slow": 0.6}],
	}, enemy)

func on_death() -> void:
	for sprout: Dictionary in _sprouts:
		if is_instance_valid(sprout.mark):
			sprout.mark.queue_free()
	_sprouts.clear()
