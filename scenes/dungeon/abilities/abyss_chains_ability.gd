extends EnemyAbility

## ЛАНЦЮГИ БЕЗОДНІ (Володар Рун, фаза 2+). Володар чаклує (руна на
## героєві), і з підлоги до героя тягнеться фіолетовий ланцюг: герой
## прив'язаний до Володаря (не далі radius м) на time секунд. Під кінець довкола Володаря
## розгорається коло рун (burst_radius) — коли ланцюг рветься, коло
## вибухає. Встиг вибігти з кола в останню мить — цілий.
## Анти-кайт: від Володаря не втечеш, а стояти поруч теж не можна.
## Налаштування: windup, radius, time, burst_radius, burst_warn, damage.

const COLOR := Color(0.6, 0.3, 1.0)

var _time_left := 0.0
var _burst_left := -1.0
var _chain: Node3D
var _links: Array = []
var _burst_mark: MeshInstance3D

func _init() -> void:
	id = "abyss_chains"
	cooldown = 15.0

func try_use(_distance: float) -> bool:
	if _time_left > 0.0 or _burst_left >= 0.0:
		return false
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return false
	start_cooldown()
	var windup := float(config.get("windup", 0.9))
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	BossFx.hero_rune_mark(hero, COLOR, windup)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_time_left = float(config.get("time", 4.5))
	_burst_left = -1.0
	# Ланцюг — ряд темних ланок із фіолетовим обідком від Володаря до героя.
	_chain = Node3D.new()
	world().add_child(_chain)
	var material := BossFx.ghost_material(Color(0.75, 0.45, 1.0), Color(0.06, 0.02, 0.1, 0.95))
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.07
	mesh.outer_radius = 0.17
	mesh.rings = 8
	mesh.ring_segments = 6
	_links.clear()
	for i in 14:
		var link := MeshInstance3D.new()
		link.mesh = mesh
		link.material_override = material
		link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_chain.add_child(link)
		_links.append(link)
	BossFx.dark_effect(world(), BossFx.DARK_AREA, hero.global_position, 0.7, 0.9)
	CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.8, COLOR, false)

func tick(delta: float) -> void:
	super.tick(delta)
	var hero := player()
	if _time_left > 0.0 and hero != null and is_instance_valid(hero):
		_time_left -= delta
		var anchor := enemy.global_position
		var radius := float(config.get("radius", 5.0))
		if hero.has_method("leash"):
			hero.leash(anchor, radius, 0.2, false)
		_draw_chain(hero)
		# Наостанок — коло рун довкола Володаря, що вибухне.
		if _time_left <= float(config.get("burst_warn", 1.2)) and _burst_mark == null:
			_burst_mark = CombatVfx.make_ground_marker(Color(COLOR, 0.8), float(config.get("burst_radius", 3.6)))
			enemy.add_child(_burst_mark)
			_burst_mark.position.y = 0.06
			var glyph := BossFx.rune_glyph(Color(0.75, 0.5, 1.0, 0.8), float(config.get("burst_radius", 3.6)) * 2.0)
			_burst_mark.add_child(glyph)
		if _burst_mark != null:
			var warn := float(config.get("burst_warn", 1.2))
			CombatVfx.set_param(_burst_mark, &"progress", clampf(1.0 - _time_left / warn, 0.0, 1.0))
		if _time_left <= 0.0:
			_burst()
	elif _time_left > 0.0:
		_time_left = 0.0
		_clear()

func _draw_chain(hero: Node3D) -> void:
	if _chain == null or not is_instance_valid(_chain):
		return
	var from := enemy.global_position + Vector3.UP * 1.4
	var to := hero.global_position + Vector3.UP * 0.9
	var count := _links.size()
	for i in count:
		var t := float(i) / float(count - 1)
		var link: MeshInstance3D = _links[i]
		# Провисає дугою вниз, ланки через одну повернуті.
		var point := from.lerp(to, t) + Vector3.DOWN * sin(t * PI) * 0.6
		link.global_position = point
		var dir := (to - from)
		if dir.length() > 0.1:
			link.look_at(point + dir, Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD)
		link.rotate_object_local(Vector3.FORWARD, PI * 0.5 * (i % 2))
		link.rotate_object_local(Vector3.RIGHT, PI * 0.5)

func _burst() -> void:
	var radius := float(config.get("burst_radius", 3.6))
	var center := enemy.global_position
	Fx.bloom(world(), center + Vector3.UP * 0.1, "magic_03", radius * 2.4, Color(0.75, 0.5, 1.0), 0.5, true, true, 0.4, 1.2)
	CombatVfx.shockwave(world(), center, radius, COLOR, 0.35)
	var hero := player()
	if hero != null and is_instance_valid(hero):
		var off: Vector3 = hero.global_position - center
		off.y = 0.0
		if off.length() <= radius and hero.take_damage(damage()):
			CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.8, COLOR, true)
			if hero.has_method("knock_down"):
				hero.knock_down(off.normalized() * 8.0, 0.4)
	_clear()

func _clear() -> void:
	if _chain != null and is_instance_valid(_chain):
		_chain.queue_free()
	_chain = null
	_links.clear()
	if _burst_mark != null and is_instance_valid(_burst_mark):
		_burst_mark.queue_free()
	_burst_mark = null

func on_death() -> void:
	_time_left = 0.0
	_clear()
