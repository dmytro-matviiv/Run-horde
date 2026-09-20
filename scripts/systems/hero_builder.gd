extends RefCounted
class_name HeroBuilder

## Збирає героя з даних: модель + зброя в руці.
##
## Одним і тим самим користуються бій і екрани вибору героя та зброї —
## тож у меню гравець бачить рівно те, чим гратиме.
##
## Якщо моделі героя ще немає, береться тимчасова, пофарбована в колір
## героя; якщо немає моделі зброї — вона збирається з простих фігур
## (WeaponModels). Див. ArtSlots — там усі "слоти" під майбутній арт.

## Модель героя. Другим значенням повертає true, якщо це тимчасова
## модель (щоб екран міг написати "модель ще не додана").
static func build_model(hero: HeroDef) -> Array:
	var scene := ArtSlots.hero_model(hero.id, hero.model_scene)
	var placeholder := scene == null
	if placeholder:
		var fallback := HeroPool.get_def(&"blade_warden")
		scene = ArtSlots.hero_model(fallback.id, fallback.model_scene)
	if scene == null:
		return [null, true]
	var instance: Node3D = scene.instantiate()
	if placeholder:
		tint(instance, hero.color)
	return [instance, placeholder]

## Фарбує тимчасову модель у колір героя: копіюємо матеріали (щоб не
## перефарбувати всіх героїв одразу) і підмішуємо колір.
static func tint(instance: Node3D, color: Color) -> void:
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material: StandardMaterial3D = source.duplicate()
			material.albedo_color = source.albedo_color.lerp(color, 0.55)
			mesh_instance.set_surface_override_material(surface, material)

## Вішає зброю на кістку руки. Вбудований у модель меч ховаємо, коли
## герой бере щось інше, — інакше він тримав би дві зброї.
static func attach_weapon(model: Node3D, hero: HeroDef, weapon: WeaponDef) -> void:
	var builtin := model.find_child(String(hero.builtin_weapon_node), true, false)
	if builtin != null and builtin is Node3D:
		(builtin as Node3D).visible = weapon == null or weapon.style_3d == "sword"
	if weapon == null:
		return
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var bone := skeleton.find_bone(String(hero.weapon_bone))
	if bone < 0:
		return

	var scene := ArtSlots.weapon_model(weapon.id, weapon.model_scene)
	var weapon_node: Node3D
	if scene != null:
		weapon_node = scene.instantiate()
	elif weapon.style_3d == "sword":
		return   # у моделі вже є меч — лишаємо його
	else:
		weapon_node = WeaponModels.build(weapon.style_3d, weapon.color)

	var attachment := BoneAttachment3D.new()
	attachment.bone_idx = bone
	skeleton.add_child(attachment)
	attachment.add_child(weapon_node)
	weapon_node.position = weapon.grip_offset
	weapon_node.rotation_degrees = weapon.grip_rotation_deg
	# Кістки моделі мають власний масштаб, тож зброю зводимо до метрів.
	var bone_scale: float = skeleton.global_transform.basis.get_scale().x
	weapon_node.scale = Vector3.ONE * weapon.model_scale / maxf(bone_scale, 0.0001)

## Вмикає спокійну анімацію — для вітрини в меню.
static func play_idle(model: Node3D) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	for name: String in ["CharacterArmature|Idle", "Idle"]:
		if player.has_animation(name):
			player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
			player.play(name)
			return
	if not player.get_animation_list().is_empty():
		player.play(player.get_animation_list()[0])
