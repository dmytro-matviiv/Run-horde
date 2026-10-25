extends EnemyAbility

## ВІДКРИТІ САРКОФАГИ (Хранитель Склепів, фаза 2): бос відходить до стіни
## своєї зали, де стоять саркофаги, і відмикає їх ключами (unlock секунд)
## — тим часом не б'є, і його можна бити. Далі з саркофагів вилазять
## вороги зі списку spawn (назви звичайних ворогів рівня).
##
## Налаштування: spawn, unlock (с), speed (м/с — хода до стіни).

const COFFIN_SCENE := preload("res://assets/models/graveyard/coffin_open.glb")
const COLOR := Color(0.55, 1.0, 0.45)
## Саркофаги стоять уздовж стіни на такій відстані один від одного.
const SPACING := 2.4

enum Step {IDLE, WALK, UNLOCK}

var _step := Step.IDLE
var _target := Vector3.ZERO
var _inward := Vector3.BACK
var _time_left := 0.0
var _coffins: Array[Vector3] = []

func _init() -> void:
	id = "sarcophagi"
	cooldown = 20.0

func is_busy() -> bool:
	return _step != Step.IDLE

func try_use(_distance: float) -> bool:
	if _coffins.is_empty() and not _place_coffins():
		return false
	start_cooldown()
	_step = Step.WALK
	return true

## Саркофаги — біля стіни зали, найближчої до боса (там же, де після бою
## відкриється портал: на тій стіні вільно).
func _place_coffins() -> bool:
	var map_rows: Array = DungeonLevels.get_level(GameState.dungeon_level).map
	var wall := DungeonBuilder.portal_wall(map_rows, DungeonBuilder.cell_of(enemy.global_position))
	if wall.is_empty():
		return false
	_inward = wall.inward
	var face: Vector3 = wall.face
	var side := Vector3(-_inward.z, 0.0, _inward.x)
	_target = face + _inward * 1.6
	_target.y = enemy.global_position.y
	for k in [-1, 1, 0]:
		var spot: Vector3 = face + _inward * 0.75 + side * SPACING * k
		if k == 0:
			spot += side * SPACING * 2.0
		_coffins.append(spot)
		var coffin: Node3D = COFFIN_SCENE.instantiate()
		world().add_child(coffin)
		coffin.global_position = Vector3(spot.x, DungeonBuilder.FLOOR_TOP, spot.z)
		coffin.rotation.y = atan2(_inward.x, _inward.z)
		coffin.scale = Vector3.ONE * 1.6
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	match _step:
		Step.WALK:
			var offset := _target - enemy.global_position
			offset.y = 0.0
			if offset.length() < 0.25:
				_step = Step.UNLOCK
				_time_left = float(config.get("unlock", 3.0))
				enemy.face_point(enemy.global_position - _inward)
				return
			var step := offset.normalized() * float(config.get("speed", 4.0)) * delta
			enemy.global_position += step if step.length() < offset.length() else offset
			enemy.face_point(_target)
			enemy.play_loop("Run")
		Step.UNLOCK:
			_time_left -= delta
			enemy.play_loop("Unlock")
			if _time_left <= 0.0:
				_step = Step.IDLE
				_release()

func _release() -> void:
	var names: Array = config.get("spawn", [])
	var level: Dictionary = DungeonLevels.get_level(GameState.dungeon_level)
	for i in names.size():
		var definition := _find(level, String(names[i]))
		if definition.is_empty():
			continue
		definition = definition.duplicate(true)
		definition.erase("group")
		definition["no_elite"] = true
		var spot: Vector3 = _coffins[i % _coffins.size()] + _inward * 0.9
		CombatVfx.impact(world(), spot + Vector3.UP * 0.6, COLOR, true)
		CombatVfx.shockwave(world(), spot, 1.6, COLOR, 0.4)
		enemy.spawn_requested.emit(spot, definition, enemy)
	AudioManager.play(&"explosion", 0.05)

static func _find(level: Dictionary, name: String) -> Dictionary:
	for group: Array in level.enemies.values():
		for definition: Dictionary in group:
			if String(definition.get("name", "")) == name:
				return definition
	return {}

func on_death() -> void:
	_step = Step.IDLE
