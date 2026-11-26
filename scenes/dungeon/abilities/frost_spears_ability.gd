extends EnemyAbility

## СПИСИ ХОЛОДУ (Володар Крижаної Безодні, фаза 2+) — проти стрільців.
## Лицар здіймає руку — над ним намерзає віяло з count крижаних списів
## (windup), і вони летять на випередження: туди, куди біжить герой, а
## крайні — трохи вбік від нього. Біг по прямій карається; рятує зміна
## напрямку чи перекат.
## Налаштування: count, spread, lead, speed, damage.

const COLOR := Color(0.6, 0.9, 1.0)

var _spears: Array = []

func _init() -> void:
	id = "frost_spears"
	cooldown = 8.0

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 4.0)):
		return false
	start_cooldown()
	var windup := float(config.get("windup", 0.8))
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	# Списи намерзають над лицарем віялом — видно, звідки полетять.
	_spears.clear()
	var count := int(config.get("count", 5))
	for i in count:
		var spear := EnemyProjectile.create(damage(), COLOR, float(config.get("speed", 15.0)))
		spear.shape = "spear"
		enemy.add_child(spear)
		var side := (float(i) - (count - 1) * 0.5) * 0.7
		spear.position = Vector3(side, enemy.target_height + 0.6 - absf(side) * 0.25, 0.0)
		spear.scale = Vector3.ONE * 0.2
		var tween := spear.create_tween()
		tween.tween_property(spear, "scale", Vector3.ONE, windup * 0.8)
		_spears.append(spear)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		_drop()
		return
	var target := hero.global_position
	if hero is CharacterBody3D:
		var run := (hero as CharacterBody3D).velocity
		run.y = 0.0
		target += run * float(config.get("lead", 0.55))
	var count := _spears.size()
	var spread := deg_to_rad(float(config.get("spread", 9.0)))
	for i in count:
		var spear: EnemyProjectile = _spears[i]
		if not is_instance_valid(spear):
			continue
		var aim := target + Vector3.UP * 1.0 - spear.global_position
		aim = aim.rotated(Vector3.UP, (float(i) - (count - 1) * 0.5) * spread)
		spear.launch(aim, hero, world())
	_spears.clear()

func tick(delta: float) -> void:
	super.tick(delta)
	# Каст збили (оглушення) — списи розсипаються, а не висять над ним.
	if not _spears.is_empty() and String(enemy.get("_special")) != id:
		for spear: Variant in _spears:
			if is_instance_valid(spear):
				CombatVfx.smoke_puff(world(), (spear as Node3D).global_position, Color(0.85, 0.95, 1.0), 0.6)
		_drop()

func _drop() -> void:
	for spear: Variant in _spears:
		if is_instance_valid(spear):
			(spear as Node).queue_free()
	_spears.clear()

func on_death() -> void:
	_drop()
