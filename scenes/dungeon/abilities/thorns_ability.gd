extends EnemyAbility

## КОЛЮЧКИ (Колючий кущ із насіння Квітки-пастки). Хто стоїть ближче за
## radius — щоevery секунд колеться (шкода куща) і грузне (slow).
## Кущ можна зрубати, але він і так зів'яне за свій lifetime.

const COLOR := Color(0.6, 0.15, 0.2)

var _prick_left := 0.0

func _init() -> void:
	id = "thorns"
	cooldown = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	_prick_left -= delta
	if _prick_left > 0.0:
		return
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - enemy.global_position
	offset.y = 0.0
	if offset.length() > float(config.get("radius", 1.05)):
		return
	_prick_left = float(config.get("every", 0.8))
	if hero.take_damage(damage()):
		CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.6, COLOR, false)
		if hero.has_method("apply_slow"):
			hero.apply_slow(float(config.get("slow", 0.6)), 1.0)
