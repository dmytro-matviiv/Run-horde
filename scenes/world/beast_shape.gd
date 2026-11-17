extends SkeletonModifier3D

## Переробляє тіло звіра поверх анімації: множить масштаб кісток (діти
## кістки масштабуються разом із нею). Так з вовка виходить ведмідь:
## короткі товсті лапи, круглі вуха, масивна голова й груди, куций хвіст.
## shape: назва кістки -> множник масштабу. Для вух беремо корінь ланцюжка.

var shape := {}

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for bone_name: String in shape:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var factor: Vector3 = shape[bone_name]
		skeleton.set_bone_pose_scale(bone, skeleton.get_bone_pose_scale(bone) * factor)

## Корені ланцюжків (кістка, чий батько має іншу назву-основу) — щоб
## зменшити, наприклад, усе вухо, а не тільки кінчик.
static func chain_roots(skeleton: Skeleton3D, prefix: String) -> Array[String]:
	var roots: Array[String] = []
	for bone in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone)
		if not bone_name.begins_with(prefix):
			continue
		var parent := skeleton.get_bone_parent(bone)
		if parent < 0 or not skeleton.get_bone_name(parent).begins_with(prefix):
			roots.append(bone_name)
	return roots
