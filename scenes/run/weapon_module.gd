extends Node2D
class_name WeaponModule

## Модуль зброї героя: єдине місце, де рішення "чим саме б'є герой"
## перетворюється на конкретну атаку. Герой більше не вміє стріляти
## сам — він лише раз на кадр каже модулю "ось мої бонуси, атакуй,
## якщо кулдаун минув", а вже модуль дивиться на архетип спорядженої
## зброї (WeaponDef.archetype) і запускає потрібну гілку:
##
##   projectile      — звичайний постріл (можна віялом і з пробиттям)
##   aoe_projectile  — снаряд, що вибухає по площі (посох метеора)
##   cone            — струмінь вогнемета
##   melee_arc       — замах сокири/коси навколо себе
##   chain           — блискавка, що стрибає між ворогами
##   orbit_storm     — постійні клинки навколо героя (без кулдауна)
##   ground_zone     — зона на землі: багаття, крижане поле
##
## Щоб додати нову зброю, достатньо .tres з існуючим архетипом; новий
## архетип — це одна гілка в _attack() і своя сцена ефекту.

## Уміння героя слухає цей сигнал: рунний заряд рахує постріли,
## асасин вішає мітку на ціль.
signal attacked(target: Node2D)

const MELEE_ARC_SCENE := preload("res://scenes/run/melee_arc.tscn")
const FLAME_CONE_SCENE := preload("res://scenes/run/flame_cone.tscn")
const CHAIN_LIGHTNING_SCENE := preload("res://scenes/run/chain_lightning.tscn")
const STORM_BLADE_SCENE := preload("res://scenes/run/storm_blade.tscn")

var _hero: Node2D
var _projectile_pool: ObjectPool
var _blast_pool: ObjectPool
var _zone_pool: ObjectPool
var _vfx_pool: ObjectPool

var _def: WeaponDef
var _cooldown_left := 0.0
var _storm_blades: Array[Node] = []
var _flame_cone: Node
var _last_stats: Dictionary = {}

func setup(hero: Node2D, projectile_pool: ObjectPool, blast_pool: ObjectPool, zone_pool: ObjectPool, vfx_pool: ObjectPool = null) -> void:
	_hero = hero
	_projectile_pool = projectile_pool
	_blast_pool = blast_pool
	_zone_pool = zone_pool
	_vfx_pool = vfx_pool

## Намальований спалах із набору ефектів (VfxDef). Поки набору немає —
## нічого не відбувається, бій виглядає як раніше.
func play_vfx(def: VfxDef, at_position: Vector2, rotation_angle: float = 0.0) -> void:
	if _vfx_pool == null or def == null or def.texture == null:
		return
	var vfx: Node = _vfx_pool.acquire()
	vfx.play(def, at_position, rotation_angle)

func equip(def: WeaponDef) -> void:
	_def = def
	_cooldown_left = 0.0
	_clear_storm_blades()
	if def.archetype == "orbit_storm":
		_build_storm_blades()

func get_def() -> WeaponDef:
	return _def

## Викликає герой щокадру. stats — його бонуси (множники шкоди й
## кулдауна, пробиття, зайві снаряди, рикошет), щоб модуль не ліз у
## внутрішні поля героя.
func process_attack(delta: float, stats: Dictionary) -> void:
	if _def == null:
		return
	_last_stats = stats

	# Струмінь вогнемета живий кілька кадрів — увесь цей час веде за ціллю.
	if _flame_cone != null and is_instance_valid(_flame_cone):
		var live_target := _find_target()
		if live_target != null:
			_flame_cone.set_aim(_hero.global_position.direction_to(live_target.global_position))

	_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	_attack(target)
	_cooldown_left = _def.cooldown * float(stats.get("cooldown_mult", 1.0))

## Вибухи потрібні не лише зброї, а й умінням героїв (руна-нова,
## вибух мітки) — тому пул вибухів роздає модуль.
##
## Сам удар відкладаємо на кінець кадру (call_deferred). Інакше
## виходить нескінченна рекурсія: вибух убиває ворога -> смерть
## викликає вміння -> вміння створює новий вибух -> той убиває ще
## когось... і все це ВСЕРЕДИНІ обробки першої смерті, аж поки не
## переповниться стек. Відкладений виклик перетворює цей ланцюг на
## послідовність: кожна хвиля вибухів спрацьовує наступним кроком.
func spawn_blast(at_position: Vector2, radius: float, damage: float, color: Color, status: StringName = &"", status_power: float = 0.0, status_duration: float = 0.0) -> void:
	if _blast_pool == null:
		return
	var blast: Node = _blast_pool.acquire()
	blast.spawn.call_deferred(at_position, radius, damage, color, status, status_power, status_duration)

func _get_damage() -> float:
	return _def.damage * float(_last_stats.get("damage_mult", 1.0))

func _find_target() -> Node2D:
	return CombatQuery.nearest_enemy(get_tree(), _hero.global_position, 100000.0)

func _attack(target: Node2D) -> void:
	attacked.emit(target)
	AudioManager.play(&"shoot")
	var aim := _hero.global_position.direction_to(target.global_position)
	var damage := _get_damage()
	match _def.archetype:
		"projectile", "aoe_projectile":
			_fire_projectiles(aim, damage)
		"cone":
			_fire_cone(aim, damage)
		"melee_arc":
			_swing_melee(aim, damage)
		"chain":
			_fire_chain(target, damage)
		"ground_zone":
			_drop_zone(target.global_position, damage)
		"orbit_storm":
			_storm_tick(damage)

func _fire_projectiles(aim: Vector2, damage: float) -> void:
	if _projectile_pool == null:
		return
	var shots: int = _def.shots + int(_last_stats.get("extra_shots", 0))
	var pierce: int = _def.pierce + int(_last_stats.get("pierce_bonus", 0))
	var ricochet: int = int(_last_stats.get("ricochet", 0))
	var spread := deg_to_rad(_def.spread_deg)
	for i in shots:
		var angle_offset := 0.0
		if shots > 1:
			angle_offset = spread * (i - float(shots - 1) / 2.0)
		var projectile: Node = _projectile_pool.acquire()
		projectile.spawn(_hero.global_position, aim.rotated(angle_offset), _def, damage, pierce, ricochet, _on_projectile_explode)

## Снаряд вибухає не сам — він лише повідомляє модулю, де саме, бо
## пул вибухів живе тут.
func _on_projectile_explode(at_position: Vector2, damage: float) -> void:
	spawn_blast(at_position, _def.aoe_radius, damage, _def.color, _def.status, _def.status_power, _def.status_duration)
	play_vfx(_def.hit_vfx, at_position)

func _fire_cone(aim: Vector2, damage: float) -> void:
	if _flame_cone != null and is_instance_valid(_flame_cone):
		return
	_flame_cone = FLAME_CONE_SCENE.instantiate()
	_hero.add_child(_flame_cone)
	_flame_cone.ignite(aim, _def, damage)

func _swing_melee(aim: Vector2, damage: float) -> void:
	var swing: Node = MELEE_ARC_SCENE.instantiate()
	_hero.add_child(swing)
	swing.strike(_hero.global_position, aim, _def, damage)
	play_vfx(_def.swing_vfx, _hero.global_position + aim * _def.melee_range * 0.5, aim.angle())

func _fire_chain(target: Node2D, damage: float) -> void:
	var chain: Node = CHAIN_LIGHTNING_SCENE.instantiate()
	add_child(chain)
	chain.strike(_hero.global_position, target, _def, damage)
	play_vfx(_def.hit_vfx, target.global_position)

func _drop_zone(at_position: Vector2, damage: float) -> void:
	if _zone_pool == null:
		return
	var zone: Node = _zone_pool.acquire()
	zone.spawn(at_position, _def, damage)

## Вихор ріже все коло навколо героя, а не лише точки, де зараз
## клинки: інакше ворог, що притиснувся впритул, проходив би між ними.
const STORM_BAND := 22.0

func _storm_tick(damage: float) -> void:
	var enemies := CombatQuery.enemies_in_circle(get_world_2d(), _hero.global_position, _def.orbit_radius + STORM_BAND)
	CombatQuery.hit_all(enemies, damage, _def.status, _def.status_power, _def.status_duration)

func _build_storm_blades() -> void:
	for i in _def.orbit_count:
		var blade: Node = STORM_BLADE_SCENE.instantiate()
		_hero.add_child(blade)
		blade.setup(_hero, TAU / float(_def.orbit_count) * i, _def)
		_storm_blades.append(blade)

func _clear_storm_blades() -> void:
	for blade in _storm_blades:
		blade.queue_free()
	_storm_blades.clear()
