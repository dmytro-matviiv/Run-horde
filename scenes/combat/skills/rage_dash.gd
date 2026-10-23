extends HeroSkill3D

## РИВОК ЛЮТІ — Клинкова Вартова, друга кнопка.
##
## Не має звичайної перезарядки: заряджається ЛЮТТЮ, яку вартова
## накопичує, б'ючи й отримуючи удари (див. пасивку Rage). Повна шкала —
## можна зірватися в ривок крізь ворогів: усіх на шляху розкидає, сама
## в цей час невразлива, а після ривка кілька секунд б'є швидше.
##
## Через це вартова грається агресивно: що гарячіший бій, то частіші
## ривки — саме те, чого не дає звичайний кулдаун.

const DISTANCE := 7.0
const TIME := 0.3
const DAMAGE := 2.0
const KNOCKBACK := 5.0
const HIT_RADIUS := 1.9
const INVULNERABLE := 0.45
const FURY_TIME := 4.0
const FURY_ATTACK_SPEED := 1.3
const RAGE_COLOR := Color(1.0, 0.5, 0.2)

var _dash_left := -1.0
var _hit_ids: Array = []

func _init() -> void:
	id = &"rage_dash"
	title = "Ривок"
	description = "Шкала люті повна — ривок крізь ворогів: розкидає всіх на шляху, дає невразливість і прискорює удари."
	color = RAGE_COLOR
	icon_kind = "dash"
	cooldown = 0.6   # лише щоб не спрацювало двічі за один дотик

## Кнопка світиться не за таймером, а за люттю.
func get_charge(player: Node) -> float:
	var passive: HeroPassive3D = player.passive
	return passive.get_charge() if passive != null else -1.0

func _use(player: Node) -> bool:
	var passive: HeroPassive3D = player.passive
	if passive == null or passive.get_charge() < 1.0:
		return false
	passive.consume_charge()
	_dash_left = TIME
	_hit_ids.clear()
	# "Таран" із походу робить ривок довшим і болючішим.
	var distance: float = DISTANCE * (1.0 + (player.dash_power() - 1.0) * 0.5)
	player.dash(player.facing_vector(), distance / TIME, TIME)
	player.grant_invulnerable(INVULNERABLE)
	player.add_attack_speed(FURY_ATTACK_SPEED, FURY_TIME)
	var parent := player.get_parent()
	CombatVfx.shockwave(parent, player.global_position, 2.2, color, 0.35)
	CombatVfx.slash(parent, player.global_position + Vector3.UP, player.facing_angle(), 2.6, 120.0, color, false, 0.0, 0.3)
	player.shake_camera(0.12)
	return true

## Поки триває ривок, б'ємо кожного, крізь кого пробігли — але кожного
## лише раз.
func _update(player: Node, delta: float) -> void:
	if _dash_left < 0.0:
		return
	_dash_left -= delta
	for enemy: Enemy3D in player.enemies_in_radius(HIT_RADIUS, false):
		if _hit_ids.has(enemy.get_instance_id()):
			continue
		_hit_ids.append(enemy.get_instance_id())
		var push: Vector3 = enemy.global_position - player.global_position
		push.y = 0.0
		if push.length() < 0.1:
			push = player.facing_vector()
		player.deal_damage(enemy, DAMAGE * player.dash_power(), push.normalized() * KNOCKBACK, true, id)
		CombatVfx.hitstop(player.get_tree(), 0.04)
	if _dash_left <= 0.0:
		_dash_left = -1.0
