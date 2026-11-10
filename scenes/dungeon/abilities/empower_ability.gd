extends EnemyAbility

## ПОСИЛЕННЯ (Кістяний тотем): ворогів довкола посилює — поки зв'язок
## тримається, ворог б'є сильніше (bonus) і потроху лікується (regen —
## частка здоров'я за секунду). Сам тотем не б'є: розбий його першим.
##
## Як це видно (без кіл і без променів через увесь екран): над тотемом
## повільно здіймається зелена сила; від нього до кожного посиленого
## ворога раз на мить плавно летить світний згусток, а на посиленому
## ворогові тихо курять зелені іскри — видно, хто зараз сильніший.
##
## Налаштування: radius, bonus (множник шкоди), regen, links (скільки ворогів).

const REFRESH := 0.5
const COLOR := Color(0.45, 1.0, 0.45)
const ORB_EVERY := 1.1
const ORB_FLIGHT := 0.6

var _refresh_left := 0.0
var _orb_left := 0.3
var _links: Array[Enemy3D] = []
var _auras := {}
var _motes: CPUParticles3D

func _init() -> void:
	id = "empower"
	cooldown = 0.0

func tick(delta: float) -> void:
	if _motes == null:
		_motes = CombatVfx.make_motes(COLOR, 10, 0.35, 1.2, 0.22)
		enemy.add_child(_motes)
		_motes.position = Vector3.UP * enemy.target_height * 0.75
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH
		_relink()
	_orb_left -= delta
	if _orb_left <= 0.0:
		_orb_left = ORB_EVERY
		var from := enemy.global_position + Vector3.UP * enemy.target_height * 0.85
		for other in _links:
			if is_instance_valid(other) and other.is_aim_target():
				CombatVfx.glow_orb(world(), from, other, other.target_height * 0.6, COLOR, ORB_FLIGHT)

func _relink() -> void:
	var reach := float(config.get("radius", 8.0))
	var candidates: Array[Enemy3D] = []
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or other == enemy or not other.is_alive() or other.stationary or other.kind == Enemy3D.Kind.BOSS:
			continue
		if other.global_position.distance_to(enemy.global_position) <= reach:
			candidates.append(other)
	candidates.sort_custom(func(a: Enemy3D, b: Enemy3D) -> bool:
		return a.global_position.distance_to(enemy.global_position) < b.global_position.distance_to(enemy.global_position))
	_links = candidates.slice(0, int(config.get("links", 6)))
	var bonus := float(config.get("bonus", 1.25))
	var regen := float(config.get("regen", 0.015))
	for other in _links:
		other.apply_empower(bonus, REFRESH * 2.0)
		if other.current_hp < other.max_hp:
			other.heal(other.max_hp * regen * REFRESH)
	_sync_auras()

## Іскри сили на тих, кого тотем зараз посилює; хто вийшов із зв'язку — гасне.
func _sync_auras() -> void:
	var linked := {}
	for other in _links:
		linked[other.get_instance_id()] = other
		if not _auras.has(other.get_instance_id()):
			var motes := CombatVfx.make_motes(COLOR, 8, other.body_radius() * 0.9, 1.0, 0.16)
			other.add_child(motes)
			motes.position = Vector3.UP * 0.1
			_auras[other.get_instance_id()] = motes
	for key: int in _auras.keys():
		if linked.has(key):
			continue
		_fade(_auras[key])
		_auras.erase(key)

func _fade(motes: Variant) -> void:
	if is_instance_valid(motes) and motes is CPUParticles3D:
		var particles := motes as CPUParticles3D
		particles.emitting = false
		particles.get_tree().create_timer(particles.lifetime + 0.1, false).timeout.connect(particles.queue_free)

func on_death() -> void:
	for motes: Variant in _auras.values():
		_fade(motes)
	_auras.clear()
	_links.clear()
	if _motes != null and is_instance_valid(_motes):
		_motes.emitting = false
