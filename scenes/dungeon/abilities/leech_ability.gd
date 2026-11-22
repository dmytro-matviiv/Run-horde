extends EnemyAbility

## ПРИСМОКТУВАННЯ (Болотна п'явка, Потонулі Сади). Укус, що влучив, —
## п'явка присмоктується до героя й їде на ньому: щоevery секунд
## висмоктує drain (частку своєї шкоди) й лікується на стільки ж. Сама не
## відпаде, поки не мине time секунд, — її треба вбити просто на собі.
## Кілька п'явок разом — швидко тануть сили.
## Налаштування: drain, every, time, heal (частка висмоктаного).

const COLOR := Color(0.85, 0.15, 0.2)

var _attached_left := 0.0
var _drain_left := 0.0
var _offset := Vector3.ZERO

func _init() -> void:
	id = "leech"
	cooldown = 0.0

func on_strike() -> void:
	if _attached_left > 0.0 or not enemy.strike_landed:
		return
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_attached_left = float(config.get("time", 7.0))
	_drain_left = float(config.get("every", 0.6))
	var angle := randf() * TAU
	_offset = Vector3(cos(angle), 0.0, sin(angle)) * 0.5
	enemy.collision_layer = 0
	CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.6, COLOR, false)

func is_busy() -> bool:
	return _attached_left > 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	if _attached_left <= 0.0:
		return
	_attached_left -= delta
	var hero := player()
	if hero == null or not is_instance_valid(hero) or (hero.has_method("is_swallowed") and hero.is_swallowed()):
		_detach()
		return
	enemy.global_position = hero.global_position + _offset
	enemy.face_point(hero.global_position)
	enemy.velocity = Vector3.ZERO
	_drain_left -= delta
	if _drain_left <= 0.0:
		_drain_left = float(config.get("every", 0.6))
		var amount := damage() * float(config.get("drain", 0.35))
		if hero.take_damage(amount):
			enemy.heal(amount * float(config.get("heal", 1.0)))
			CombatVfx.glow_orb(world(), hero.global_position + Vector3.UP, enemy, enemy.target_height * 0.5, COLOR, 0.25)
	if _attached_left <= 0.0:
		_detach()

func _detach() -> void:
	_attached_left = 0.0
	if not enemy.is_alive():
		return
	enemy.collision_layer = 4
	var hero := player()
	if hero != null and is_instance_valid(hero):
		var away := enemy.global_position - hero.global_position
		away.y = 0.0
		enemy.global_position = hero.global_position + away.normalized() * 1.2 + Vector3.UP * 0.2
	CombatVfx.smoke_puff(world(), enemy.global_position, Color(0.3, 0.35, 0.2), 0.8)

func on_death() -> void:
	_attached_left = 0.0
