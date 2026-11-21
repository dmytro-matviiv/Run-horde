extends EnemyAbility

## КОВАДЛО-ЩИТ (Ковадлоносець, Кузня Присмерку). Ковадло завжди перед
## ним: удари спереду майже не проходять (front_factor), а стріли й
## закляття здалеку (далі за reflect_range) ковадло відбиває назад у героя.
## Збоку й ззаду — повна шкода. Раз на cooldown він гупає ковадлом об
## землю (коло radius) — і open секунд стоїть відкритий, отримуючи все.
##
## Налаштування: cooldown, radius, damage (частка за гупання), open,
## front_factor, reflect_range, reflect_damage.

const COLOR := Color(1.0, 0.75, 0.35, 0.85)
const FRONT_ANGLE := deg_to_rad(70.0)
const REFLECT_GAP := 0.35

var _open_left := 0.0
var _reflect_wait := 0.0

func _init() -> void:
	id = "anvil_slam"
	cooldown = 8.0

func tick(delta: float) -> void:
	super.tick(delta)
	_open_left -= delta
	_reflect_wait -= delta

func try_use(distance: float) -> bool:
	if distance > float(config.get("radius", 2.6)) + 0.4:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.8)), COLOR, float(config.get("radius", 2.6)))
	return true

func resolve() -> void:
	var radius := float(config.get("radius", 2.6))
	CombatVfx.shockwave(world(), enemy.global_position, radius, COLOR, 0.4)
	CombatVfx.impact_decal(world(), enemy.global_position, radius * 0.7, COLOR)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.2)
	var hero := player()
	if hero != null and is_instance_valid(hero):
		var offset := hero.global_position - enemy.global_position
		offset.y = 0.0
		if offset.length() <= radius:
			hero.take_damage(damage())
	# Відкритий: ковадло лежить на землі, сам важко дихає.
	var open := float(config.get("open", 2.5))
	_open_left = open
	enemy.hold_still(open)
	enemy.play_loop("Stunned")

func filter_damage(amount: float, _heavy: bool) -> float:
	if _open_left > 0.0:
		return amount
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return amount
	var to_hero := hero.global_position - enemy.global_position
	to_hero.y = 0.0
	if to_hero.length() < 0.05:
		return amount
	if enemy.model_forward().angle_to(to_hero.normalized()) > FRONT_ANGLE:
		return amount
	var chest := enemy.global_position + Vector3.UP * enemy.target_height * 0.55 + to_hero.normalized() * 0.6
	CombatVfx.impact(world(), chest, COLOR, false)
	# Здалеку — стріла чи закляття: ковадло відбиває їх назад.
	if to_hero.length() > float(config.get("reflect_range", 3.2)):
		if _reflect_wait <= 0.0:
			_reflect_wait = REFLECT_GAP
			enemy.spawn_shot(chest, to_hero.normalized(), COLOR, 13.0,
				enemy.damage * float(config.get("reflect_damage", 0.6)))
		return 0.0
	return amount * float(config.get("front_factor", 0.2))
