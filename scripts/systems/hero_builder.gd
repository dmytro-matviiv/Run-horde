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
## Повертає вузол причепленої зброї (або null, якщо лишився вбудований
## у модель меч) — з нього беремо кінчик ствола для пострілу.
static func attach_weapon(model: Node3D, hero: HeroDef, weapon: WeaponDef) -> Node3D:
	var scene: PackedScene = null
	if weapon != null:
		scene = ArtSlots.weapon_model(weapon.id, weapon.model_scene)
	# Вбудований меч лишаємо, лише коли в руках і так меч без власної
	# моделі. Інакше героїня тримала б дві зброї одразу.
	var builtin := model.find_child(String(hero.builtin_weapon_node), true, false)
	if builtin != null and builtin is Node3D:
		(builtin as Node3D).visible = weapon == null or (weapon.style_3d == "sword" and scene == null)
	if weapon == null:
		return null
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return null
	var skeleton := skeletons[0] as Skeleton3D
	var bone := skeleton.find_bone(String(hero.weapon_bone))
	if bone < 0:
		return null
	if scene == null and weapon.style_3d == "sword":
		return null   # у моделі вже є меч — лишаємо його

	# Кістки моделі мають власний масштаб, тож зброю зводимо до метрів.
	var bone_scale: float = skeleton.global_transform.basis.get_scale().x
	var grip := Transform3D(
		Basis.from_euler(weapon.grip_rotation_deg * (PI / 180.0)).scaled(Vector3.ONE * weapon.model_scale / maxf(bone_scale, 0.0001)),
		weapon.grip_offset)
	if weapon.upright_3d:
		# Посох чаклуна — рівно вертикально, рука лише тримає (UprightGrip).
		var holder := UprightGrip.wrap(_make_weapon(scene, weapon), model, weapon.model_scale / maxf(bone_scale, 0.0001))
		_hold(skeleton, bone, holder, Transform3D.IDENTITY)
		return holder.get_child(0) as Node3D
	var weapon_node := _hold(skeleton, bone, _make_weapon(scene, weapon), grip)
	if weapon.dual_wield:
		var other := skeleton.find_bone(String(hero.offhand_bone))
		if other >= 0:
			var copy := _hold(skeleton, other, _make_weapon(scene, weapon), _mirrored_grip(skeleton, bone, other, grip))
			# Друга рука теж "стріляє" (карти летять із тієї руки, що кидає).
			weapon_node.set_meta(&"offhand", copy)
	return weapon_node

static func _make_weapon(scene: PackedScene, weapon: WeaponDef) -> Node3D:
	if scene != null:
		return scene.instantiate()
	return WeaponModels.build(weapon.style_3d, weapon.color)

## Чіпляє зброю до кістки: вона рухається разом із рукою в анімаціях.
static func _hold(skeleton: Skeleton3D, bone: int, weapon_node: Node3D, grip: Transform3D) -> Node3D:
	var attachment := BoneAttachment3D.new()
	attachment.bone_idx = bone
	skeleton.add_child(attachment)
	attachment.add_child(weapon_node)
	weapon_node.transform = grip
	return weapon_node

## Хват для лівої руки — дзеркало правого відносно площини симетрії
## героя. Рахуємо за спокійною позою скелета (вона симетрична), тож
## підганяти ліву руку окремо не треба.
static func _mirrored_grip(skeleton: Skeleton3D, bone: int, other: int, grip: Transform3D) -> Transform3D:
	var mirror := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	var held := skeleton.get_bone_global_rest(bone) * grip
	var mirrored := Transform3D(mirror * held.basis * mirror, mirror * held.origin)
	return skeleton.get_bone_global_rest(other).affine_inverse() * mirrored

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
