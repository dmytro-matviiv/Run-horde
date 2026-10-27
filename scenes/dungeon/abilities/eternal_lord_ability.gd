extends EnemyAbility

## ВІЧНИЙ ПОВЕЛИТЕЛЬ (Кістяний Володар, фаза 3): уперше впавши, бос
## розсипається купою кісток — і за rise секунд збирається знову з
## часткою здоров'я (revive). Щоб не встав, поки лежить, розбий світний
## череп у купі (skull — його опис). Поки лежить — невразливий.
##
## Налаштування: rise (с), revive (частка здоров'я), skull.

const COLOR := Color(0.45, 1.0, 0.5)
const BONE_SCENE := preload("res://assets/models/graveyard/bone.glb")
const RIBS_SCENE := preload("res://assets/models/graveyard/ribcage.glb")
## Скільки грає Collapse — далі купа лежить (петля Down).
const COLLAPSE_TIME := 0.95
const RISE_TIME := 1.2

enum Step {READY, DOWN, RISING, DONE}

var _step := Step.READY
var _time := 0.0
var _down_for := 0.0
var _skull: Enemy3D
var _pile: Node3D
## Череп розбито — далі бос падає по-справжньому.
var _final := false

func _init() -> void:
	id = "eternal_lord"
	cooldown = 0.0

func is_busy() -> bool:
	return _step == Step.DOWN or _step == Step.RISING

func on_lethal() -> bool:
	if _final or _step != Step.READY:
		return false
	if enemy.phases != null and enemy.phases.phase < from_phase:
		return false
	_step = Step.DOWN
	_time = float(config.get("rise", 5.0))
	_down_for = 0.0
	enemy.current_hp = 1.0
	enemy.invulnerable = true
	enemy.untargetable = true
	enemy.hold_still(0.1)
	enemy.velocity = Vector3.ZERO
	enemy.play_once(["Collapse"])
	CombatVfx.shockwave(world(), enemy.global_position, 3.5, COLOR, 0.5)
	CombatVfx.impact(world(), enemy.global_position + Vector3.UP * 0.8, Color(0.9, 0.88, 0.8), true)
	_scatter_bones()
	_spawn_skull()
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	match _step:
		Step.DOWN:
			_time -= delta
			_down_for += delta
			if _down_for >= COLLAPSE_TIME:
				enemy.play_loop("Down")
			if _skull == null or not is_instance_valid(_skull) or not _skull.is_alive():
				_finish()
				return
			if _time <= 0.0:
				_rise()
		Step.RISING:
			_time -= delta
			if _time <= 0.0:
				_step = Step.DONE
				enemy.invulnerable = false
				enemy.untargetable = false

## Череп розбито, поки бос лежав, — більше не встане.
func _finish() -> void:
	_final = true
	_step = Step.DONE
	_clear_pile()
	enemy.invulnerable = false
	enemy.untargetable = false
	enemy.death_anims = ["Down"]
	enemy.take_damage(1.0e9)

func _rise() -> void:
	_step = Step.RISING
	_time = RISE_TIME
	# Череп повертається в купу — прибираємо без нагороди.
	if _skull != null and is_instance_valid(_skull) and _skull.is_alive():
		_skull.xp_reward = 0
		_skull.take_damage(1.0e9)
	_skull = null
	_clear_pile()
	enemy.current_hp = enemy.max_hp * float(config.get("revive", 0.3))
	enemy.play_once(["Rise"])
	CombatVfx.shockwave(world(), enemy.global_position, 6.0, COLOR, 0.6)
	CombatVfx.sky_beam(world(), enemy.global_position, COLOR)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.3)
	AudioManager.play(&"explosion")

## Світний череп у купі кісток — окремий ворог, що не б'є.
func _spawn_skull() -> void:
	var definition: Dictionary = config.get("skull", {})
	if definition.is_empty():
		return
	var spot := enemy.global_position + enemy.facing_vector() * 0.9
	enemy.spawn_requested.emit(spot, definition, enemy)
	var name := String(definition.get("name", ""))
	var best_distance := 4.0
	for node in enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Enemy3D
		if other == null or not other.is_alive() or String(other.definition.get("name", "")) != name:
			continue
		var distance := other.global_position.distance_to(spot)
		if distance < best_distance:
			best_distance = distance
			_skull = other

## Кістки й ребра довкола — купа, з якої він збирається.
func _scatter_bones() -> void:
	_clear_pile()
	_pile = Node3D.new()
	world().add_child(_pile)
	_pile.global_position = Vector3(enemy.global_position.x, DungeonBuilder.FLOOR_TOP, enemy.global_position.z)
	for i in 7:
		var piece: Node3D = (RIBS_SCENE if i % 3 == 0 else BONE_SCENE).instantiate()
		_pile.add_child(piece)
		var angle := TAU * i / 7.0 + randf() * 0.5
		piece.position = Vector3(cos(angle), 0.05, sin(angle)) * randf_range(0.6, 1.6)
		piece.rotation.y = randf() * TAU
		piece.scale = Vector3.ONE * randf_range(1.4, 2.0)

func _clear_pile() -> void:
	if _pile != null and is_instance_valid(_pile):
		_pile.queue_free()
	_pile = null

func on_death() -> void:
	_clear_pile()
