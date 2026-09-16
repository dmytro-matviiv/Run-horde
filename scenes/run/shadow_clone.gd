extends Node2D

## Тіньовий клон асасина: живе кілька секунд, тримається біля героя і
## сам б'є найближчого ворога. Не має фізичного тіла — по ньому не
## можна влучити, він лише завдає шкоди, тому не ламає баланс
## зіткнень і не потребує пулу (за ран їх десятки, не тисячі).

const ATTACK_INTERVAL := 0.5
const ATTACK_RANGE := 280.0
const FOLLOW_SPEED := 4.0

var _hero: Node2D
var _offset := Vector2.ZERO
var _damage := 10.0
var _life_left := 0.0
var _attack_left := 0.0
var _flash_to := Vector2.ZERO
var _flash_left := 0.0

func spawn(hero: Node2D, offset: Vector2, damage: float, lifetime: float) -> void:
	_hero = hero
	_offset = offset
	_damage = damage
	_life_left = lifetime
	global_position = hero.global_position + offset

func _process(delta: float) -> void:
	if _hero == null or not is_instance_valid(_hero):
		queue_free()
		return
	# М'яко тягнеться за героєм, а не приклеєний до нього намертво.
	global_position = global_position.lerp(_hero.global_position + _offset, clampf(FOLLOW_SPEED * delta, 0.0, 1.0))

	_life_left -= delta
	_flash_left -= delta
	_attack_left -= delta
	if _attack_left <= 0.0:
		_attack_left = ATTACK_INTERVAL
		_attack()
	queue_redraw()
	if _life_left <= 0.0:
		queue_free()

func _attack() -> void:
	var target := CombatQuery.nearest_enemy(get_tree(), global_position, ATTACK_RANGE)
	if target == null:
		return
	CombatQuery.hit(target, _damage, StatusEffects.MARK, 0.15, 2.0)
	_flash_to = target.global_position
	_flash_left = 0.12

func _draw() -> void:
	var alpha := clampf(_life_left, 0.0, 1.0) * 0.75
	var color := Color(0.55, 0.3, 0.9, alpha)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(9, 8), Vector2(-9, 8)]), color)
	if _flash_left > 0.0:
		draw_line(Vector2.ZERO, _flash_to - global_position, Color(0.8, 0.5, 1.0, alpha), 2.0)
