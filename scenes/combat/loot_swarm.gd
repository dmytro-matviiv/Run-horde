extends Node3D
class_name LootSwarm

## Здобич, що вилітає з убитого ворога й летить до героя: золоті
## самородки й блакитні кристали досвіду.
##
## Спершу шматочки розлітаються фонтаном і підскакують на підлозі, потім
## їх притягує до героя — і щойно долетів, золото чи досвід
## зараховується (сигнал collected). Так вбивство видно й чутно: дзенькіт
## монет, лічильник росте в ту мить, коли здобич долетіла.
##
## ДЛЯ ТЕЛЕФОНА: усі шматочки — це ОДИН MultiMesh, один виклик малювання,
## скільки б їх не літало. Окремих вузлів на кожну монету немає.

signal collected(kind: int, amount: int)

enum Kind {GOLD, XP}

const CAPACITY := 160
## Скільки секунд шматочок летить фонтаном, перш ніж його притягне.
const BURST_TIME := 0.38
const GRAVITY := 16.0
const FLOOR_Y := 0.22
## Швидкість притягування: стартова й приріст за секунду.
const HOMING_SPEED := 5.0
const HOMING_ACCEL := 30.0
const HOMING_MAX := 24.0
const COLLECT_DISTANCE := 0.55
## Шматочки, що зачепились за стіну чи загубились, долітають силоміць.
const MAX_AGE := 3.0

const COLORS := {Kind.GOLD: Color(1.0, 0.84, 0.18), Kind.XP: Color(0.35, 0.95, 1.0)}
const SIZES := {Kind.GOLD: 1.0, Kind.XP: 0.85}

var _target: Node3D
var _pieces: Array[Dictionary] = []
var _multimesh: MultiMesh
var _instance: MultiMeshInstance3D

func setup(target: Node3D) -> void:
	_target = target

func _ready() -> void:
	var mesh := SphereMesh.new()
	# Чотири сегменти по колу й два по висоті — гранчастий "самоцвіт".
	mesh.radius = 0.16
	mesh.height = 0.38
	mesh.radial_segments = 4
	mesh.rings = 2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	mesh.material = material

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = mesh
	_multimesh.instance_count = CAPACITY
	_multimesh.visible_instance_count = 0
	_instance = MultiMeshInstance3D.new()
	_instance.multimesh = _multimesh
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Шматочки розкидані по всьому рівню, а межі пакета рахувати щокадру
	# дорого — тож межі свідомо величезні: відкидати нема чого.
	_instance.custom_aabb = AABB(Vector3(-1000, -50, -1000), Vector3(2000, 100, 2000))
	_instance.visible = false
	add_child(_instance)

## Фонтан здобичі: total золота чи досвіду, поділений на pieces шматочків.
func burst(position: Vector3, kind: int, total: int, pieces: int) -> void:
	if total <= 0:
		return
	pieces = clampi(pieces, 1, total)
	var share := total / pieces
	for i in pieces:
		var amount := share + (total - share * pieces if i == pieces - 1 else 0)
		if _pieces.size() >= CAPACITY:
			# Місця немає — зараховуємо одразу, здобич не губиться.
			collected.emit(kind, amount)
			continue
		var angle := randf() * TAU
		var outward := randf_range(1.2, 3.2)
		_pieces.append({
			"kind": kind,
			"amount": amount,
			"position": position + Vector3(0, 0.6, 0),
			"velocity": Vector3(cos(angle) * outward, randf_range(4.0, 6.5), sin(angle) * outward),
			"age": 0.0,
			"speed": HOMING_SPEED,
			"spin": randf() * TAU,
		})
	_instance.visible = true

## Показати один шматочок на мить — щоб шейдер зібрався під екраном
## завантаження, а не на першому вбивстві.
func warm_up(position: Vector3) -> void:
	_pieces.append({"kind": -1, "amount": 0, "position": position, "velocity": Vector3.ZERO,
		"age": MAX_AGE - 0.3, "speed": 0.0, "spin": 0.0})
	_instance.visible = true

func _physics_process(delta: float) -> void:
	if _pieces.is_empty():
		return
	var goal := _target.global_position + Vector3(0, 0.9, 0) if is_instance_valid(_target) else Vector3.ZERO
	var index := 0
	while index < _pieces.size():
		var piece: Dictionary = _pieces[index]
		piece.age += delta
		piece.spin += delta * 7.0
		if piece.kind == -1:
			if piece.age >= MAX_AGE:
				_pieces.remove_at(index)
				continue
		elif piece.age < BURST_TIME:
			var velocity: Vector3 = piece.velocity
			velocity.y -= GRAVITY * delta
			var position: Vector3 = piece.position + velocity * delta
			if position.y < FLOOR_Y:
				position.y = FLOOR_Y
				velocity.y = absf(velocity.y) * 0.35
				velocity.x *= 0.6
				velocity.z *= 0.6
			piece.velocity = velocity
			piece.position = position
		else:
			piece.speed = minf(piece.speed + HOMING_ACCEL * delta, HOMING_MAX)
			var offset: Vector3 = goal - piece.position
			var step: float = piece.speed * delta
			if offset.length() <= maxf(COLLECT_DISTANCE, step) or piece.age >= MAX_AGE:
				_pieces.remove_at(index)
				collected.emit(piece.kind, piece.amount)
				continue
			piece.position += offset.normalized() * step
		index += 1
	_draw_pieces()

func _draw_pieces() -> void:
	_multimesh.visible_instance_count = _pieces.size()
	for i in _pieces.size():
		var piece: Dictionary = _pieces[i]
		var kind: int = maxi(piece.kind, 0)
		# Шматочок крутиться й трохи "дихає" — так він блищить.
		var pulse: float = 1.0 + 0.15 * sin(piece.spin * 1.7)
		var basis := Basis(Vector3.UP, piece.spin).scaled(Vector3.ONE * SIZES[kind] * pulse)
		_multimesh.set_instance_transform(i, Transform3D(basis, piece.position))
		_multimesh.set_instance_color(i, COLORS[kind])
	if _pieces.is_empty():
		_instance.visible = false
