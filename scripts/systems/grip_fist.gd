extends SkeletonModifier3D
class_name GripFist

## РУКА ЗІ ЗБРОЄЮ — поверх будь-якої анімації:
##  - кулак: пальці зімкнуті як у лівій руці Idle_Torch (там рука справді
##    стискає держак); для правої руки — той самий кулак, віддзеркалений;
##  - wrist_tilt: кисть опущена (ліктьове відведення) — у спокої меч
##    дивиться лезом униз-вперед, як у лицаря на картині;
##  - torch_arm: уся рука (ключиця, плече, передпліччя, кисть) — у позі
##    Idle_Torch: зігнута, кисть біля грудей; так маг тримає посох рівно
##    і в місті, і в бою (друга рука вільна для чар).

const SOURCE := "res://assets/animations/character/Idle_Torch.res"
const FINGERS := ["index", "middle", "ring", "pinky", "thumb"]
const ARM := ["clavicle", "upperarm", "lowerarm", "hand"]
## Як віддзеркалити кватерніон лівої кістки на праву.
static var MIRROR := Vector4(1, -1, -1, 1)

var side := "_r"
var wrist_tilt := 0.0
var torch_arm := false

## Сторона -> {кістка: поворот} (кулак) і рука смолоскипа (лише ліва).
static var _fists := {}
static var _arm := {}
var _bones: Array = []
var _arm_bones: Array = []
var _hand := -1

static func _source() -> Animation:
	return load(SOURCE)

static func _fist(side_suffix: String) -> Dictionary:
	if _fists.has(side_suffix):
		return _fists[side_suffix]
	var result := {}
	var anim := _source()
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(anim.track_get_path(t)).get_slice(":", 1)
		for finger: String in FINGERS:
			if bone_name.begins_with(finger + "_") and bone_name.ends_with("_l") and not bone_name.contains("leaf"):
				var q := anim.rotation_track_interpolate(t, 0.0)
				if side_suffix == "_r":
					q = Quaternion(q.x * MIRROR.x, q.y * MIRROR.y, q.z * MIRROR.z, q.w * MIRROR.w)
				result[bone_name.trim_suffix("_l") + side_suffix] = q
	_fists[side_suffix] = result
	return result

static func _torch_arm() -> Dictionary:
	if not _arm.is_empty():
		return _arm
	var anim := _source()
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(anim.track_get_path(t)).get_slice(":", 1)
		if not bone_name.ends_with("_l"):
			continue
		for part: String in ARM:
			if bone_name.begins_with(part):
				_arm[bone_name] = anim.rotation_track_interpolate(t, 0.0)
	return _arm

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if _bones.is_empty():
		var pose := _fist(side)
		for bone_name: String in pose:
			var bone := skeleton.find_bone(bone_name)
			if bone >= 0:
				_bones.append([bone, pose[bone_name]])
		_hand = skeleton.find_bone("hand" + side)
		if torch_arm and side == "_l":
			var arm := _torch_arm()
			for bone_name: String in arm:
				var bone := skeleton.find_bone(bone_name)
				if bone >= 0:
					_arm_bones.append([bone, arm[bone_name]])
	for entry: Array in _arm_bones:
		skeleton.set_bone_pose_rotation(entry[0], entry[1])
	for entry: Array in _bones:
		skeleton.set_bone_pose_rotation(entry[0], entry[1])
	if wrist_tilt != 0.0 and _hand >= 0:
		var q := skeleton.get_bone_pose_rotation(_hand)
		skeleton.set_bone_pose_rotation(_hand, q * Quaternion(Vector3.RIGHT, deg_to_rad(wrist_tilt)))
