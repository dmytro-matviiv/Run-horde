extends EnemyAbility

## ЗВОРОТНИЙ ЧАС (Безликий Бог). Бог пам'ятає своє здоров'я за останні
## back секунд. Він ставить поруч Пісочний годинник (крихкий): якщо за
## time секунд годинник не розбито — час для Бога повертається назад, і
## він має стільки здоров'я, скільки мав back секунд тому. Розбив —
## Бог на stun секунд розгублений. Кидай усе й бий годинник.
## Налаштування: back, time, glass_hp, stun.

const COLOR := Color(1.0, 0.85, 0.4)
const GLASS := "Пісочний годинник"
const SAMPLE := 0.5

var _history: Array = []
var _sample_left := 0.0
var _glass: Enemy3D
var _wait_left := 0.0
var _target_hp := 0.0

func _init() -> void:
	id = "rewind"
	cooldown = 24.0

func tick(delta: float) -> void:
	super.tick(delta)
	_sample_left -= delta
	if _sample_left <= 0.0:
		_sample_left = SAMPLE
		_history.append(enemy.current_hp)
		var keep := int(float(config.get("back", 6.0)) / SAMPLE) + 1
		while _history.size() > keep:
			_history.pop_front()
	if _wait_left <= 0.0:
		return
	_wait_left -= delta
	if _glass == null or not is_instance_valid(_glass) or not _glass.is_alive():
		_wait_left = 0.0
		_glass = null
		CombatVfx.shockwave(world(), enemy.global_position, 3.0, COLOR, 0.4)
		enemy.stun_for(float(config.get("stun", 2.5)))
		return
	if _wait_left <= 0.0:
		var glass := _glass
		_glass = null
		if is_instance_valid(glass) and glass.is_alive():
			glass.invulnerable = false
			glass.set_meta("rewound", true)
			glass.take_damage(1.0e9)
		if _target_hp > enemy.current_hp:
			enemy.heal(_target_hp - enemy.current_hp)
			CombatVfx.shockwave(world(), enemy.global_position, 5.0, COLOR, 0.7)
			CombatVfx.impact(world(), enemy.global_position + Vector3.UP * 2.0, COLOR, true)

func try_use(_distance: float) -> bool:
	if _wait_left > 0.0 or _history.is_empty() or _history[0] <= enemy.current_hp + enemy.max_hp * 0.03:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.8)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	_target_hp = _history[0] if not _history.is_empty() else enemy.current_hp
	var hero := player()
	var side := enemy.model_forward().rotated(Vector3.UP, PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
	var spot := enemy.global_position + side * 2.6
	enemy.spawn_requested.emit(spot, {
		"name": GLASS, "model": "res://scenes/dungeon/hazards/hourglass.tscn", "kind": "totem",
		"hp": float(config.get("glass_hp", 60.0)), "damage": 0.0, "speed": 0.0, "height": 1.4, "xp": 0,
		"no_elite": true, "no_loot": true,
	}, null)
	# Щойно покликаний годинник — найновіший із такою назвою.
	for node in enemy.get_parent().get_children():
		var other := node as Enemy3D
		if other != null and other.display_name == GLASS and other.is_alive():
			_glass = other
	_wait_left = float(config.get("time", 5.0))
	if hero != null and is_instance_valid(hero):
		CombatVfx.lightning(world(), [enemy.global_position + Vector3.UP * 2.5, spot + Vector3.UP * 1.0], COLOR, 0.2)

func on_death() -> void:
	_wait_left = 0.0
	if _glass != null and is_instance_valid(_glass) and _glass.is_alive():
		_glass.take_damage(1.0e9)
	_glass = null
