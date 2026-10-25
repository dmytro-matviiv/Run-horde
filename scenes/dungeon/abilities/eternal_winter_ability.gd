extends EnemyAbility

## ВІЧНА ЗИМА (Інейний Дракон, фаза 3). Холод стає смертельним: на героя
## нашаровується лід — дедалі повільніший, а як шар повний, вмерзає на
## місці. Стоячи — мерзне швидше. Лід сходить лише біля світлої руни на
## підлозі; руни (довкола арени) спалахують по черзі. Коли дракон гине,
## руни згасають одна за одною.
##
## Налаштування: runes (скільки), ring (м від центру арени), switch (с),
## build_move / build_still / melt (швидкість наростання й танення за с),
## freeze (с вмерзання), rune_radius.

const RUNE_COLOR := Color(1.0, 0.92, 0.6, 0.95)
const FROST_COLOR := Color(0.6, 0.88, 1.0, 0.85)
const CHECK := 0.2

var _active := false
var _runes: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []
var _current := 0
var _switch_left := 0.0
var _check_left := 0.0
var _frost := 0.0
var _home := Vector3.INF
var _frost_marker: MeshInstance3D

func _init() -> void:
	id = "eternal_winter"
	cooldown = 9999.0

func try_use(_distance: float) -> bool:
	start_cooldown()
	_active = true
	_place_runes()
	_switch_left = float(config.get("switch", 6.0))
	_light_rune(0)
	CombatVfx.shockwave(world(), enemy.global_position, 12.0, FROST_COLOR, 1.0)
	return false   # хід лишається за драконом — це фон бою, а не замах

func tick(delta: float) -> void:
	super.tick(delta)
	if _home == Vector3.INF and enemy.is_inside_tree():
		_home = enemy.global_position
	# Зима настає одразу з фазою — навіть якщо дракон саме оглушений чи
	# замахується (звичайна черга прийомів чекала б, доки він звільниться).
	if not _active and ready_to_use() and enemy.phases != null:
		try_use(0.0)
	if not _active:
		return
	_switch_left -= delta
	if _switch_left <= 0.0 and not _runes.is_empty():
		_switch_left = float(config.get("switch", 6.0))
		_light_rune((_current + 1) % _runes.size())
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK
	_chill(CHECK)

func _chill(step: float) -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var near_rune := false
	if not _runes.is_empty():
		var rune := _runes[_current]
		var offset := hero.global_position - rune.global_position
		offset.y = 0.0
		near_rune = offset.length() <= float(config.get("rune_radius", 1.8))
	var moving := Vector2((hero as CharacterBody3D).velocity.x, (hero as CharacterBody3D).velocity.z).length() > 0.6
	if near_rune:
		_frost = maxf(_frost - float(config.get("melt", 0.7)) * step, 0.0)
	else:
		_frost += float(config.get("build_move" if moving else "build_still", 0.07 if moving else 0.22)) * step
	if _frost >= 1.0:
		_frost = 0.55
		if hero.has_method("root"):
			hero.root(float(config.get("freeze", 1.5)))
		CombatVfx.impact(world(), hero.global_position + Vector3.UP, FROST_COLOR, true)
	if _frost > 0.05 and hero.has_method("apply_slow"):
		hero.apply_slow(1.0 - 0.65 * _frost, step * 0.8)
	_show_frost(hero)

## Інеєве коло під героєм — чим більше льоду, тим густіше.
func _show_frost(hero: Node3D) -> void:
	if _frost_marker == null or not is_instance_valid(_frost_marker):
		_frost_marker = CombatVfx.make_ground_marker(FROST_COLOR, 0.9)
		_frost_marker.set_instance_shader_parameter(&"progress", 1.0)
		hero.add_child(_frost_marker)
		_frost_marker.position = Vector3(0, 0.06, 0)
	_frost_marker.set_instance_shader_parameter(&"fade", clampf(_frost * 1.2, 0.0, 1.0))
	_frost_marker.visible = _frost > 0.03

func _place_runes() -> void:
	var map_rows: Array = DungeonLevels.get_level(GameState.dungeon_level).map
	var center := _home if _home != Vector3.INF else enemy.global_position
	var count := int(config.get("runes", 4))
	var ring := float(config.get("ring", 6.0))
	for i in count:
		var angle := TAU * i / count + PI * 0.25
		var spot := Vector3.INF
		for shrink in [1.0, 0.8, 0.6, 0.4]:
			var probe: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * ring * shrink
			var cell := DungeonBuilder.cell_of(probe)
			if DungeonBuilder.is_walkable(map_rows, cell.x, cell.y) and Enemy3D.is_spot_clear(enemy.get_world_3d(), probe):
				spot = probe
				break
		if spot == Vector3.INF:
			continue
		var rune := CombatVfx.make_telegraph(RUNE_COLOR, float(config.get("rune_radius", 1.8)), PI, false)
		rune.set_instance_shader_parameter(&"progress", 1.0)
		rune.set_instance_shader_parameter(&"fade", 0.25)
		world().add_child(rune)
		rune.global_position = Vector3(spot.x, DungeonBuilder.FLOOR_TOP + 0.04, spot.z)
		_runes.append(rune)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.9, 0.6)
		light.light_energy = 0.0
		light.omni_range = 4.0
		world().add_child(light)
		light.global_position = rune.global_position + Vector3.UP * 0.8
		_lights.append(light)

## Спалахує наступна руна, попередня гасне.
func _light_rune(index: int) -> void:
	if _runes.is_empty():
		return
	for i in _runes.size():
		var on := i == index
		var rune := _runes[i]
		var light := _lights[i]
		var tween := rune.create_tween().set_parallel(true)
		tween.tween_method(func(value: float) -> void:
			if is_instance_valid(rune):
				rune.set_instance_shader_parameter(&"fade", value), 1.0 if not on else 0.25, 1.0 if on else 0.25, 0.4)
		tween.tween_property(light, "light_energy", 2.5 if on else 0.0, 0.4)
	_current = index
	CombatVfx.shockwave(world(), _runes[index].global_position, 2.0, RUNE_COLOR, 0.5)

func on_death() -> void:
	_active = false
	if _frost_marker != null and is_instance_valid(_frost_marker):
		_frost_marker.queue_free()
	# Руни згасають одна за одною.
	var delay := 0.6
	for i in _runes.size():
		var rune := _runes[i]
		var light := _lights[i]
		enemy.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			if is_instance_valid(rune):
				CombatVfx.impact(rune.get_parent(), rune.global_position + Vector3.UP * 0.3, RUNE_COLOR, false)
				rune.queue_free()
			if is_instance_valid(light):
				light.queue_free())
		delay += 0.45
