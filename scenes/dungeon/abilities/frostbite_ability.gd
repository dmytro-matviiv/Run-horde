extends EnemyAbility

## ОБМОРОЖЕННЯ (Інейна чаклунка, як Frostbite у Crystal Maiden): простягає
## руку до героя — довкола нього стискається тонке крижане кільце. Не
## вийшов з кола — лід скуває ноги на root секунд і пече.
##
## Налаштування: range, radius, windup, root, damage.

const COLOR := Color(0.65, 0.92, 1.0, 0.9)

var _spot := Vector3.ZERO
var _marker: MeshInstance3D

func _init() -> void:
	id = "frostbite"
	cooldown = 8.0

func try_use(distance: float) -> bool:
	if distance > float(config.get("range", 9.0)) or not enemy.sees_player():
		return false
	var hero := player()
	if hero.has_method("is_rooted") and hero.is_rooted():
		return false
	start_cooldown()
	_spot = Vector3(hero.global_position.x, DungeonBuilder.FLOOR_TOP + 0.05, hero.global_position.z)
	var radius := float(config.get("radius", 1.2))
	var windup := float(config.get("windup", 0.7))
	_clear()
	_marker = CombatVfx.make_ground_marker(COLOR, radius)
	world().add_child(_marker)
	_marker.global_position = _spot
	var marker := _marker
	# Кільце стискається до героя — видно, скільки лишилось до криги.
	var tween := marker.create_tween().set_parallel(true)
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(marker):
			CombatVfx.set_param(marker, &"progress", value), 0.0, 1.0, windup)
	tween.tween_property(marker, "scale", Vector3(radius * 1.6, 1.0, radius * 1.6), windup).from(Vector3(radius * 2.6, 1.0, radius * 2.6))
	enemy.face_point(_spot)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	if _marker != null and String(enemy.get("_special")) != id:
		_clear()

func resolve() -> void:
	_clear()
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - _spot
	offset.y = 0.0
	var points: Array[Vector3] = [enemy.global_position + Vector3.UP * enemy.target_height * 0.65,
		_spot + Vector3.UP * 0.4]
	CombatVfx.lightning(world(), points, COLOR)
	CombatVfx.impact_decal(world(), _spot, float(config.get("radius", 1.2)), COLOR, 0.8)
	if offset.length() > float(config.get("radius", 1.2)) + 0.2:
		return
	if hero.take_damage(damage()) and hero.has_method("root"):
		hero.root(float(config.get("root", 1.6)))
		CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.6, COLOR, true)

func on_death() -> void:
	_clear()

func _clear() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
