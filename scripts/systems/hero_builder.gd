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
	# 13–17 поверхонь моделі -> одна (для телефона це найдорожче в герої).
	HeroMerge.apply(instance, scene.resource_path)
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
## Поправка хвату для руки бази UBC (hand_r): кістка повернута інакше,
## ніж зап'ястя старих героїв (Wrist.R), під які налаштовано grip зброї.
## Хват на тілі власного героя (кисть hand_r: пальці вздовж +Y, від мізинця
## до вказівного — +Z, долоня — у -X). Руків'я йде вздовж кулака (+Z),
## лезо виходить з боку вказівного пальця, ребро леза — за кісточками (+Y);
## точка хвату — посеред зігнутих пальців.
static var CHARACTER_GRIP_FIX := Transform3D(Basis(Vector3(0.0102, 0.9615, -0.2733), Vector3(-0.0358, 0.2736, 0.9612),
	Vector3(0.999, 0.0, 0.0372)), Vector3(-0.0314, 0.098, 0.003))

## Посох — у лівій руці (права вільна для чарів); рука в позі смолоскипа
## (GripFist.torch_arm): кисть біля грудей, посох рівно до землі — хват
## опущено на STAFF_DROP уздовж посоха.
const STAFF_DROP := 0.55
## Нахил кисті в спокої (місто, спорядження): клинок і лук — униз-вперед.
static var WRIST_TILT := -40.0

static func character_left_hand(weapon: WeaponDef) -> bool:
	return weapon != null and weapon.style_3d == "staff"

## Хват — точно в кулаці (центр кільця пальців, руків'я вздовж кулака).
static func character_grip(weapon: WeaponDef, _relaxed: bool = false) -> Transform3D:
	var fist := CHARACTER_GRIP_FIX
	if character_left_hand(weapon):
		return Transform3D(fist.basis, fist.origin - fist.basis.y * STAFF_DROP)
	return fist

## Руки свого героя після того, як зброю вдягнено: нахил кисті в спокої,
## поза смолоскипа для руки з посохом.
static func setup_character_hands(model: Node3D, weapon: WeaponDef, relaxed: bool) -> void:
	for fist: GripFist in model.find_children("GripFist*", "", true, false):
		# Посох стоїть сам (UprightGrip) — руку лишаємо анімації, кулак
		# стиснутий; поза смолоскипа більше не потрібна.
		if fist.side == "_l" and character_left_hand(weapon):
			fist.torch_arm = false
		elif fist.side == "_r" and relaxed and not character_left_hand(weapon):
			fist.wrist_tilt = WRIST_TILT

static func attach_weapon(model: Node3D, hero: HeroDef, weapon: WeaponDef, bone_override: StringName = &"",
		offhand_override: StringName = &"", grip_fix: Transform3D = Transform3D.IDENTITY, left_hand: bool = false) -> Node3D:
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
	var bone := skeleton.find_bone(String(bone_override if bone_override != &"" else hero.weapon_bone))
	if bone < 0:
		return null
	if scene == null and weapon.style_3d == "sword" and bone_override == &"":
		return null   # у моделі вже є меч — лишаємо його

	# Кістки моделі мають власний масштаб, тож зброю зводимо до метрів.
	var bone_scale: float = skeleton.global_transform.basis.get_scale().x
	var grip := grip_fix * Transform3D(
		Basis.from_euler(weapon.grip_rotation_deg * (PI / 180.0)).scaled(Vector3.ONE * weapon.model_scale / maxf(bone_scale, 0.0001)),
		weapon.grip_offset)
	if weapon.upright_3d:
		# Посох чаклуна — рівно вертикально, рука лише тримає (UprightGrip).
		var holder := UprightGrip.wrap(_make_weapon(scene, weapon), model, weapon.model_scale / maxf(bone_scale, 0.0001))
		var hold_bone := bone
		if left_hand:
			var left_bone := skeleton.find_bone(String(offhand_override if offhand_override != &"" else hero.offhand_bone))
			if left_bone >= 0:
				hold_bone = left_bone
				holder.fingers = 0.075
		_hold(skeleton, hold_bone, holder, Transform3D.IDENTITY)
		return holder.get_child(0) as Node3D
	# Зброя в лівій руці (посох): той самий хват, віддзеркалений.
	if left_hand:
		var left := skeleton.find_bone(String(offhand_override if offhand_override != &"" else hero.offhand_bone))
		if left >= 0:
			grip = _mirrored_grip(skeleton, bone, left, grip)
			bone = left
	var weapon_node := _hold(skeleton, bone, _make_weapon(scene, weapon), grip)
	# Свій герой: пальці стискаються в кулак навколо руків'я.
	if bone_override != &"":
		_add_fist(skeleton, "_l" if left_hand else "_r")
		if weapon.dual_wield or weapon.offhand_model != null:
			_add_fist(skeleton, "_l")
	if weapon.offhand_model != null:
		var hand := skeleton.find_bone(String(offhand_override if offhand_override != &"" else hero.offhand_bone))
		if hand >= 0:
			var shield_grip := Transform3D(Basis.from_euler(weapon.offhand_rotation_deg * (PI / 180.0)).scaled(
				Vector3.ONE * weapon.offhand_scale / maxf(bone_scale, 0.0001)), weapon.offhand_offset / maxf(bone_scale, 0.0001))
			weapon_node.set_meta(&"shield", _hold(skeleton, hand, weapon.offhand_model.instantiate(), shield_grip))
	if weapon.dual_wield:
		var other := skeleton.find_bone(String(offhand_override if offhand_override != &"" else hero.offhand_bone))
		if other >= 0:
			var copy := _hold(skeleton, other, _make_weapon(scene, weapon), _mirrored_grip(skeleton, bone, other, grip))
			# Друга рука теж "стріляє" (карти летять із тієї руки, що кидає).
			weapon_node.set_meta(&"offhand", copy)
	return weapon_node

static func _add_fist(skeleton: Skeleton3D, side: String) -> void:
	if skeleton.has_node("GripFist" + side):
		return
	var fist := GripFist.new()
	fist.name = "GripFist" + side
	fist.side = side
	skeleton.add_child(fist)

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
