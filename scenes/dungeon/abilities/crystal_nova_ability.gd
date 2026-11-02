extends EnemyAbility

## КРИШТАЛЕВИЙ ВИБУХ (Інейна чаклунка, як Crystal Nova у Crystal Maiden):
## посох угору — і під героєм розквітає крижане коло. Хто не вибіг, поки
## воно заповнювалось, отримує шкоду й сповільнюється на slow_time секунд.
##
## Налаштування: range, radius, windup, slow (множник швидкості),
## slow_time, damage.

const COLOR := Color(0.55, 0.88, 1.0, 0.9)

var _spot := Vector3.ZERO
var _marker: MeshInstance3D

func _init() -> void:
	id = "crystal_nova"
	cooldown = 6.0

func try_use(distance: float) -> bool:
	if distance > float(config.get("range", 10.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	var hero := player()
	_spot = Vector3(hero.global_position.x, DungeonBuilder.FLOOR_TOP + 0.05, hero.global_position.z)
	var radius := float(config.get("radius", 2.4))
	var windup := float(config.get("windup", 0.95))
	_clear()
	_marker = CombatVfx.make_telegraph(COLOR, radius, PI, true)
	world().add_child(_marker)
	_marker.global_position = _spot
	var marker := _marker
	var tween := marker.create_tween()
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(marker):
			CombatVfx.set_param(marker, &"progress", value), 0.0, 1.0, windup)
	enemy.face_point(_spot)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	return true

## Замах збила суперздібність — коло зникає разом із ним.
func tick(delta: float) -> void:
	super.tick(delta)
	if _marker != null and String(enemy.get("_special")) != id:
		_clear()

func resolve() -> void:
	_clear()
	var radius := float(config.get("radius", 2.4))
	CombatVfx.shockwave(world(), _spot, radius, COLOR, 0.35)
	CombatVfx.impact_decal(world(), _spot, radius * 0.8, COLOR, 0.6)
	CombatVfx.impact(world(), _spot + Vector3.UP * 0.5, COLOR, true)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - _spot
	offset.y = 0.0
	if offset.length() <= radius and hero.take_damage(damage()):
		hero.apply_slow(float(config.get("slow", 0.5)), float(config.get("slow_time", 3.0)))

func on_death() -> void:
	_clear()

func _clear() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
