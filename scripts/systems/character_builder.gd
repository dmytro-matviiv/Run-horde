extends RefCounted
class_name CharacterBuilder

## ЗБИРАЧ ПЕРСОНАЖА: одне тіло (Universal Base Characters) + зовнішність
## (зачіска, борода, кольори) + броня частинами (Modular Character
## Outfits — Fantasy). Усі частини мають той самий скелет, тож броня сідає
## на будь-якого створеного персонажа однаково.
##
## Під надітою річчю ділянка тіла ХОВАЄТЬСЯ (трикутники, чиї вершини
## тримають кістки цієї ділянки, викидаються з меша тіла) — інакше
## м'язисте тіло проступало б крізь одяг.
##
## look — зовнішність (див. DEFAULT_LOOK), gear — слот -> вигляд речі:
##   {"parts": ["Ranger_Body", ...], "tint": Color, "rarity": "rare"}
## Назви частин без статі ("Ranger_Body") — стать додається сама.

const PEOPLE := "res://assets/models/haven/people/"
const OUTFITS := "res://assets/models/character/outfits/"

const BODIES := {"male": "Superhero_Male_FullBody", "female": "Superhero_Female_FullBody"}
## Зачіски (файли UBC). "" — без волосся.
const HAIRS := ["", "Hair_Buzzed", "Hair_SimpleParted", "Hair_Long", "Hair_Buns", "Hair_BuzzedFemale"]
const HAIR_TITLES := ["Лиса", "Їжачок", "Проділ", "Довге", "Гульки", "Коротке"]
const SKIN_TONES := [Color(1.0, 0.92, 0.86), Color(0.96, 0.8, 0.68), Color(0.82, 0.62, 0.48), Color(0.6, 0.42, 0.3), Color(0.42, 0.28, 0.2)]
const HAIR_COLORS := [Color(0.12, 0.1, 0.09), Color(0.35, 0.22, 0.13), Color(0.62, 0.4, 0.2), Color(0.85, 0.7, 0.42),
	Color(0.85, 0.85, 0.85), Color(0.55, 0.12, 0.08), Color(0.25, 0.45, 0.8)]
const EYE_COLORS := [Color(0.45, 0.28, 0.15), Color(0.25, 0.5, 0.85), Color(0.3, 0.6, 0.3), Color(0.5, 0.5, 0.5), Color(0.7, 0.45, 0.1)]

const DEFAULT_LOOK := {"gender": "male", "skin": 1, "hair": 1, "hair_color": 1, "beard": false, "eyes": 0}

## Яку ділянку тіла закриває частина броні (за закінченням назви).
const PART_REGIONS := {"_Body": "torso", "_Arms": "arms", "_Legs": "legs", "_Feet": "feet", "_Head_Hood": "head"}
## Кістки кожної ділянки (скелет UBC — як в Unreal).
const REGION_BONES := {
	"torso": ["spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"],
	"arms": ["upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"],
	"legs": ["pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r"],
	"feet": ["foot_l", "foot_r", "ball_l", "ball_r", "ball_leaf_l", "ball_leaf_r"],
	"head": [],
}

## Кольори рідкості: на що "фарбується" річ (множення кольору).
const RARITY_TINTS := {
	"common": Color(0.82, 0.8, 0.78),
	"uncommon": Color(0.72, 0.95, 0.68),
	"rare": Color(0.66, 0.8, 1.05),
	"epic": Color(0.88, 0.66, 1.05),
	"legendary": Color(1.08, 0.96, 0.72),
}

## Тіло з прихованими ділянками: (стать|ділянки) -> ArrayMesh.
static var _masked := {}

## Зібрати персонажа. Повертає корінь із Skeleton3D всередині.
static func build(look: Dictionary, gear: Dictionary = {}) -> Node3D:
	var gender: String = look.get("gender", "male")
	var root: Node3D = load(PEOPLE + BODIES.get(gender, BODIES.male) + ".gltf").instantiate()
	root.name = "Character"
	var skeleton: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]

	# Які ділянки закриті бронею.
	var covered := {}
	var hidden_hair := false
	for slot: String in gear:
		for part: String in (gear[slot] as Dictionary).get("parts", []):
			for suffix: String in PART_REGIONS:
				if part.contains(suffix):
					covered[PART_REGIONS[suffix]] = true
			if part.contains("Head") or slot == "helmet":
				hidden_hair = true

	for node in skeleton.get_children():
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		if mesh.name.begins_with("Super"):
			_paint_skin(mesh, SKIN_TONES[clampi(int(look.get("skin", 1)), 0, SKIN_TONES.size() - 1)])
			if not covered.is_empty():
				mesh.mesh = _masked_body(gender, mesh, skeleton, covered.keys())
		elif mesh.name == "Eyes":
			_tint(mesh, EYE_COLORS[clampi(int(look.get("eyes", 0)), 0, EYE_COLORS.size() - 1)])

	var hair_color: Color = HAIR_COLORS[clampi(int(look.get("hair_color", 1)), 0, HAIR_COLORS.size() - 1)]
	var hair: String = HAIRS[clampi(int(look.get("hair", 1)), 0, HAIRS.size() - 1)]
	if hair != "" and not hidden_hair:
		_attach(PEOPLE + hair + ".gltf", skeleton, hair_color)
	if look.get("beard", false) and gender == "male":
		_attach(PEOPLE + "Hair_Beard.gltf", skeleton, hair_color)
	for mesh in skeleton.get_children():
		if mesh is MeshInstance3D and mesh.name == "Eyebrows":
			_tint(mesh as MeshInstance3D, hair_color)

	var prefix := "Female_" if gender == "female" else "Male_"
	for slot: String in gear:
		var item: Dictionary = gear[slot]
		var tint: Color = item.get("tint", RARITY_TINTS.get(item.get("rarity", "common"), Color.WHITE))
		for part: String in item.get("parts", []):
			var path := OUTFITS + prefix + _gender_part(part, gender) + ".gltf"
			if ResourceLoader.exists(path):
				_attach(path, skeleton, tint, item.get("rarity", "common"))
	return root

## Деякі частини в чоловічому й жіночому варіанті звуться трохи інакше.
static func _gender_part(part: String, gender: String) -> String:
	if gender == "female":
		return part.replace("Feet_Boots", "Feet").replace("Acc_Pauldron", "Acc_Pauldrons")
	return part

static func _attach(path: String, skeleton: Skeleton3D, tint: Color, rarity: String = "") -> void:
	var scene: Node3D = load(path).instantiate()
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		mesh.get_parent().remove_child(mesh)
		skeleton.add_child(mesh)
		mesh.skeleton = NodePath("..")
		_tint(mesh, tint, rarity)
	scene.free()

## Перефарбувати всі матеріали меша (копії — оригінал спільний).
static func _tint(mesh: MeshInstance3D, tint: Color, rarity: String = "") -> void:
	for surface in mesh.mesh.get_surface_count():
		var source := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
		if source == null:
			continue
		var material: BaseMaterial3D = source.duplicate()
		var name := source.resource_name.to_lower()
		# Шкіру на одязі (руки, ноги в шортах) фарбує колір шкіри, не рідкості.
		if name.contains("regular") or name.contains("skin") or name.contains("superhero"):
			mesh.set_surface_override_material(surface, material)
			continue
		material.albedo_color = source.albedo_color * tint
		if rarity == "legendary":
			material.emission_enabled = true
			material.emission = Color(1.0, 0.75, 0.3)
			material.emission_energy_multiplier = 0.05
		elif rarity == "epic":
			material.rim_enabled = true
			material.rim = 0.6
			material.rim_tint = 0.8
		mesh.set_surface_override_material(surface, material)

static func _paint_skin(mesh: MeshInstance3D, tone: Color) -> void:
	for surface in mesh.mesh.get_surface_count():
		var source := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
		if source == null:
			continue
		var material: BaseMaterial3D = source.duplicate()
		material.albedo_color = source.albedo_color * tone
		mesh.set_surface_override_material(surface, material)

## Тіло без ділянок, закритих бронею (кешується).
static func _masked_body(gender: String, mesh: MeshInstance3D, skeleton: Skeleton3D, regions: Array) -> ArrayMesh:
	regions.sort()
	var key := gender + "|" + ",".join(regions)
	if _masked.has(key):
		return _masked[key]
	var hide := {}
	for region: String in regions:
		for bone_name: String in REGION_BONES.get(region, []):
			var index := skeleton.find_bone(bone_name)
			if index >= 0:
				hide[index] = true
	var source := mesh.mesh
	var skin := mesh.skin
	var result := ArrayMesh.new()
	# Морф-цілі обличчя (у жіночого тіла) мусять бути й у новій сітці.
	result.blend_shape_mode = (source as ArrayMesh).blend_shape_mode if source is ArrayMesh else Mesh.BLEND_SHAPE_MODE_NORMALIZED
	for shape in source.get_blend_shape_count():
		result.add_blend_shape(source.get_blend_shape_name(shape))
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var per := bones.size() / maxi(count, 1)
		# Головна кістка вершини (через Skin: індекс прив'язки -> кістка).
		var covered := PackedByteArray()
		covered.resize(count)
		for v in count:
			var best := 0
			var best_w := -1.0
			for k in per:
				if weights[v * per + k] > best_w:
					best_w = weights[v * per + k]
					best = bones[v * per + k]
			var bone := skin.get_bind_bone(best) if skin != null and best < skin.get_bind_count() else best
			if skin != null and bone < 0:
				bone = skeleton.find_bone(skin.get_bind_name(best))
			covered[v] = 1 if hide.has(bone) else 0
		var kept := PackedInt32Array()
		for t in range(0, indices.size(), 3):
			if covered[indices[t]] and covered[indices[t + 1]] and covered[indices[t + 2]]:
				continue
			kept.append(indices[t])
			kept.append(indices[t + 1])
			kept.append(indices[t + 2])
		arrays[Mesh.ARRAY_INDEX] = kept
		# Додаткові канали (custom) тілу не потрібні, а без їхнього формату
		# сітка не створюється.
		for channel in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arrays[channel] = null
		var flags: int = source.call("surface_get_format", surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		var shapes: Array = source.surface_get_blend_shape_arrays(surface) if source is ArrayMesh else []
		for shape: Array in shapes:
			shape[Mesh.ARRAY_INDEX] = null
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes, {}, flags)
		result.surface_set_material(surface, source.surface_get_material(surface))
	_masked[key] = result
	return result
