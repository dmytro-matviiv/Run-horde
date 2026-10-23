extends HeroPassive3D

## МІТКА СМЕРТІ — пасивка Асасина Порожнечі.
## Удар лишає на ворогові мітку: позначений отримує більше шкоди від
## будь-чого, а коли гине — лопається хмарою отрути й труїть сусідів.
## Тому асасину вигідно бити по черзі всіх, а добивати — мічених.

const MARK_TIME := 4.0
const MARK_BONUS := 1.25
const BURST_RADIUS := 2.6
const BURST_DAMAGE := 0.6
const MARK_COLOR := Color(0.8, 0.45, 1.0)

## id ворога -> коли мітка згасне (секунди від старту гри).
var _marks: Dictionary = {}

func _init() -> void:
	id = &"death_mark"
	title = "Мітка Цілі"
	description = "Влучання лишають мітку: мічений отримує на чверть більше шкоди, а гинучи — вибухає, зачіпаючи сусідів."
	color = MARK_COLOR

func modify_damage(player: Node, enemy: Node, amount: float) -> float:
	# "Мисливець" із походу робить мітку ще болючішою.
	return amount * (MARK_BONUS + player.mark_bonus()) if _is_marked(enemy) else amount

func on_hit(_player: Node, enemy: Node, _amount: float, _heavy: bool) -> void:
	_marks[enemy.get_instance_id()] = _now() + MARK_TIME

func on_kill(player: Node, enemy: Node) -> void:
	if not _is_marked(enemy):
		return
	_marks.erase(enemy.get_instance_id())
	var center: Vector3 = enemy.global_position
	CombatVfx.shockwave(player.get_parent(), center, BURST_RADIUS, MARK_COLOR, 0.4)
	for other: Enemy3D in player.enemies_in_radius(BURST_RADIUS + center.distance_to(player.global_position), false):
		if other.global_position.distance_to(center) <= BURST_RADIUS:
			player.deal_damage(other, BURST_DAMAGE, Vector3.ZERO, false, id)

func tick(_player: Node, _delta: float) -> void:
	# Прибираємо згаслі мітки, щоб словник не ріс увесь похід.
	if _marks.size() < 24:
		return
	var now := _now()
	for key: int in _marks.keys():
		if _marks[key] < now:
			_marks.erase(key)

func _is_marked(enemy: Node) -> bool:
	return _marks.get(enemy.get_instance_id(), 0.0) > _now()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
