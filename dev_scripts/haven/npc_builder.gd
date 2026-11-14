extends Node
## ЗБИРАЧ ЖИТЕЛІВ ПРИХИСТКУ. Набір одягу Quaternius (Modular Character
## Outfits) не має голів — до нього йде набір Universal Base Characters, де
## голова — частина цільного тіла. Тож жителя збираємо так:
##   скелет і одяг — з моделі одягу;
##   голова — з базового тіла: лише трикутники вище шиї (тіло під одягом
##     не потрібне й лізло б крізь нього);
##   очі, брови — з базового тіла; зачіска — з набору зачісок;
##   рухи — з Universal Animation Library 2 (той самий скелет, 65 кісток).
##
## ДЛЯ ТЕЛЕФОНА. Кожну окрему частину анімованої моделі відеочип рахує
## окремим проходом (кістки -> вершини), тож житель із 6-7 частин коштував
## як шість жителів. Тому:
##   - усі частини зливаються в ОДИН меш з ОДНІЄЮ текстурою-атласом
##     (одяг, шкіра, волосся, очі — плитками на одній картинці);
##   - модель спрощено (KEEP_RATIO трикутників) — з ~11 м більшого не видно;
##   - на вершину — 4 кістки замість 8;
##   - матеріал без карт нерівностей/блиску, освітлення у вершинах;
##   - з анімацій прибрано доріжки пальців, масштабу й зайвих зсувів
##     (пальці стоять у позі з першого кадру своєї анімації).
##
## Запуск (test_env; двома заходами, бо атласи мають пройти імпорт):
##   1) godot --headless res://dev_scripts/haven/npc_builder.tscn -- --atlas
##      (пише assets/models/haven/people/atlas_<id>.png) і godot --import;
##   2) godot --headless res://dev_scripts/haven/npc_builder.tscn
## Результат — res://scenes/world/haven/npcs/<id>.scn (+ кліпи в
## res://assets/animations/npc/).

const PEOPLE := "res://assets/models/haven/people/"
const UAL := "res://incoming/anims/UAL2_Standard.glb"   # лише в test_env; сирці — D:\RuneHorde_work\packs
const OUT_DIR := "res://scenes/world/haven/npcs/"
const ANIM_DIR := "res://assets/animations/npc/"

## Хто як виглядає: одяг, тіло (стать), зачіски, відтінок одягу, рух.
const LOOKS := {
	&"elder": {"outfit": "Male_Peasant", "body": "Superhero_Male_FullBody", "hair": ["Hair_Long", "Hair_Beard"],
		"tint": Color(0.78, 0.82, 1.0), "anim": "Idle_FoldArms"},
	&"mentor": {"outfit": "Female_Ranger", "body": "Superhero_Female_FullBody", "hair": [],
		"tint": Color(1, 1, 1), "anim": "Idle_FoldArms"},
	&"smith": {"outfit": "Male_Peasant", "body": "Superhero_Male_FullBody", "hair": ["Hair_Buzzed", "Hair_Beard"],
		"tint": Color(1.0, 0.86, 0.72), "anim": "TreeChopping"},
	&"sage": {"outfit": "Male_Ranger", "body": "Superhero_Male_FullBody", "hair": ["Hair_Beard"],
		"tint": Color(0.82, 0.72, 1.0), "anim": "Idle_Lantern"},
	&"merchant": {"outfit": "Female_Peasant", "body": "Superhero_Female_FullBody", "hair": ["Hair_Buns"],
		"tint": Color(1, 1, 1), "anim": "Idle_Rail"},
}
## Рухи, що їх можуть грати жителі (кліпи зберігаються окремо).
const CLIPS := ["Idle_FoldArms", "TreeChopping", "Idle_Lantern", "Idle_Rail", "Yes", "Idle_No"]
## Яку частку трикутників лишити (з відстані камери більшого не видно).
const KEEP_RATIO := 0.3
## Кістки, яких анімація жителів не рухає: пальці й кінцеві "листки".
const STILL_BONES := ["index_", "middle_", "pinky_", "ring_", "thumb_", "_leaf"]

## Атлас 1024×1024: три великі плитки 512 (одяг, шкіра голови, шкіра тіла)
## і чверть, поділена на чотири малі 256 (волосся, брови, очі).
const ATLAS_SIZE := 1024
const BIG_TILES := [Rect2i(0, 0, 512, 512), Rect2i(512, 0, 512, 512), Rect2i(0, 512, 512, 512)]
const SMALL_TILES := [Rect2i(512, 512, 256, 256), Rect2i(768, 512, 256, 256), Rect2i(512, 768, 256, 256), Rect2i(768, 768, 256, 256)]

## Пози пальців із першого кадру кожної анімації: назва кліпу -> {кістка: поворот}.
var _finger_poses := {}

## Наскільки темнішає повністю металева ділянка в малюнку атласу.
const METAL_SHADE := 0.5

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(ANIM_DIR)
	var atlas_only := "--atlas" in OS.get_cmdline_user_args()
	if not atlas_only:
		_save_clips()
	for id: StringName in LOOKS:
		var npc := _assemble(id, LOOKS[id], atlas_only)
		if npc == null:
			continue
		var packed := PackedScene.new()
		_own(npc, npc)
		packed.pack(npc)
		var err := ResourceSaver.save(packed, OUT_DIR + String(id) + ".scn")
		print("NPC ", id, " err=", err)
		npc.free()
	get_tree().quit(0)

func _save_clips() -> void:
	var lib_scene: Node = load(UAL).instantiate()
	var player: AnimationPlayer = lib_scene.find_children("*", "AnimationPlayer", true, false)[0]
	for clip: String in CLIPS:
		var anim: Animation = player.get_animation(clip).duplicate(true)
		# Імпорт сам зробив зацикленими ті, що мали суфікс _Loop; "Так" — разовий.
		if clip == "Yes":
			anim.loop_mode = Animation.LOOP_NONE
		var poses := {}
		var before := anim.get_track_count()
		for track in range(anim.get_track_count() - 1, -1, -1):
			var bone := String(anim.track_get_path(track).get_concatenated_subnames())
			var kind := anim.track_get_type(track)
			var still := false
			for marker: String in STILL_BONES:
				if bone.contains(marker):
					still = true
			if still and kind == Animation.TYPE_ROTATION_3D and anim.track_get_key_count(track) > 0:
				poses[bone] = anim.track_get_key_value(track, 0)
			# Масштаб кісток не міняється; зсув потрібен лише тазу.
			var extra := kind == Animation.TYPE_SCALE_3D or (kind == Animation.TYPE_POSITION_3D and bone != "pelvis" and bone != "root")
			if still or extra:
				anim.remove_track(track)
		_finger_poses[clip] = poses
		print("NPC clip ", clip, ": tracks ", before, " -> ", anim.get_track_count())
		ResourceSaver.save(anim, ANIM_DIR + clip + ".res")
	lib_scene.free()

## Збирає жителя. atlas_only — лише записати атлас (PNG) і вийти.
func _assemble(id: StringName, look: Dictionary, atlas_only: bool) -> Node3D:
	var source: Node3D = load(PEOPLE + String(look.outfit) + ".gltf").instantiate()
	var src_armature := source.get_node("Armature") as Node3D
	var src_skeleton := src_armature.get_node("Skeleton3D") as Skeleton3D
	# Частини: {arrays, skin, material, tint, eight, xf}.
	var pieces: Array = []
	var skin: Skin = null
	for visual: MeshInstance3D in src_skeleton.find_children("*", "MeshInstance3D", false, false):
		if visual.mesh == null:
			continue
		if skin == null:
			skin = visual.skin.duplicate(true)
		_add_pieces(pieces, visual, look.tint, -INF)
	var body: Node3D = load(PEOPLE + String(look.body) + ".gltf").instantiate()
	var body_skeleton := body.get_node("Armature/Skeleton3D") as Skeleton3D
	var neck_y := body_skeleton.get_bone_global_rest(body_skeleton.find_bone("neck_01")).origin.y
	for visual: MeshInstance3D in body_skeleton.find_children("*", "MeshInstance3D", false, false):
		if visual.mesh == null:
			continue
		var is_body := String(visual.name).to_lower().begins_with("superhero")
		_add_pieces(pieces, visual, Color.WHITE, neck_y + 0.02 if is_body else -INF)
	body.free()
	for hair: String in look.hair:
		var hair_scene: Node3D = load(PEOPLE + hair + ".gltf").instantiate()
		for visual: MeshInstance3D in hair_scene.find_children("*", "MeshInstance3D", true, false):
			_add_pieces(pieces, visual, Color.WHITE, -INF)
		hair_scene.free()

	# Атлас: по плитці на кожну текстуру (з відтінком одягу).
	var atlas_path := PEOPLE + "atlas_%s.png" % id
	var tiles := _atlas_tiles(pieces)
	if atlas_only:
		_write_atlas(tiles, atlas_path)
		source.free()
		return null
	if not ResourceLoader.exists(atlas_path):
		push_error("Немає атласу %s — спершу запусти з -- --atlas і зроби імпорт" % atlas_path)
		source.free()
		return null

	# Один меш: усі частини прив'язані до скелета одягу, UV — в атлас.
	var merged := _merge(pieces, skin, tiles)
	var slim := _slim(merged, _atlas_material(load(atlas_path), String(id)))
	print("NPC ", id, ": parts ", pieces.size(), ", tris ", (merged[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3,
		" -> ", _triangles(slim))

	var root := Node3D.new()
	root.name = String(id).capitalize()
	var armature := Node3D.new()
	armature.name = "Armature"
	armature.transform = src_armature.transform
	root.add_child(armature)
	var skeleton := src_skeleton.duplicate(0) as Skeleton3D
	for child in skeleton.get_children():
		skeleton.remove_child(child)
		child.free()
	skeleton.name = "Skeleton3D"
	armature.add_child(skeleton)
	source.free()
	var visual_body := MeshInstance3D.new()
	visual_body.name = "Body"
	visual_body.mesh = slim
	visual_body.skin = skin
	visual_body.skeleton = NodePath("..")
	skeleton.add_child(visual_body)
	# Пальці — у позі з першого кадру своєї анімації (доріжок пальців немає).
	var poses: Dictionary = _finger_poses.get(String(look.anim), {})
	for bone: String in poses:
		var index := skeleton.find_bone(bone)
		if index >= 0:
			skeleton.set_bone_pose_rotation(index, poses[bone])
	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	root.add_child(animation_player)
	var library := AnimationLibrary.new()
	for clip: String in CLIPS:
		library.add_animation(clip, load(ANIM_DIR + clip + ".res"))
	animation_player.add_animation_library(&"", library)
	animation_player.autoplay = String(look.anim)
	root.set_meta(&"idle_anim", String(look.anim))
	return root

## Поверхні меша як частини. min_y — лишити тільки трикутники вище цієї
## висоти (голова з цільного тіла).
func _add_pieces(pieces: Array, visual: MeshInstance3D, tint: Color, min_y: float) -> void:
	for surface in visual.mesh.get_surface_count():
		var arrays := visual.mesh.surface_get_arrays(surface)
		if min_y > -INF:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var kept := PackedInt32Array()
			for t in range(0, indices.size(), 3):
				if vertices[indices[t]].y >= min_y and vertices[indices[t + 1]].y >= min_y and vertices[indices[t + 2]].y >= min_y:
					kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
			arrays[Mesh.ARRAY_INDEX] = kept
		var format: int = visual.mesh.call("surface_get_format", surface)
		pieces.append({"arrays": arrays, "skin": visual.skin, "material": visual.mesh.surface_get_material(surface),
			"tint": tint, "eight": (format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0, "xf": visual.transform})

# --- атлас ---

## Текстура (з відтінком) -> плитка атласу. Великі — одяг і шкіра, малі —
## волосся, брови, очі.
func _atlas_tiles(pieces: Array) -> Dictionary:
	var tiles := {}
	var big := 0
	var small := 0
	for piece: Dictionary in pieces:
		var material := piece.material as BaseMaterial3D
		var key := _tile_key(piece)
		if tiles.has(key):
			continue
		var name := material.resource_name.to_lower()
		var is_small := name.contains("hair") or name.contains("eye")
		var rect: Rect2i
		if is_small:
			rect = SMALL_TILES[small]
			small += 1
		else:
			rect = BIG_TILES[big]
			big += 1
		tiles[key] = {"rect": rect, "texture": material.albedo_texture, "color": material.albedo_color * (piece.tint as Color),
			"metal": material.metallic_texture, "metal_channel": material.metallic_texture_channel, "metallic": material.metallic}
	return tiles

func _tile_key(piece: Dictionary) -> String:
	var material := piece.material as BaseMaterial3D
	return "%s|%s" % [material.albedo_texture.resource_path, (material.albedo_color * (piece.tint as Color)).to_html()]

func _write_atlas(tiles: Dictionary, path: String) -> void:
	var atlas := Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0.5, 0.45, 0.4))
	for key: String in tiles:
		var tile: Dictionary = tiles[key]
		var rect: Rect2i = tile.rect
		var image := Image.load_from_file(ProjectSettings.globalize_path((tile.texture as Texture2D).resource_path))
		image.convert(Image.FORMAT_RGBA8)
		image.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_LANCZOS)
		var color: Color = tile.color
		# Метал (пряжки, наплічники) без карти блиску виглядав би світлою
		# плямою — притемнюємо його просто в малюнку.
		var metal: Image = null
		if tile.metal != null and float(tile.metallic) > 0.0:
			metal = Image.load_from_file(ProjectSettings.globalize_path((tile.metal as Texture2D).resource_path))
			metal.convert(Image.FORMAT_RGBA8)
			metal.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_BILINEAR)
		if metal != null or not color.is_equal_approx(Color.WHITE):
			var channel: int = tile.metal_channel
			for y in rect.size.y:
				for x in rect.size.x:
					var pixel := image.get_pixel(x, y)
					var shade := 1.0
					if metal != null:
						shade = lerpf(1.0, METAL_SHADE, metal.get_pixel(x, y)[channel] * float(tile.metallic))
					image.set_pixel(x, y, Color(pixel.r * color.r * shade, pixel.g * color.g * shade, pixel.b * color.b * shade, 1.0))
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, rect.size), rect.position)
	atlas.convert(Image.FORMAT_RGB8)
	atlas.save_png(ProjectSettings.globalize_path(path))
	# Параметри імпорту: стискати для відеопам'яті, з рівнями зменшення.
	var import_path := ProjectSettings.globalize_path(path) + ".import"
	if not FileAccess.file_exists(import_path):
		var file := FileAccess.open(import_path, FileAccess.WRITE)
		file.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[deps]\n\nsource_file=\"%s\"\n\n[params]\n\ncompress/mode=2\nmipmaps/generate=true\n" % path)
	print("NPC atlas ", path, " tiles=", tiles.size())

func _atlas_material(texture: Texture2D, id: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "Npc_" + id
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.roughness = 0.9
	material.metallic = 0.0
	material.metallic_specular = 0.3
	# Пасма волосся — пласкі картки, видно з обох боків.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

# --- один меш ---

## Зливає частини в одні масиви: 4 ваги, прив'язка до скелета одягу, UV в атлас.
func _merge(pieces: Array, target: Skin, tiles: Dictionary) -> Array:
	var bind_index := {}
	for i in target.get_bind_count():
		bind_index[String(target.get_bind_name(i))] = i
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_b := PackedInt32Array()
	var out_w := PackedFloat32Array()
	var out_i := PackedInt32Array()
	for piece: Dictionary in pieces:
		var arrays: Array = piece.arrays
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var per := 8 if piece.eight else 4
		var skin: Skin = piece.skin
		var xf: Transform3D = piece.xf
		# Частина прив'язана до свого скелета (інші пропорції тіла): для
		# кожної кістки — перехід з її прив'язки в прив'язку одягу.
		var rebind: Array[Transform3D] = []
		var remap_bone := PackedInt32Array()
		var differs := false
		for i in skin.get_bind_count():
			var index: int = bind_index[String(skin.get_bind_name(i))]
			remap_bone.append(index)
			var change := target.get_bind_pose(index).affine_inverse() * skin.get_bind_pose(i)
			rebind.append(change)
			if not change.is_equal_approx(Transform3D.IDENTITY):
				differs = true
		var rect: Rect2i = tiles[_tile_key(piece)].rect
		var remap := {}
		for index in indices:
			if not remap.has(index):
				remap[index] = out_v.size()
				# Чотири найсильніші ваги.
				var pairs := []
				for k in per:
					pairs.append([weights[index * per + k], bones[index * per + k]])
				pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
				var sum := 0.0
				for k in 4:
					sum += float(pairs[k][0])
				var vertex := xf * vertices[index]
				var normal := (xf.basis * normals[index]).normalized()
				var moved := Vector3.ZERO
				var turned := Vector3.ZERO
				for k in 4:
					var weight := float(pairs[k][0]) / sum if sum > 0.0 else (1.0 if k == 0 else 0.0)
					var bone := int(pairs[k][1])
					out_b.append(remap_bone[bone])
					out_w.append(weight)
					if differs and weight > 0.0:
						moved += (rebind[bone] * vertex) * weight
						turned += (rebind[bone].basis * normal) * weight
				out_v.append(moved if differs else vertex)
				out_n.append(turned.normalized() if differs else normal)
				# UV у свою плитку (з відступом у піксель від краю).
				var uv := uvs[index]
				if uv.x < 0.0 or uv.x > 1.0:
					uv.x = fposmod(uv.x, 1.0)
				if uv.y < 0.0 or uv.y > 1.0:
					uv.y = fposmod(uv.y, 1.0)
				out_uv.append(Vector2((rect.position.x + 1.0 + uv.x * (rect.size.x - 2.0)) / ATLAS_SIZE,
					(rect.position.y + 1.0 + uv.y * (rect.size.y - 2.0)) / ATLAS_SIZE))
			out_i.append(remap[index])
	var arrays_out := []
	arrays_out.resize(Mesh.ARRAY_MAX)
	arrays_out[Mesh.ARRAY_VERTEX] = out_v
	arrays_out[Mesh.ARRAY_NORMAL] = out_n
	arrays_out[Mesh.ARRAY_TEX_UV] = out_uv
	arrays_out[Mesh.ARRAY_BONES] = out_b
	arrays_out[Mesh.ARRAY_WEIGHTS] = out_w
	arrays_out[Mesh.ARRAY_INDEX] = out_i
	return arrays_out

## Спрощений меш з одним матеріалом: рівень деталізації, найближчий до
## KEEP_RATIO, стиснутий до потрібних вершин; плюс рівні для дальшої відстані.
func _slim(arrays: Array, material: Material) -> ArrayMesh:
	var probe := ImporterMesh.new()
	probe.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	probe.generate_lods(60.0, 25.0, [])
	var source := probe.get_surface_arrays(0)
	var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var target := int(indices.size() * KEEP_RATIO)
	var best_gap := absi(indices.size() - target)
	for lod in probe.get_surface_lod_count(0):
		var lod_indices := probe.get_surface_lod_indices(0, lod)
		if absi(lod_indices.size() - target) < best_gap:
			best_gap = absi(lod_indices.size() - target)
			indices = lod_indices
	var remap := {}
	var order := PackedInt32Array()
	var out_i := PackedInt32Array()
	for index in indices:
		if not remap.has(index):
			remap[index] = order.size()
			order.append(index)
		out_i.append(remap[index])
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = source[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = source[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = source[Mesh.ARRAY_WEIGHTS]
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_b := PackedInt32Array()
	var out_w := PackedFloat32Array()
	for index in order:
		out_v.append(vertices[index])
		out_n.append(normals[index])
		out_uv.append(uvs[index])
		for k in 4:
			out_b.append(bones[index * 4 + k])
			out_w.append(weights[index * 4 + k])
	var slim := []
	slim.resize(Mesh.ARRAY_MAX)
	slim[Mesh.ARRAY_VERTEX] = out_v
	slim[Mesh.ARRAY_NORMAL] = out_n
	slim[Mesh.ARRAY_TEX_UV] = out_uv
	slim[Mesh.ARRAY_BONES] = out_b
	slim[Mesh.ARRAY_WEIGHTS] = out_w
	slim[Mesh.ARRAY_INDEX] = out_i
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, slim, [], {}, material)
	importer.generate_lods(60.0, 25.0, [])
	return importer.get_mesh()

static func _triangles(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		total += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return total

func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)
