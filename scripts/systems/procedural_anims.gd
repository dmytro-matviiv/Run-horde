extends RefCounted
class_name ProceduralAnims

## ПРОЦЕДУРНІ АНІМАЦІЇ: удари, яких немає в моделі героя, збираються кодом
## прямо зі скелета, коли герой з'являється. Окремих файлів анімацій
## немає — рух описано ключовими кадрами тут, у коді, і його легко
## підправити.
##
## Опис однієї анімації: {"length": с, "keys": {час: поза}}, поза —
## {кістка: {"x": .., "y": .., "z": .., "loc": Vector3}}. Кут (градуси) —
## поворот кістки разом з усім, що на ній, навколо осі ГЕРОЯ від спокійної
## пози base (стійка з мечем):
##   x — нахил уперед (+); рука/нога вперед-угору (−);
##   y — поворот ліворуч (+), праворуч (−);
##   z — нахил ліворуч (+), праворуч (−); праву руку вбік-угору піднімає −.
## "loc" — зсув таза (Hips) у метрах: x — ліворуч, y — угору, z — уперед.
## Кістки без ключа в кадрі стоять, як у base; ноги без жодного ключа
## лишаються за рухом героя (біг під час удару).

## Кістки, що завжди в анімації (верх тіла): інакше під час удару руки
## махали б за бігом.
const UPPER_BODY := ["Hips", "Abdomen", "Torso", "Chest", "Neck", "Head", "Shoulder.R", "UpperArm.R",
	"LowerArm.R", "Wrist.R", "Shoulder.L", "UpperArm.L", "LowerArm.L", "Wrist.L"]
const ROOT_BONE := "Hips"

## Додає анімації з specs у бібліотеку плеєра (назва — prefix + ключ).
static func build(player: AnimationPlayer, base_name: String, specs: Dictionary, prefix: String = "") -> void:
	if not player.has_animation(base_name):
		push_warning("ProceduralAnims: немає базової анімації %s" % base_name)
		return
	var root: Node = player.get_node(player.root_node)
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var skeleton_path := String(root.get_path_to(skeleton))
	var base := player.get_animation(base_name)
	var base_rotation := {}
	var base_position := {}
	for bone in skeleton.get_bone_count():
		base_rotation[bone] = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		base_position[bone] = skeleton.get_bone_rest(bone).origin
	for track in base.get_track_count():
		var bone := skeleton.find_bone(String(base.track_get_path(track).get_concatenated_subnames()))
		if bone < 0:
			continue
		match base.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				base_rotation[bone] = base.rotation_track_interpolate(track, 0.0)
			Animation.TYPE_POSITION_3D:
				base_position[bone] = base.position_track_interpolate(track, 0.0)
	# Орієнтація кожної кістки в просторі скелета в базовій позі.
	var global_rotation := {}
	for bone in skeleton.get_bone_count():
		_global_rotation(skeleton, bone, base_rotation, global_rotation)
	# Осі героя -> осі скелета (у моделі скелет буває повернутий і масштабований).
	var to_model := _relative_basis(root, skeleton)
	var model_to_skeleton := to_model.get_rotation_quaternion().inverse()
	var scale := to_model.get_scale().x
	var library := player.get_animation_library("")
	for name: String in specs:
		var spec: Dictionary = specs[name]
		var keys: Dictionary = spec.keys
		var times: Array = keys.keys()
		times.sort()
		var animation := Animation.new()
		animation.length = float(spec.length)
		var bones: Array = UPPER_BODY.duplicate()
		for time: float in times:
			for bone_name: String in keys[time]:
				if not bones.has(bone_name):
					bones.append(bone_name)
		for bone_name: String in bones:
			var bone := skeleton.find_bone(bone_name)
			if bone < 0:
				continue
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath(skeleton_path + ":" + bone_name))
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
			var global: Quaternion = global_rotation[bone]
			for time: float in times:
				var offset := _offset(keys[time].get(bone_name, {}), model_to_skeleton)
				var local: Quaternion = base_rotation[bone] * (global.inverse() * offset * global)
				animation.rotation_track_insert_key(track, time, local.normalized())
		var root_bone := skeleton.find_bone(ROOT_BONE)
		var moves := false
		for time: float in times:
			if keys[time].get(ROOT_BONE, {}).has("loc"):
				moves = true
		if moves and root_bone >= 0:
			var track := animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(track, NodePath(skeleton_path + ":" + ROOT_BONE))
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
			var parent := skeleton.get_bone_parent(root_bone)
			var parent_rotation: Quaternion = global_rotation[parent] if parent >= 0 else Quaternion()
			for time: float in times:
				var shift: Vector3 = keys[time].get(ROOT_BONE, {}).get("loc", Vector3.ZERO)
				var local_shift := parent_rotation.inverse() * (model_to_skeleton * shift) / maxf(scale, 0.0001)
				animation.position_track_insert_key(track, time, base_position[root_bone] + local_shift)
		if library.has_animation(prefix + name):
			library.remove_animation(prefix + name)
		library.add_animation(prefix + name, animation)

## Поворот навколо осей героя (z, тоді y, тоді x) — в осях скелета.
static func _offset(spec: Dictionary, model_to_skeleton: Quaternion) -> Quaternion:
	var q := Quaternion()
	for axis: String in ["z", "y", "x"]:
		if spec.has(axis):
			var direction := Vector3.RIGHT if axis == "x" else (Vector3.UP if axis == "y" else Vector3.BACK)
			q = Quaternion(direction, deg_to_rad(float(spec[axis]))) * q
	return model_to_skeleton * q * model_to_skeleton.inverse()

static func _global_rotation(skeleton: Skeleton3D, bone: int, local: Dictionary, cache: Dictionary) -> Quaternion:
	if cache.has(bone):
		return cache[bone]
	var parent := skeleton.get_bone_parent(bone)
	var result: Quaternion = local[bone]
	if parent >= 0:
		result = _global_rotation(skeleton, parent, local, cache) * result
	cache[bone] = result
	return result

## Перетворення з простору вузла node у простір предка ancestor.
static func _relative_basis(ancestor: Node, node: Node3D) -> Basis:
	var basis := Basis()
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			basis = (current as Node3D).transform.basis * basis
		current = current.get_parent()
	return basis
