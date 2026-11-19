extends SkeletonModifier3D
class_name GripFist

## Кулак на руці зі зброєю: поверх будь-якої анімації згинає пальці
## (вказівний, середній, безіменний, мізинець і великий) навколо руків'я.
## Без цього кисть з анімації спокою лишалась розкритою («окей» пальцями),
## а зброя висіла біля долоні.

## Сторона: "_r" — права рука, "_l" — ліва (щит).
var side := "_r"
## Вісь згину в локальних осях кістки пальця і кути по фалангах (градуси).
var axis := Vector3(1, 0, 0)
var angles := [62.0, 78.0, 55.0]
var thumb_axis := Vector3(0, 0, 1)
var thumb_angles := [25.0, 30.0, 20.0]

var _bones: Array = []

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if _bones.is_empty():
		for finger: String in ["index", "middle", "ring", "pinky", "thumb"]:
			for k in 3:
				var bone := skeleton.find_bone("%s_%02d%s" % [finger, k + 1, side])
				if bone >= 0:
					_bones.append([bone, finger == "thumb", k])
	for entry: Array in _bones:
		var thumb: bool = entry[1]
		var k: int = entry[2]
		var angle: float = float(thumb_angles[k] if thumb else angles[k])
		var bend := Quaternion((thumb_axis if thumb else axis).normalized(), deg_to_rad(angle))
		var rest := skeleton.get_bone_rest(entry[0]).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(entry[0], rest * bend)
