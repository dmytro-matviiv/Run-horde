extends Node
## ЗБИРАЧ NPC ПРИХИСТКУ. Набір одягу Quaternius (Modular Character Outfits)
## не має голів — до нього йде набір Universal Base Characters, де голова —
## частина цільного тіла. Тож NPC збираємо так:
##   скелет і одяг — з моделі одягу;
##   голова — з базового тіла: лишаємо лише трикутники вище шиї (тіло під
##     одягом не потрібне й лізло б крізь нього);
##   очі, брови — з базового тіла; зачіска — з набору зачісок;
##   рухи — з Universal Animation Library 2 (той самий скелет, 65 кісток).
## Результат — res://scenes/world/haven/npcs/<id>.scn (+ кліпи в
## res://assets/animations/npc/). Запуск — як у haven_builder.

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
## Рухи, що їх можуть грати NPC (кліпи зберігаються окремо).
const CLIPS := ["Idle_FoldArms", "TreeChopping", "Idle_Lantern", "Idle_Rail", "Yes", "Idle_No"]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(ANIM_DIR)
	_save_clips()
	for id: StringName in LOOKS:
		var npc := _assemble(id, LOOKS[id])
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
		ResourceSaver.save(anim, ANIM_DIR + clip + ".res")
	lib_scene.free()

func _assemble(id: StringName, look: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = String(id).capitalize()
	var source: Node3D = load(PEOPLE + String(look.outfit) + ".gltf").instantiate()
	var src_armature := source.get_node("Armature") as Node3D
	var src_skeleton := src_armature.get_node("Skeleton3D") as Skeleton3D
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
	# Одяг.
	for mesh_instance: MeshInstance3D in src_skeleton.find_children("*", "MeshInstance3D", false, false):
		if mesh_instance.mesh == null:
			continue
		var copy := _copy_mesh(mesh_instance)
		_tint(copy, look.tint)
		skeleton.add_child(copy)
	# Голова, очі, брови з базового тіла.
	var body: Node3D = load(PEOPLE + String(look.body) + ".gltf").instantiate()
	var body_skeleton := body.get_node("Armature/Skeleton3D") as Skeleton3D
	var neck_y := (body_skeleton.get_bone_global_rest(body_skeleton.find_bone("neck_01"))).origin.y
	for mesh_instance: MeshInstance3D in body_skeleton.find_children("*", "MeshInstance3D", false, false):
		if mesh_instance.mesh == null:
			continue
		var copy := _copy_mesh(mesh_instance)
		if String(mesh_instance.name).begins_with("SuperHero") or String(mesh_instance.name).begins_with("Superhero"):
			copy.mesh = _head_only(copy.mesh, neck_y + 0.02)
			copy.name = "Head"
		skeleton.add_child(copy)
	body.free()
	# Зачіски.
	for hair: String in look.hair:
		var hair_scene: Node3D = load(PEOPLE + hair + ".gltf").instantiate()
		for mesh_instance: MeshInstance3D in hair_scene.find_children("*", "MeshInstance3D", true, false):
			skeleton.add_child(_copy_mesh(mesh_instance))
		hair_scene.free()
	source.free()
	_merge_by_material(skeleton)
	for mesh_instance: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", false, false):
		mesh_instance.mesh = _with_lods(mesh_instance.mesh)
	# Рух.
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

## Частини з однаковою текстурою (руки, тіло, ноги, взуття, пояси...)
## зливаються в один меш: замість 8-14 команд відеокарті — 3-4 на жителя.
## Скіни в усіх частин однакові (ті самі 65 кісток у тому ж порядку).
func _merge_by_material(skeleton: Skeleton3D) -> void:
	var parts: Array[MeshInstance3D] = []
	for node in skeleton.get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).skin != null:
			parts.append(node)
	if parts.is_empty():
		return
	# Зливаємо лише частини з тим самим скіном (ті самі кістки й пози
	# прив'язки) — брови й очі базового тіла прив'язані інакше, лишаються.
	var skin: Skin = parts[0].skin
	var compatible: Array[MeshInstance3D] = []
	for part in parts:
		if _same_skin(part.skin, skin):
			compatible.append(part)
	if compatible.size() < 2:
		return
	var groups := {}
	var order: Array = []
	for part in compatible:
		for s in part.mesh.get_surface_count():
			var material := part.mesh.surface_get_material(s)
			var key := _material_key(material)
			if not groups.has(key):
				groups[key] = []
				order.append(key)
			groups[key].append([part, s, material])
	var merged := ArrayMesh.new()
	for key in order:
		var eight := false
		for entry: Array in groups[key]:
			var mi: MeshInstance3D = entry[0]
			if mi.mesh.surface_get_format(entry[1]) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
				eight = true
		var st := SurfaceTool.new()
		st.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS if eight else SurfaceTool.SKIN_4_WEIGHTS)
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for entry: Array in groups[key]:
			var mi: MeshInstance3D = entry[0]
			st.append_from(mi.mesh, entry[1], mi.transform)
		var arrays := st.commit_to_arrays()
		for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arrays[c] = null
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if eight else 0
		merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		merged.surface_set_material(merged.get_surface_count() - 1, groups[key][0][2])
	for part in compatible:
		skeleton.remove_child(part)
		part.free()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = merged
	body.skin = skin
	body.skeleton = NodePath("..")
	skeleton.add_child(body)

## Рівні деталізації: з відстані камери (~11 м) житель займає небагато
## пікселів — відеокарта малює спрощену модель (Godot сам обирає рівень).
static func _with_lods(mesh: Mesh) -> ArrayMesh:
	var importer := ImporterMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var flags: int = mesh.surface_get_format(s) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mesh.surface_get_material(s), "", flags)
	importer.generate_lods(60.0, 25.0, [])
	return importer.get_mesh()

static func _same_skin(a: Skin, b: Skin) -> bool:
	if a.get_bind_count() != b.get_bind_count():
		return false
	for i in a.get_bind_count():
		if a.get_bind_name(i) != b.get_bind_name(i) or not a.get_bind_pose(i).is_equal_approx(b.get_bind_pose(i)):
			return false
	return true

static func _material_key(material: Material) -> String:
	var standard := material as StandardMaterial3D
	if standard != null and standard.albedo_texture != null:
		return "%s|%s" % [standard.albedo_texture.resource_path, standard.albedo_color.to_html()]
	return str(material.get_instance_id()) if material != null else "none"

func _copy_mesh(source: MeshInstance3D) -> MeshInstance3D:
	var copy := MeshInstance3D.new()
	copy.name = source.name
	copy.mesh = source.mesh.duplicate(true)
	copy.skin = source.skin.duplicate(true) if source.skin != null else null
	copy.transform = source.transform
	copy.skeleton = NodePath("..")
	copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return copy

## Відтінок одягу: копія матеріалу з помноженим кольором.
func _tint(mesh_instance: MeshInstance3D, tint: Color) -> void:
	if tint == Color(1, 1, 1):
		return
	for s in mesh_instance.mesh.get_surface_count():
		var material := mesh_instance.mesh.surface_get_material(s) as StandardMaterial3D
		if material == null:
			continue
		material = material.duplicate() as StandardMaterial3D
		material.albedo_color = material.albedo_color * tint
		mesh_instance.mesh.surface_set_material(s, material)

## Лише голова: трикутники, усі вершини яких вище шиї.
func _head_only(mesh: Mesh, min_y: float) -> ArrayMesh:
	var result := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for t in range(0, indices.size(), 3):
			var a := indices[t]
			var b := indices[t + 1]
			var c := indices[t + 2]
			if vertices[a].y >= min_y and vertices[b].y >= min_y and vertices[c].y >= min_y:
				kept.append_array([a, b, c])
		arrays[Mesh.ARRAY_INDEX] = kept
		# Той самий формат, що в оригіналу (8 ваг кісток, свої канали тощо),
		# але без стискання — масиви вже розпаковані.
		var flags: int = mesh.surface_get_format(s) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		var blend: Array = mesh.surface_get_blend_shape_arrays(s) if mesh is ArrayMesh else []
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blend, {}, flags)
		result.surface_set_material(s, mesh.surface_get_material(s))
	return result

func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)
