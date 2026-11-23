extends Node3D
class_name UprightGrip

## Посох у руці чаклуна: рука його тримає (посох іде за кистю), але стоїть
## він РІВНО — вертикально вгору від землі, лише трохи нахилений уперед,
## як у справжніх чарівників. Поворот кисті в анімації на нього не впливає,
## тож посох не лізе в голову, хоч би що робила рука.
##
## Вузол висить на кістці кисті (BoneAttachment3D), але top_level — поворот
## кістки не успадковує (інакше посох хитався б із запізненням на кадр).
## Модель посоха — його дитина без власного повороту. Щокадру ставимо
## світове положення самі: точка — кисть, поворот — лише свій, рівний.

## Нахил верхівки вперед, градуси.
const LEAN_DEG := 6.0
## Де рука тримає посох: частка довжини від низу.
const HOLD_AT := 0.45
## Ближче до осі тіла посох не підходить (метри) — щоб не пройшов крізь
## голову, коли рука перед грудьми: його відсуває вбік, на праву руку.
const MIN_SIDE := 0.36

## Корінь моделі героя — звідти беремо, куди він дивиться.
var body: Node3D
## Масштаб посоха відносно масштабу кисті (як у звичайному хваті).
var scale_ratio := 1.0
## Точка хвату в координатах моделі посоха (на її довгій осі Y).
var hold_point := Vector3.ZERO
## Посох — крізь кулак: на стільки метрів від зап'ястя вздовж пальців
## (0 — у зап'ясті, як у старих героїв).
var fingers := 0.0

## Обгортає вже зібрану модель посоха.
static func wrap(staff: Node3D, model_root: Node3D, ratio: float) -> UprightGrip:
	var grip := UprightGrip.new()
	grip.body = model_root
	grip.scale_ratio = ratio
	grip.add_child(staff)
	staff.transform = Transform3D.IDENTITY
	grip.hold_point = _hold_point(staff)
	return grip

func _ready() -> void:
	top_level = true
	process_priority = 100   # після анімації (кістки вже на місці)
	_place()

func _process(_delta: float) -> void:
	_place()

func _place() -> void:
	var hand := get_parent() as Node3D
	if hand == null or body == null or not is_instance_valid(body):
		return
	var yaw := Basis(Vector3.UP, body.global_rotation.y)
	var basis := Basis(yaw.x, deg_to_rad(LEAN_DEG)) * yaw
	var world_scale := scale_ratio * hand.global_basis.get_scale().x
	var scaled := basis.scaled(Vector3.ONE * world_scale)
	# Кисть — з пози кістки (BoneAttachment може ще не оновитись у цьому кадрі).
	var at := hand.global_position
	var attachment := hand as BoneAttachment3D
	if attachment != null and attachment.get_parent() is Skeleton3D:
		var skeleton := attachment.get_parent() as Skeleton3D
		var pose := skeleton.get_bone_global_pose(attachment.bone_idx)
		# Центр кулака: уздовж пальців (+Y кисті) і трохи в бік долоні.
		var inv := 1.0 / maxf(skeleton.global_transform.basis.get_scale().x, 0.0001)
		var palm := 0.03 if String(skeleton.get_bone_name(attachment.bone_idx)).ends_with("_l") else -0.03
		at = skeleton.global_transform * (pose.origin + (pose.basis.y.normalized() * fingers + pose.basis.x.normalized() * palm) * inv)
	# Відстань від осі тіла (по горизонталі). Замало — відсуваємо назовні,
	# змішуючи напрямок руки з правим боком героя.
	var axis := body.global_position
	var flat := Vector3(at.x - axis.x, 0.0, at.z - axis.z)
	# Свій герой тримає посох опущеною рукою збоку — відступ менший.
	var min_side := MIN_SIDE if fingers == 0.0 else 0.2
	if flat.length() < min_side:
		# Відсуваємо в бік руки, що тримає (а не на праву: посох у лівій
		# опинявся за спиною).
		var right := -yaw.x
		var outward := flat.normalized() if flat.length() > 0.05 else right
		if fingers == 0.0:
			outward = outward.lerp(right, 0.5).normalized()
		at = Vector3(axis.x, at.y, axis.z) + outward * min_side
	global_transform = Transform3D(scaled, at - scaled * hold_point)

## Точка хвату: на осі посоха (Y моделі) на HOLD_AT довжини від низу.
static func _hold_point(staff: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for node in staff.find_children("*", "MeshInstance3D", true, false) + ([staff] if staff is MeshInstance3D else []):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var local := _relative(staff, mesh) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	if first:
		return Vector3.ZERO
	var center := box.get_center()
	return Vector3(center.x, box.position.y + box.size.y * HOLD_AT, center.z)

static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf
