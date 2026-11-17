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

	var hidden_hair := false
	for slot: String in gear:
		for part: String in (gear[slot] as Dictionary).get("parts", []):
			if part.contains("Head") or slot == "helmet":
				hidden_hair = true

	var body: MeshInstance3D = null
	for node in skeleton.get_children():
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		if mesh.name.begins_with("Super"):
			body = mesh
			_paint_skin(mesh, SKIN_TONES[clampi(int(look.get("skin", 1)), 0, SKIN_TONES.size() - 1)])
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
	var garments: Array[MeshInstance3D] = []
	var part_names := []
	for slot: String in gear:
		var item: Dictionary = gear[slot]
		var tint: Color = item.get("tint", RARITY_TINTS.get(item.get("rarity", "common"), Color.WHITE))
		for part: String in item.get("parts", []):
			var path := OUTFITS + prefix + _gender_part(part, gender) + ".gltf"
			if ResourceLoader.exists(path):
				garments.append_array(_attach(path, skeleton, tint, item.get("rarity", "common")))
				part_names.append(part)
	# Шкіра під одягом ховається (інакше м'язисте тіло проступає крізь нього).
	if body != null and not garments.is_empty():
		part_names.sort()
		body.mesh = _masked_body(gender + "|" + ",".join(part_names), body, skeleton, garments)
	return root

## Деякі частини в чоловічому й жіночому варіанті звуться трохи інакше.
static func _gender_part(part: String, gender: String) -> String:
	if gender == "female":
		return part.replace("Feet_Boots", "Feet").replace("Acc_Pauldron", "Acc_Pauldrons")
	return part

static func _attach(path: String, skeleton: Skeleton3D, tint: Color, rarity: String = "") -> Array[MeshInstance3D]:
	var scene: Node3D = load(path).instantiate()
	var added: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		skeleton.add_child(mesh)
		mesh.skeleton = NodePath("..")
		_tint(mesh, tint, rarity)
		added.append(mesh)
	scene.free()
	return added

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

## Наскільки близько до одягу має бути шкіра, щоб сховатись (метри).
const COVER_RADIUS := 0.035
const HASH_CELL := 0.06

## Тіло без шкіри, закритої одягом (кешується за набором частин).
## Геометрично: вершина тіла ховається, якщо поруч (у позі спокою) є
## трикутник одягу. Так короткі штани не "з'їдають" гомілку, а довгий
## рукав ховає всю руку.
static func _masked_body(key: String, mesh: MeshInstance3D, skeleton: Skeleton3D, garments: Array[MeshInstance3D]) -> ArrayMesh:
	if _masked.has(key):
		return _masked[key]
	# Трикутники одягу в позі спокою, розкладені по клітинках простору.
	var grid := {}
	var tris := PackedVector3Array()
	for garment in garments:
		for surface in garment.mesh.get_surface_count():
			var arrays := garment.mesh.surface_get_arrays(surface)
			var points := _rest_points(arrays, garment.skin, skeleton)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for t in range(0, indices.size(), 3):
				var a := points[indices[t]]
				var b := points[indices[t + 1]]
				var c := points[indices[t + 2]]
				var id := tris.size() / 3
				tris.append(a)
				tris.append(b)
				tris.append(c)
				var lo := (a.min(b).min(c) - Vector3.ONE * COVER_RADIUS) / HASH_CELL
				var hi := (a.max(b).max(c) + Vector3.ONE * COVER_RADIUS) / HASH_CELL
				for x in range(floori(lo.x), floori(hi.x) + 1):
					for y in range(floori(lo.y), floori(hi.y) + 1):
						for z in range(floori(lo.z), floori(hi.z) + 1):
							var cell := Vector3i(x, y, z)
							if not grid.has(cell):
								grid[cell] = PackedInt32Array()
							var list: PackedInt32Array = grid[cell]
							list.append(id)
							grid[cell] = list
	var source := mesh.mesh
	var result := ArrayMesh.new()
	# Морф-цілі обличчя (у жіночого тіла) мусять бути й у новій сітці.
	result.blend_shape_mode = (source as ArrayMesh).blend_shape_mode if source is ArrayMesh else Mesh.BLEND_SHAPE_MODE_NORMALIZED
	for shape in source.get_blend_shape_count():
		result.add_blend_shape(source.get_blend_shape_name(shape))
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var points := _rest_points(arrays, mesh.skin, skeleton)
		var covered := PackedByteArray()
		covered.resize(points.size())
		for v in points.size():
			var p := points[v]
			var cell := Vector3i(floori(p.x / HASH_CELL), floori(p.y / HASH_CELL), floori(p.z / HASH_CELL))
			if not grid.has(cell):
				continue
			for id: int in grid[cell]:
				var closest := _closest_on_triangle(p, tris[id * 3], tris[id * 3 + 1], tris[id * 3 + 2])
				if p.distance_squared_to(closest) < COVER_RADIUS * COVER_RADIUS:
					covered[v] = 1
					break
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

## Вершини меша в позі спокою скелета (як їх і малює гра без анімації).
static func _rest_points(arrays: Array, skin: Skin, skeleton: Skeleton3D) -> PackedVector3Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if skin == null or bones.is_empty():
		return vertices
	var out := PackedVector3Array()
	out.resize(vertices.size())
	var per := bones.size() / maxi(vertices.size(), 1)
	var matrices: Array[Transform3D] = []
	for bind in skin.get_bind_count():
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(bind))
		matrices.append(skeleton.get_bone_global_rest(maxi(bone, 0)) * skin.get_bind_pose(bind))
	for v in vertices.size():
		var p := Vector3.ZERO
		var total := 0.0
		for k in per:
			var w := weights[v * per + k]
			if w <= 0.0:
				continue
			p += (matrices[bones[v * per + k]] * vertices[v]) * w
			total += w
		out[v] = p / total if total > 0.0 else vertices[v]
	return out

static func _closest_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)
