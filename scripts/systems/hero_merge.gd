extends RefCounted
class_name HeroMerge

## Зливає модель героя в ОДНУ поверхню.
##
## Модель героя — це 4 частини (тіло, голова, ноги, ступні), і в кожній
## по кілька "поверхонь" різного кольору: разом 13–17. Для телефона кожна
## поверхня зі скелетом — це окремий прохід перерахунку кісток і окреме
## промальовування, тож один герой коштував як пів сцени.
##
## Тут усі частини стають одним мешем, а колір кожної поверхні
## записується просто у вершини. Матеріал лишається той самий (блиск,
## шорсткість), тож вигляд не змінюється — змінюється лише кількість
## промальовувань: 17 -> 1.
##
## Злиття робиться один раз на модель за запуск гри (далі береться
## готове). Якщо модель незвична (текстури, прозорість, різні скелети в
## частин) — вона лишається як є.

## Шлях сцени моделі -> {"mesh": ArrayMesh, "skin": Skin} або null,
## якщо модель злити не можна.
static var _cache := {}

static func apply(model: Node3D, key: String) -> void:
	var parts: Array[MeshInstance3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.skin != null and part.mesh != null:
			parts.append(part)
	if parts.is_empty():
		return
	var skeleton := parts[0].get_parent()
	for part in parts:
		if part.get_parent() != skeleton:
			return
	if not _cache.has(key):
		_cache[key] = _merge(parts)
	var merged: Variant = _cache[key]
	if merged == null:
		return
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = merged.mesh
	body.skin = merged.skin
	body.layers = parts[0].layers
	body.cast_shadow = parts[0].cast_shadow
	skeleton.add_child(body)
	body.skeleton = parts[0].skeleton
	for part in parts:
		skeleton.remove_child(part)
		part.free()

static func _merge(parts: Array[MeshInstance3D]) -> Variant:
	var skin := parts[0].skin
	# Групи поверхонь, що відрізняються лише кольором: підпис -> дані.
	var groups := {}
	for part in parts:
		if not _same_skin(skin, part.skin) or part.mesh.get_blend_shape_count() > 0:
			return null
		for surface in part.mesh.get_surface_count():
			var material := part.get_active_material(surface) as BaseMaterial3D
			if material == null or material.albedo_texture != null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				return null
			var signature := _signature(material)
			if not groups.has(signature):
				groups[signature] = {"material": material, "v": PackedVector3Array(), "n": PackedVector3Array(),
					"c": PackedColorArray(), "b": PackedInt32Array(), "w": PackedFloat32Array(), "i": PackedInt32Array()}
			_append(groups[signature], part, surface, material)
	var mesh := ArrayMesh.new()
	for signature: String in groups:
		var group: Dictionary = groups[signature]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = group.v
		arrays[Mesh.ARRAY_NORMAL] = group.n
		arrays[Mesh.ARRAY_COLOR] = group.c
		arrays[Mesh.ARRAY_BONES] = group.b
		arrays[Mesh.ARRAY_WEIGHTS] = group.w
		arrays[Mesh.ARRAY_INDEX] = group.i
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material: BaseMaterial3D = (group.material as BaseMaterial3D).duplicate()
		material.albedo_color = Color.WHITE
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return {"mesh": mesh, "skin": skin}

## Додає поверхню частини в групу: колір — у вершини, ваги — 4 найсильніші.
static func _append(group: Dictionary, part: MeshInstance3D, surface: int, material: BaseMaterial3D) -> void:
	var arrays := part.mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var count := vertices.size()
	var per := bones.size() / count
	var own_colors := PackedColorArray()
	if material.vertex_color_use_as_albedo and arrays[Mesh.ARRAY_COLOR] != null:
		own_colors = arrays[Mesh.ARRAY_COLOR]
	var linear_colors := not material.vertex_color_is_srgb
	var xf := part.transform
	var normal_basis := xf.basis.inverse().transposed()
	var out_v: PackedVector3Array = group.v
	var out_n: PackedVector3Array = group.n
	var out_c: PackedColorArray = group.c
	var out_b: PackedInt32Array = group.b
	var out_w: PackedFloat32Array = group.w
	var out_i: PackedInt32Array = group.i
	var base := out_v.size()
	var albedo := material.albedo_color
	for index in count:
		out_v.append(xf * vertices[index])
		out_n.append((normal_basis * normals[index]).normalized())
		var color := albedo
		if own_colors.size() == count:
			var own := own_colors[index]
			if linear_colors:
				own = own.linear_to_srgb()
			color = Color(albedo.r * own.r, albedo.g * own.g, albedo.b * own.b, 1.0)
		out_c.append(color)
		if per == 4:
			for k in 4:
				out_b.append(bones[index * 4 + k])
				out_w.append(weights[index * 4 + k])
		else:
			# 8 ваг -> 4 найсильніші (решта — соті частки, їх не видно).
			var order := [0, 1, 2, 3, 4, 5, 6, 7]
			order.sort_custom(func(a: int, b: int) -> bool: return weights[index * 8 + a] > weights[index * 8 + b])
			var sum := 0.0
			for k in 4:
				sum += weights[index * 8 + int(order[k])]
			for k in 4:
				out_b.append(bones[index * 8 + int(order[k])])
				out_w.append(weights[index * 8 + int(order[k])] / sum if sum > 0.0 else (1.0 if k == 0 else 0.0))
	var indices: Variant = arrays[Mesh.ARRAY_INDEX]
	if indices == null:
		for index in count:
			out_i.append(base + index)
	else:
		for index: int in (indices as PackedInt32Array):
			out_i.append(base + index)
	group.v = out_v
	group.n = out_n
	group.c = out_c
	group.b = out_b
	group.w = out_w
	group.i = out_i

## Усе в матеріалі, окрім кольору: поверхні з однаковим підписом можна
## малювати одним матеріалом.
static func _signature(material: BaseMaterial3D) -> String:
	return "%s|%.3f|%.3f|%.3f|%s|%s|%.3f|%d|%d|%d" % [material.get_class(), material.metallic, material.roughness,
		material.metallic_specular, material.emission_enabled,
		material.emission.to_html() if material.emission_enabled else "",
		material.emission_energy_multiplier if material.emission_enabled else 0.0,
		material.cull_mode, material.shading_mode, material.diffuse_mode]

static func _same_skin(a: Skin, b: Skin) -> bool:
	if a == b:
		return true
	if a.get_bind_count() != b.get_bind_count():
		return false
	for index in a.get_bind_count():
		if a.get_bind_name(index) != b.get_bind_name(index) or a.get_bind_bone(index) != b.get_bind_bone(index):
			return false
		if not a.get_bind_pose(index).is_equal_approx(b.get_bind_pose(index)):
			return false
	return true
