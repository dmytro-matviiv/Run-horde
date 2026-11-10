extends EnemyAbility

## ВІДКРИТІ САРКОФАГИ (Хранитель Склепів, фаза 2). Рев — і герой
## оглушений (зірочки, ні кроку, ні перекату). Бос іде до стіни своєї
## зали — не тієї, де після бою відкриється портал, — там із підлоги
## виростають саркофаги; відмикає їх (unlock секунд), і з них вилазять
## вороги зі списку spawn. Щойно вилізли — оглушення спадає, бій далі.
## Саркофаги тверді й лишаються до кінця бою.
##
## Налаштування: spawn (назви звичайних ворогів рівня), unlock (с),
## speed (м/с — хода до стіни).

const SARCOPHAGUS_SCENE := preload("res://assets/models/props/sarcophagus.glb")
const COLOR := Color(0.55, 1.0, 0.45)
## Модель: 2.3 x 1.27 x 1.23 м, лицем (замок) уперед по +Z.
const BOX := Vector3(2.1, 1.2, 1.15)
## Відстань між саркофагами вздовж стіни й відступ від лиця стіни.
const SPACING := 2.8
const WALL_GAP := 1.0
## Оглушення героя — доки вороги не вилізуть, але не довше за це.
const STUN_LIMIT := 12.0

enum Step {IDLE, WALK, UNLOCK}

var _step := Step.IDLE
var _target := Vector3.ZERO
var _inward := Vector3.BACK
var _time_left := 0.0
var _coffins: Array[Vector3] = []
var _wall_face := Vector3.ZERO
var _placed := false
## Де бос з'явився (середина його зали) — від нього шукаємо стіну.
var _home := Vector3.INF
## Хода до стіни не довше за це — далі відмикає, де стоїть (не застрягає).
const WALK_LIMIT := 4.0

func _init() -> void:
	id = "sarcophagi"
	cooldown = 20.0

func is_busy() -> bool:
	return _step != Step.IDLE

func try_use(_distance: float) -> bool:
	if _wall_face == Vector3.ZERO and not _find_wall():
		return false
	start_cooldown()
	_step = Step.WALK
	_time_left = WALK_LIMIT
	var hero := player()
	if hero != null and hero.has_method("stun"):
		hero.stun(STUN_LIMIT)
	enemy.play_once(["Roar"])
	CombatVfx.shockwave(world(), enemy.global_position, 9.0, COLOR, 0.6)
	return true

## Стіна для саркофагів — у самій залі боса (не в коридорі) і не та, де
## після бою відкриється портал. Шукаємо від місця, де бос з'явився.
func _find_wall() -> bool:
	var map_rows: Array = DungeonLevels.get_level(GameState.dungeon_level).map
	var cell := DungeonBuilder.cell_of(_home if _home != Vector3.INF else enemy.global_position)
	var portal := DungeonBuilder.portal_wall(map_rows, cell)
	var wall := DungeonBuilder.portal_wall(map_rows, cell, portal.get("inward", Vector3.ZERO), true)
	if wall.is_empty():
		return false
	_inward = wall.inward
	_wall_face = wall.face
	_target = _wall_face + _inward * (WALL_GAP + 2.0)
	_target.y = enemy.global_position.y
	return true

## Саркофаги виростають, коли бос уже дійшов, — не на його шляху.
func _place_coffins() -> void:
	if _placed:
		return
	_placed = true
	var map_rows: Array = DungeonLevels.get_level(GameState.dungeon_level).map
	var face := _wall_face
	var side := Vector3(-_inward.z, 0.0, _inward.x)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	world().add_child(body)
	for k in [0, -1, 1, -2, 2]:
		if _coffins.size() >= 3:
			break
		var spot: Vector3 = face + _inward * WALL_GAP + side * SPACING * k
		var spot_cell := DungeonBuilder.cell_of(spot)
		if not DungeonBuilder.is_walkable(map_rows, spot_cell.x, spot_cell.y):
			continue
		_coffins.append(spot)
		var coffin: Node3D = SARCOPHAGUS_SCENE.instantiate()
		world().add_child(coffin)
		coffin.global_position = Vector3(spot.x, DungeonBuilder.FLOOR_TOP, spot.z)
		coffin.rotation.y = atan2(_inward.x, _inward.z)
		# Виростає з-під підлоги.
		coffin.scale = Vector3(1.0, 0.05, 1.0)
		coffin.create_tween().tween_property(coffin, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		CombatVfx.impact_decal(world(), spot, 1.4, Color(0.8, 0.75, 0.65), 0.5)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = BOX
		shape.shape = box
		body.add_child(shape)
		shape.global_position = Vector3(spot.x, DungeonBuilder.FLOOR_TOP + BOX.y * 0.5, spot.z)
		shape.global_rotation.y = coffin.rotation.y

func tick(delta: float) -> void:
	super.tick(delta)
	if _home == Vector3.INF:
		_home = enemy.global_position
	match _step:
		Step.WALK:
			_time_left -= delta
			var offset := _target - enemy.global_position
			offset.y = 0.0
			if offset.length() < 0.35 or _time_left <= 0.0:
				_step = Step.UNLOCK
				_time_left = float(config.get("unlock", 3.0))
				enemy.velocity = Vector3.ZERO
				enemy.face_point(enemy.global_position - _inward)
				_place_coffins()
				return
			# Іде з фізикою: стіни й меблі не проходить наскрізь.
			var speed := float(config.get("speed", 4.0))
			enemy.velocity = Vector3(offset.normalized().x * speed, -2.0, offset.normalized().z * speed)
			enemy.move_and_slide()
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
		var spot: Vector3 = _coffins[i % _coffins.size()] + _inward * 1.4 if not _coffins.is_empty() else enemy.global_position + _inward * 2.0
		# Віко злітає — клуб пилу з саркофага.
		CombatVfx.shockwave(world(), spot, 1.6, Color(0.75, 0.7, 0.62, 0.8), 0.4)
		enemy.spawn_requested.emit(spot, definition, enemy)
	AudioManager.play(&"explosion", 0.05)
	_free_hero()

func _free_hero() -> void:
	var hero := player()
	if hero != null and is_instance_valid(hero) and hero.has_method("end_stun"):
		hero.end_stun()

static func _find(level: Dictionary, name: String) -> Dictionary:
	for group: Array in level.enemies.values():
		for definition: Dictionary in group:
			if String(definition.get("name", "")) == name:
				return definition
	return {}

func on_death() -> void:
	if _step != Step.IDLE:
		_free_hero()
	_step = Step.IDLE
