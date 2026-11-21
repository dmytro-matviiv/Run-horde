extends EnemyAbility

## СПРАВЖНЯ СКРИНЯ (серед мімиків Скупаря): виглядає так само, але не
## кусає. Герой підійшов ближче за reach — скриня відчиняється: лікує
## (heal — частка здоров'я героя), сипле gold золота й зникає.

const COLOR := Color(0.6, 1.0, 0.55)

var _opened := false

func _init() -> void:
	id = "treasure"
	cooldown = 0.0

func setup(owner: Enemy3D, settings: Dictionary) -> void:
	super.setup(owner, settings)
	owner.invulnerable = true

func tick(delta: float) -> void:
	super.tick(delta)
	if _opened:
		return
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - enemy.global_position
	offset.y = 0.0
	if offset.length() > float(config.get("reach", 1.8)):
		return
	_opened = true
	if hero.has_method("heal"):
		hero.heal(float(hero.get("max_hp")) * float(config.get("heal", 0.2)))
	var dungeon := hero.get_parent()
	if dungeon != null and dungeon.has_method("drop_gold"):
		dungeon.drop_gold(enemy.global_position, int(config.get("gold", 40)))
	CombatVfx.shockwave(world(), enemy.global_position, 2.0, COLOR, 0.4)
	CombatVfx.impact(world(), enemy.global_position + Vector3.UP, COLOR, true)
	enemy.play_once(["Wake"])
	enemy.invulnerable = false
	enemy.get_tree().create_timer(0.5, false).timeout.connect(func() -> void:
		if is_instance_valid(enemy) and enemy.is_alive():
			enemy.take_damage(1.0e9))
