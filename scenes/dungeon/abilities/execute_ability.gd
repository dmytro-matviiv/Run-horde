extends EnemyAbility

## СТРАТА (Демон-кат). Коли здоров'я героя нижче за below — кат чує
## слабкість: його удари в factor разів сильніші, а над героєм горить
## знак черепа. Не підпускай ката, коли поранений.
## Налаштування: below, factor.

const COLOR := Color(1.0, 0.25, 0.15)

var _base := -1.0
var _mark: Label3D

func _init() -> void:
	id = "execute"
	cooldown = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	if _base < 0.0:
		_base = enemy.damage
	var low: bool = hero.current_hp < hero.max_hp * float(config.get("below", 0.35))
	enemy.damage = _base * (float(config.get("factor", 2.0)) if low else 1.0)
	var near := hero.global_position.distance_to(enemy.global_position) < 9.0
	if low and near and _mark == null:
		_mark = Label3D.new()
		_mark.text = "СТРАТА"
		_mark.font_size = 80
		_mark.pixel_size = 0.005
		_mark.outline_size = 18
		_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_mark.no_depth_test = true
		_mark.modulate = COLOR
		world().add_child(_mark)
	if _mark != null:
		if not (low and near):
			_clear()
		else:
			_mark.global_position = hero.global_position + Vector3.UP * 2.7

func on_death() -> void:
	_clear()

func _clear() -> void:
	if _mark != null and is_instance_valid(_mark):
		_mark.queue_free()
	_mark = null
