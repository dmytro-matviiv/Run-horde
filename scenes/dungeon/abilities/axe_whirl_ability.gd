extends EnemyAbility

## ВИХОР СОКИРИ (Берсерк Півночі). Берсерк реве й присідає (windup), тоді
## крутиться дзиґою з сокирою time секунд і суне на героя (speed): кожні
## every секунд коло льодяних замахів б'є всіх у radius, а під ним
## намерзає ожеледь (як від його ударів). Не стій поруч — відходь убік
## і бий, коли він, закрутившись, похитується (dizzy).
## Налаштування: windup, time, speed, radius, every, dizzy, damage.

const COLOR := Color(0.75, 0.92, 1.0)

var _time_left := 0.0
var _hit_left := 0.0
var _rest_yaw := 0.0
var _swings := 0

func _init() -> void:
	id = "axe_whirl"
	cooldown = 11.0

func try_use(distance: float) -> bool:
	if distance > 6.0 or _time_left > 0.0:
		return false
	start_cooldown()
	var windup := float(config.get("windup", 0.6))
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	BossFx.gesture(enemy.get("_model") as Node3D, -12.0, -0.15, windup, 0.2)
	return true

func resolve() -> void:
	_time_left = float(config.get("time", 2.4))
	_hit_left = 0.0
	var model := enemy.get("_model") as Node3D
	if model != null:
		_rest_yaw = model.rotation.y

func tick(delta: float) -> void:
	super.tick(delta)
	if _time_left <= 0.0 or not enemy.is_alive():
		return
	_time_left -= delta
	var model := enemy.get("_model") as Node3D
	if model != null:
		model.rotation.y += TAU * 2.2 * delta
	var hero := player()
	if hero != null and is_instance_valid(hero):
		var to := hero.global_position - enemy.global_position
		to.y = 0.0
		if to.length() > 0.8:
			var next := enemy.global_position + to.normalized() * float(config.get("speed", 2.6)) * delta
			var rows: Variant = hero.get_parent().get("_map_rows")
			var cell := DungeonBuilder.cell_of(next)
			if not rows is Array or DungeonBuilder.is_walkable(rows, cell.x, cell.y):
				enemy.global_position = next
	_hit_left -= delta
	if _hit_left <= 0.0:
		_hit_left = float(config.get("every", 0.4))
		var radius := float(config.get("radius", 1.9))
		CombatVfx.slash(world(), enemy.global_position + Vector3.UP * 1.0, randf() * TAU, radius, 300.0, COLOR, false, 0.0, 0.3)
		if hero != null and is_instance_valid(hero):
			var off := hero.global_position - enemy.global_position
			off.y = 0.0
			if off.length() <= radius and hero.take_damage(damage()):
				CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, false)
		# Ожеледь під ним — та сама, що від ударів (ice_slick).
		_swings += 1
		for ability in enemy.abilities:
			if ability.id == "ice_slick" and _swings % 3 == 0:
				ability.on_strike()
	if _time_left <= 0.0:
		if model != null:
			model.rotation.y = _rest_yaw
		enemy.stun_for(float(config.get("dizzy", 1.2)))
		CombatVfx.smoke_puff(world(), enemy.global_position + Vector3.UP * enemy.target_height, Color(0.9, 0.95, 1.0), 0.8)

func is_busy() -> bool:
	return _time_left > 0.0

func on_death() -> void:
	if _time_left > 0.0:
		var model := enemy.get("_model") as Node3D
		if model != null:
			model.rotation.y = _rest_yaw
	_time_left = 0.0
