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

## Колір тканини сетів: ним фарбується "гола шкіра", вшита в рукави й
## штани Quaternius (смужка біля пахви), — у сеті там тканина.
const SKIN_CLOTH := {"Sword1": Color(0.36, 0.25, 0.16), "Archer1": Color(0.2, 0.36, 0.15), "Mage1": Color(0.33, 0.15, 0.48),
	"Tank1": Color(0.18, 0.23, 0.35), "Druid1": Color(0.34, 0.24, 0.15)}

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
				garments.append_array(_attach(path, skeleton, tint, item.get("rarity", "common"), String(item.get("skin", ""))))
				part_names.append(part)
	# Шкіра під одягом ховається (інакше м'язисте тіло проступає крізь нього).
	if body != null and not garments.is_empty():
		part_names.sort()
		# Чоботи: стопа вся всередині — шкіру стоп ховаємо повністю (інакше
		# пальці визирають крізь носок чобота).
		var boots := false
		for part: String in part_names:
			if part.contains("Feet") or part.contains("Boots"):
				boots = true
		body.mesh = _masked_body(gender + "|" + ",".join(part_names), body, skeleton, garments, boots)
	return root

## Деякі частини в чоловічому й жіночому варіанті звуться трохи інакше.
static func _gender_part(part: String, gender: String) -> String:
	if gender == "female":
		return part.replace("Feet_Boots", "Feet").replace("Acc_Pauldron", "Acc_Pauldrons")
	return part

static func _attach(path: String, skeleton: Skeleton3D, tint: Color, rarity: String = "", skin: String = "") -> Array[MeshInstance3D]:
	var scene: Node3D = load(path).instantiate()
	var added: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		skeleton.add_child(mesh)
		mesh.skeleton = NodePath("..")
		if SKIN_CLOTH.has(skin):
			_cloth_over_skin(mesh, skeleton, SKIN_CLOTH[skin])
		_tint(mesh, tint, rarity, skin)
		added.append(mesh)
	scene.free()
	return added

## "Гола шкіра", вшита в одяг Quaternius: кисті лишаються шкірою, а решта
## (смужка біля пахви, шия) у сеті — тканина: трикутники, де головна
## кістка не кисть і не пальці, переносимо в окрему поверхню кольору тканини.
static func _cloth_over_skin(mesh: MeshInstance3D, skeleton: Skeleton3D, cloth_color: Color) -> void:
	var source := mesh.mesh
	var result := ArrayMesh.new()
	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = cloth_color
	cloth_mat.roughness = 0.9
	cloth_mat.resource_name = "SetCloth"
	var hand_bones := {}
	for b in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(b)
		if n.begins_with("hand") or n.begins_with("index") or n.begins_with("middle") or n.begins_with("ring") 				or n.begins_with("pinky") or n.begins_with("thumb"):
			hand_bones[b] = true
	var changed := false
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var material := source.surface_get_material(surface)
		var name := material.resource_name.to_lower() if material != null else ""
		var flags: int = source.call("surface_get_format", surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		if not (name.contains("regular") or name.contains("skin")) or arrays[Mesh.ARRAY_BONES] == null:
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
			result.surface_set_material(result.get_surface_count() - 1, material)
			continue
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := 8 if flags != 0 else 4
		var bind_bones := mesh.skin
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var skin_idx := PackedInt32Array()
		var cloth_idx := PackedInt32Array()
		for t in range(0, indices.size(), 3):
			var on_hand := 0
			for k in 3:
				var v := indices[t + k]
				var best := 0
				for j in per:
					if weights[v * per + j] > weights[v * per + best]:
						best = j
				var bone := bones[v * per + best]
				if bind_bones != null and bone < bind_bones.get_bind_count():
					var bname := bind_bones.get_bind_name(bone)
					bone = skeleton.find_bone(bname) if bname != &"" else bind_bones.get_bind_bone(bone)
				if hand_bones.has(bone):
					on_hand += 1
			var target := skin_idx if on_hand >= 2 else cloth_idx
			target.append(indices[t])
			target.append(indices[t + 1])
			target.append(indices[t + 2])
		for pair in [[skin_idx, material], [cloth_idx, cloth_mat]]:
			if (pair[0] as PackedInt32Array).is_empty():
				continue
			var part := arrays.duplicate()
			part[Mesh.ARRAY_INDEX] = pair[0]
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part, [], {}, flags)
			result.surface_set_material(result.get_surface_count() - 1, pair[1])
		changed = true
	if changed:
		mesh.mesh = result

## Перефарбувати всі матеріали меша (копії — оригінал спільний).
## skin — свій атлас сету (T_<skin>_Ranger / T_<skin>_Peasant): той самий
## одяг, але в кольорах сету, зі збереженими складками й швами.
static func _tint(mesh: MeshInstance3D, tint: Color, rarity: String = "", skin: String = "") -> void:
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
		if skin != "":
			var family := "Peasant" if name.contains("peasant") else ("Ranger" if name.contains("ranger") else "")
			var atlas := OUTFITS + "T_%s_%s.png" % [skin, family]
			if family != "" and ResourceLoader.exists(atlas):
				material.albedo_texture = load(atlas)
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
## Шкіра ховається, лише коли вона ПРЯМО під/над одягом (проєкція на
## трикутник падає всередину нього): так м'яз, що вилазить крізь одяг,
## зникає, а шкіра одразу ЗА краєм одягу лишається — без прозорої щілини
## між штанами й голим торсом. Біля самого краю — лише впритул (EDGE).
const COVER_RADIUS := 0.045
## Наскільки далеко над шкірою (уздовж нормалі) річ ще вважається накриттям.
const COVER_RAY := 0.12
const EDGE_RADIUS := 0.008
## Шкіра між краями ДВОХ різних речей (пройма між безрукавкою й рукавом)
## ховається, якщо обидва краї ближче за це.
const GAP_RADIUS := 0.07
const HASH_CELL := 0.06

## Тіло без шкіри, закритої одягом (кешується за набором частин).
## Геометрично: вершина тіла ховається, якщо поруч (у позі спокою) є
## трикутник одягу. Так короткі штани не "з'їдають" гомілку, а довгий
## рукав ховає всю руку.
static func _armpit_vertices(arrays: Array, skin: Skin, skeleton: Skeleton3D) -> PackedByteArray:
	var result := PackedByteArray()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	result.resize(points.size())
	if arrays[Mesh.ARRAY_BONES] == null or skin == null:
		return result
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / maxi(points.size(), 1)
	var shoulder := 0.21
	var shoulder_y := 1.45
	var sb := skeleton.find_bone("upperarm_l")
	if sb >= 0:
		shoulder = absf(skeleton.get_bone_global_rest(sb).origin.x)
		shoulder_y = skeleton.get_bone_global_rest(sb).origin.y
	var kind := {}
	for i in skin.get_bind_count():
		var n := String(skin.get_bind_name(i))
		if n == "":
			n = skeleton.get_bone_name(skin.get_bind_bone(i))
		if n.begins_with("Head") or n.begins_with("neck"):
			kind[i] = 3
		else:
			kind[i] = 1 if n.begins_with("upperarm") else (2 if n.begins_with("spine") or n.begins_with("clavicle") else 0)
	for v in points.size():
		var arm := 0.0
		var torso := 0.0
		var head := 0.0
		for j in per:
			var k: int = kind.get(bones[v * per + j], 0)
			if k == 1:
				arm += weights[v * per + j]
			elif k == 2:
				torso += weights[v * per + j]
			elif k == 3:
				head += weights[v * per + j]
		# 2 — голова й шия: не ховаємо ніколи (обличчя під шоломом, шия
		# під каптуром лишаються).
		if head > 0.5:
			result[v] = 2
		elif arm > 0.03 and torso > 0.03:
			result[v] = 1
		# Плече біля суглоба: верх рукава у T-позі його не накриває, а з
		# опущеною рукою воно видно крізь пройму.
		elif arm > 0.35 and absf(points[v].x) < shoulder + (0.19 if points[v].z < -0.05 else 0.14):
			result[v] = 3
		# Бік торса під пахвою (широкий м'яз) — так само.
		elif torso > 0.5 and absf(points[v].x) > shoulder * 0.55 and points[v].y > shoulder_y - 0.2:
			result[v] = 3
	return result

static func _edge_key(a: Vector3, b: Vector3) -> String:
	var ka := "%.4f,%.4f,%.4f" % [a.x, a.y, a.z]
	var kb := "%.4f,%.4f,%.4f" % [b.x, b.y, b.z]
	return ka + "|" + kb if ka < kb else kb + "|" + ka

## Точка лежить на ребрі-краю (біти borders) трикутника.
static func _on_border(q: Vector3, a: Vector3, b: Vector3, c: Vector3, bits: int) -> bool:
	var corners := [a, b, c]
	for e in 3:
		if (bits & (1 << e)) == 0:
			continue
		var p0: Vector3 = corners[e]
		var p1: Vector3 = corners[(e + 1) % 3]
		var seg := p1 - p0
		var t := clampf((q - p0).dot(seg) / maxf(seg.length_squared(), 1e-12), 0.0, 1.0)
		if (p0 + seg * t).distance_squared_to(q) < 1e-8:
			return true
	return false

## Проєкція точки на площину трикутника падає всередину трикутника.
static func _over_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return false
	var q := p - n * ((p - a).dot(n) / n.length_squared())
	return (b - a).cross(q - a).dot(n) >= 0.0 and (c - b).cross(q - b).dot(n) >= 0.0 and (a - c).cross(q - c).dot(n) >= 0.0

static func _masked_body(key: String, mesh: MeshInstance3D, skeleton: Skeleton3D, garments: Array[MeshInstance3D], boots := false) -> ArrayMesh:
	if _masked.has(key):
		return _masked[key]
	# Трикутники одягу в позі спокою, розкладені по клітинках простору.
	var grid := {}
	var tris := PackedVector3Array()
	# Які ребра трикутників — зовнішній край одягу (ребро лише одного
	# трикутника): біт 1/2/4 для ребер ab/bc/ca.
	var borders := PackedByteArray()
	var owners := PackedInt32Array()
	# Верх кожної речі (у позі спокою): вище за нього вона шкіру не ховає.
	var tops := PackedFloat32Array()
	for garment_index in garments.size():
		var garment := garments[garment_index]
		for surface in garment.mesh.get_surface_count():
			var arrays := garment.mesh.surface_get_arrays(surface)
			var points := _rest_points(arrays, garment.skin, skeleton)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var uses := {}
			if tops.size() <= garment_index:
				tops.resize(garment_index + 1)
				tops[garment_index] = -99.0
			for pt in points:
				tops[garment_index] = maxf(tops[garment_index], pt.y)
			for t in range(0, indices.size(), 3):
				for e in 3:
					var edge := _edge_key(points[indices[t + e]], points[indices[t + (e + 1) % 3]])
					uses[edge] = int(uses.get(edge, 0)) + 1
			for t in range(0, indices.size(), 3):
				var bits := 0
				for e in 3:
					if int(uses[_edge_key(points[indices[t + e]], points[indices[t + (e + 1) % 3]])]) == 1:
						bits |= 1 << e
				borders.append(bits)
				owners.append(garment_index)
			for t in range(0, indices.size(), 3):
				var a := points[indices[t]]
				var b := points[indices[t + 1]]
				var c := points[indices[t + 2]]
				var id := tris.size() / 3
				tris.append(a)
				tris.append(b)
				tris.append(c)
				var lo := (a.min(b).min(c) - Vector3.ONE * GAP_RADIUS * 1.6) / HASH_CELL
				var hi := (a.max(b).max(c) + Vector3.ONE * GAP_RADIUS * 1.6) / HASH_CELL
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
		# Пахва: вага ділиться між плечем і торсом. У T-позі маски вона
		# далеко від одягу, а з опущеними руками випирає крізь нього.
		var armpit := _armpit_vertices(arrays, mesh.skin, skeleton)
		for v in points.size():
			var p := points[v]
			var cell := Vector3i(floori(p.x / HASH_CELL), floori(p.y / HASH_CELL), floori(p.z / HASH_CELL))
			if not grid.has(cell):
				continue
			var edge_of := -1
			if armpit[v] == 2:
				continue
			var gap := GAP_RADIUS * (1.6 if armpit[v] == 1 else 1.0)
			for id: int in grid[cell]:
				var a := tris[id * 3]
				var b := tris[id * 3 + 1]
				var c := tris[id * 3 + 2]
				var closest := _closest_on_triangle(p, a, b, c)
				var dist := p.distance_squared_to(closest)
				if dist >= gap * gap or p.y > tops[owners[id]] + 0.006:
					continue
				if armpit[v] == 1:
					covered[v] = 2
					break
				if armpit[v] == 3 and dist < 0.065 * 0.065:
					covered[v] = 2
					break
				var border := _on_border(closest, a, b, c, borders[id])
				if dist < EDGE_RADIUS * EDGE_RADIUS or (dist < COVER_RADIUS * COVER_RADIUS and (not border or _over_triangle(p, a, b, c))):
					covered[v] = 1
					break
				# Дві РІЗНІ речі поруч (пройма між безрукавкою й рукавом,
				# пояс між сорочкою й штанами) — щілина між ними, ховаємо.
				if edge_of >= 0 and edge_of != owners[id]:
					covered[v] = 1
					break
				edge_of = owners[id]
		# Ховаємо лише те, що справді НАКРИТО: над точкою шкіри (уздовж її
		# нормалі) має бути річ ближче за COVER_RAY. Інакше — лишаємо шкіру:
		# краще видно плече, ніж дірку наскрізь (безрукавка, край чобота).
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var rest_normals := _rest_normals(normals, arrays, mesh.skin, skeleton)
		for v in points.size():
			if covered[v] == 0:
				continue
			var p := points[v]
			var cell := Vector3i(floori(p.x / HASH_CELL), floori(p.y / HASH_CELL), floori(p.z / HASH_CELL))
			var dir := rest_normals[v]
			var hit_any := false
			for id: int in grid.get(cell, PackedInt32Array()):
				var hit: Variant = Geometry3D.ray_intersects_triangle(p - dir * 0.004, dir, tris[id * 3], tris[id * 3 + 1], tris[id * 3 + 2])
				if hit != null and (hit as Vector3).distance_to(p) < COVER_RAY:
					hit_any = true
					break
				# Шкіра трохи прорізала річ (річ ПІД нею) — теж ховаємо.
				var back: Variant = Geometry3D.ray_intersects_triangle(p + dir * 0.004, -dir, tris[id * 3], tris[id * 3 + 1], tris[id * 3 + 2])
				if back != null and (back as Vector3).distance_to(p) < 0.035:
					hit_any = true
					break
			if not hit_any:
				covered[v] = 0
		if boots:
			var feet := _foot_vertices(arrays, mesh.skin, skeleton)
			for v in points.size():
				if feet[v]:
					covered[v] = 1
		var kept := PackedInt32Array()
		for t in range(0, indices.size(), 3):
			if covered[indices[t]] and covered[indices[t + 1]] and covered[indices[t + 2]]:
				continue
			# Пахва: досить однієї схованої вершини.
			if covered[indices[t]] == 2 or covered[indices[t + 1]] == 2 or covered[indices[t + 2]] == 2:
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
## Вершини стоп (вага кісток foot_/ball_ понад половину).
static func _foot_vertices(arrays: Array, skin: Skin, skeleton: Skeleton3D) -> PackedByteArray:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var result := PackedByteArray()
	result.resize(points.size())
	if arrays[Mesh.ARRAY_BONES] == null or skin == null:
		return result
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / maxi(points.size(), 1)
	var foot := {}
	for i in skin.get_bind_count():
		var n := String(skin.get_bind_name(i))
		if n == "":
			n = skeleton.get_bone_name(skin.get_bind_bone(i))
		foot[i] = n.begins_with("foot") or n.begins_with("ball")
	for v in points.size():
		var w := 0.0
		for j in per:
			if foot.get(bones[v * per + j], false):
				w += weights[v * per + j]
		result[v] = 1 if w > 0.5 else 0
	return result

## Нормалі тіла в позі спокою (як _rest_points, лише поворот).
static func _rest_normals(normals: PackedVector3Array, arrays: Array, skin: Skin, skeleton: Skeleton3D) -> PackedVector3Array:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if skin == null or bones.is_empty() or normals.is_empty():
		return normals
	var out := PackedVector3Array()
	out.resize(normals.size())
	var per := bones.size() / maxi(normals.size(), 1)
	var bases: Array[Basis] = []
	for bind in skin.get_bind_count():
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(bind))
		bases.append((skeleton.get_bone_global_rest(maxi(bone, 0)) * skin.get_bind_pose(bind)).basis)
	for v in normals.size():
		var n := Vector3.ZERO
		for k in per:
			var w := weights[v * per + k]
			if w > 0.0:
				n += (bases[bones[v * per + k]] * normals[v]) * w
		out[v] = n.normalized() if n.length() > 0.0001 else normals[v]
	return out

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
