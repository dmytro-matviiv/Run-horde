extends Node
## БУДІВНИК ПРИХИСТКУ: складає локацію за планом HavenLayout. Запуск (у
## test_env або в редакторі, зупинивши гру):
##   godot --path <проєкт> res://dev_scripts/haven/haven_builder.tscn
##
## На виході три сцени в res://scenes/world/haven/:
##   haven.tscn         — ОСНОВА: небо й сонце, земля (меш + фізика), тверді
##                        коробки стін/домів/дерев, місця жителів і порталу,
##                        ресурси для квестів, вогні, герой, камера;
##   haven_detail.tscn  — ДЕТАЛІ для середньої/високої якості: стіни, сходи,
##                        будинки, реквізит, природа — звичайними вузлами
##                        (їх можна правити в редакторі);
##   haven_lite.tscn    — ті самі деталі для НИЗЬКОЇ якості (слабкий телефон):
##                        усе нерухоме злите у великі шматки за матеріалом,
##                        моделі спрощені, освітлення рахується у вершинах.
##                        Картинка та сама, а відеочипу — у рази легше.
## haven.gd сам підвантажує деталі під поточну якість.
##
## Перезапуск будівника перезаписує всі три сцени (ручні правки — у плані
## HavenLayout чи тут).

const L := preload("res://dev_scripts/haven/haven_layout.gd")
const V := "res://assets/models/haven/village/"
const N := "res://assets/models/haven/nature/"
const P := "res://assets/models/haven/props/"
const F := "res://assets/models/haven/forest/"
const OUT_DIR := "res://scenes/world/haven/"
const OUT_SCENE := OUT_DIR + "haven.tscn"
const OUT_DETAIL := OUT_DIR + "haven_detail.tscn"
const OUT_LITE := OUT_DIR + "haven_lite.tscn"
const OUT_MESH := OUT_DIR + "terrain_mesh.res"
const OUT_SHAPE := OUT_DIR + "terrain_shape.res"
const MESH_DIR := OUT_DIR + "meshes/"
const LITE_DIR := OUT_DIR + "lite/"

## Сходи: модель має підйом 1.82 м на два марші, а тераса — 2 м.
const STAIR_Y_SCALE := 2.0 / 1.82

## Тверді групи: частка габаритів моделі, що стає коробкою (дахи й ґанки
## виступають — повна коробка не пускала б до дверей).
const SOLID_GROUPS := {
	"Architecture/Walls": 1.0,
	"Architecture/Pillars": 0.9,
	"Architecture/Houses": 0.92,
	"Architecture/Stations": 0.7,
	"Architecture/Camp": 0.7,
	"Architecture/Portal": 0.85,
	"Nature/BigTrees": 0.18,
	"Nature/Forest": 0.2,
	"Nature/Rocks": 0.7,
	"Nature/Cliffs": 0.8,
}

## Наскільки можна спростити модель у полегшеній версії: найбільша похибка
## форми в метрах (камера далеко — дрібні фаски однаково не видно).
const LITE_ERROR := {
	"Architecture/Walls": 0.1, "Architecture/Pillars": 0.2, "Architecture/Trim": 0.06,
	"Architecture/Stairs": 0.05, "Architecture/Plaza": 0.05, "Architecture/Houses": 0.5,
	"Architecture/Stations": 0.08, "Architecture/Camp": 0.2, "Architecture/Portal": 0.1,
	"Nature/Forest": 1.5, "Nature/BigTrees": 0.35, "Nature/Bushes": 0.12, "Nature/Grass": 0.35,
	"Nature/Rocks": 1.0, "Nature/Cliffs": 2.5,
}
const NATURE_CELL := 32.0

var _core: Node3D
var _detail: Node3D
var _rng := RandomNumberGenerator.new()
## Де запекти тінь у землю (без справжніх тіней на телефоні): [точка XZ, радіус].
var _shade: Array = []
var _cache := {}

func _ready() -> void:
	_rng.seed = 20261113
	for dir in [MESH_DIR, LITE_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)
	_core = Node3D.new()
	_core.name = "Haven"
	_detail = Node3D.new()
	_detail.name = "Detail"
	_build_environment()
	_build_terraces()
	_build_stairs()
	_build_plaza()
	_build_houses()
	_build_portal_base()
	_build_nature()
	_build_resources()
	_build_spawn_camp()
	_build_terrain()
	_build_markers()
	_build_colliders()
	_take_player_and_hud()
	# Скрипт — в останню чергу: до цього вузли лише складаються.
	_core.set_script(load("res://scenes/world/haven/haven.gd"))
	print("HAVEN core err=", _save_scene(_core, OUT_SCENE))
	print("HAVEN detail err=", _save_scene(_detail, OUT_DETAIL))
	var lite := _bake_lite()
	print("HAVEN lite err=", _save_scene(lite, OUT_LITE))
	get_tree().quit(0)

func _save_scene(root: Node, path: String) -> int:
	_set_owner(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	return err

# --- допоміжне ---

## Група за шляхом: архітектура й природа — у сцену деталей, решта — в основу.
func _group(path: String) -> Node3D:
	var parent: Node = _detail if path.begins_with("Architecture") or path.begins_with("Nature") else _core
	for part in path.split("/"):
		var child := parent.get_node_or_null(part)
		if child == null:
			child = Node3D.new()
			child.name = part
			parent.add_child(child)
		parent = child
	return parent as Node3D

func _place(path: String, group: String, pos: Vector3, yaw: float = 0.0, scale: Vector3 = Vector3.ONE) -> Node3D:
	if not _cache.has(path):
		_cache[path] = load(path)
	var scene: PackedScene = _cache[path]
	var node: Node3D = scene.instantiate()
	_group(group).add_child(node)
	node.position = pos
	node.rotation.y = yaw
	node.scale = scale
	return node

func _place_mesh(mesh: Mesh, group: String, pos: Vector3, yaw: float, scale: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	_group(group).add_child(node)
	node.position = pos
	node.rotation.y = yaw
	node.scale = scale
	return node

## Висота землі в точці (без пандусів сходів — на чому стоять речі).
func _ground(x: float, z: float) -> float:
	return L.ground(x, z)

func _set_owner(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		# Усередину вставлених сцен не лізем — їхні вузли належать їм.
		if child.scene_file_path == "":
			_set_owner(child, owner)

## Світове положення вузла (сцени будівника не в дереві — множимо самі).
func _world_xf(node: Node3D) -> Transform3D:
	var xf := node.transform
	var parent := node.get_parent()
	while parent != null and parent is Node3D:
		xf = (parent as Node3D).transform * xf
		parent = parent.get_parent()
	return xf

## Габарити всіх мешів вузла у світі.
func _bounds(object: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	var meshes: Array = object.find_children("*", "MeshInstance3D", true, false)
	if object is MeshInstance3D:
		meshes.append(object)
	for node in meshes:
		var visual := node as MeshInstance3D
		if visual.mesh == null:
			continue
		var box: AABB = _world_xf(visual) * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds

# --- середовище ---

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	# Небо не міняється — його відбиток для освітлення досить малого.
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.56, 0.82)
	sky_mat.sky_horizon_color = Color(0.86, 0.82, 0.7)
	sky_mat.ground_horizon_color = Color(0.7, 0.64, 0.52)
	sky_mat.ground_bottom_color = Color(0.3, 0.28, 0.22)
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.6, 0.58)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 6.0
	# Серпанок: далекі пагорби тонуть у теплому повітрі (і ховають край).
	e.fog_enabled = true
	e.fog_light_color = Color(0.86, 0.8, 0.66)
	e.fog_density = 0.006
	e.fog_sky_affect = 0.4
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	e.adjustment_contrast = 1.05
	env.environment = e
	_core.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# Тепле низьке сонце збоку-ззаду: схили й стіни мають світлий і тіньовий бік.
	sun.rotation_degrees = Vector3(-48.0, 38.0, 0.0)
	sun.light_color = Color(1.0, 0.9, 0.74)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	_core.add_child(sun)

# --- рельєф ---

func _build_terrain() -> void:
	var count := int(L.SIZE / L.STEP) + 1
	var half := L.SIZE * 0.5
	# Фізика — рівна сітка висот (із пандусами під сходами).
	var heights := PackedFloat32Array()
	heights.resize(count * count)
	for j in count:
		for i in count:
			heights[j * count + i] = L.height(-half + i * L.STEP, -half + j * L.STEP)
	var material := ShaderMaterial.new()
	material.shader = load(OUT_DIR + "haven_terrain.gdshader")
	material.set_shader_parameter(&"detail", load("res://assets/textures/town/town_noise.png"))
	var body := StaticBody3D.new()
	body.name = "Terrain"
	_core.add_child(body)
	# Видима земля — шматки 4×4 (те, що поза кадром, відеокарта не малює).
	# Вершини беремо з L.visual_vertex: під сходами земля опущена, схили
	# терас заховані в стіни.
	var pieces := 4
	var cells := (count - 1) / pieces
	for pj in pieces:
		for pi in pieces:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in cells + 1:
				for i in cells + 1:
					var x := -half + (pi * cells + i) * L.STEP
					var z := -half + (pj * cells + j) * L.STEP
					var vertex := L.visual_vertex(x, z)
					st.set_color(_terrain_mask(x, z, vertex.y))
					st.add_vertex(vertex)
			for j in cells:
				for i in cells:
					var a := j * (cells + 1) + i
					var b := a + 1
					var c := a + cells + 1
					var d := c + 1
					st.add_index(a); st.add_index(b); st.add_index(c)
					st.add_index(b); st.add_index(d); st.add_index(c)
			st.generate_normals()
			var mesh := st.commit()
			mesh.surface_set_material(0, material)
			var path := OUT_MESH.replace(".res", "_%d_%d.res" % [pi, pj])
			ResourceSaver.save(mesh, path)
			var visual := MeshInstance3D.new()
			visual.name = "TerrainMesh_%d_%d" % [pi, pj]
			visual.mesh = load(path)
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(visual)
	var shape := HeightMapShape3D.new()
	shape.map_width = count
	shape.map_depth = count
	shape.map_data = heights
	ResourceSaver.save(shape, OUT_SHAPE)
	var collision := CollisionShape3D.new()
	collision.name = "TerrainShape"
	collision.shape = load(OUT_SHAPE)
	collision.scale = Vector3(L.STEP, 1.0, L.STEP)
	body.add_child(collision)

## Маска землі (стежки, камінь, тінь) + запечена тінь під деревами й домами.
func _terrain_mask(x: float, z: float, h: float) -> Color:
	var m := L.mask(x, z, h)
	var p := Vector2(x, z)
	for spot: Array in _shade:
		var d := p.distance_to(spot[0])
		var r: float = spot[1]
		if d < r:
			m.b = maxf(m.b, (1.0 - smoothstep(r * 0.35, r, d)) * 0.75)
	return m

# --- тераси й стіни ---

## Підпірна стіна по периметру тераси, з проходами під сходи.
func _build_terraces() -> void:
	_terrace_walls(L.LOW_TERRACE, L.LOW_HEIGHT)
	_terrace_walls(L.HIGH_TERRACE, L.HIGH_HEIGHT)

func _terrace_walls(rect: Rect2, top: float) -> void:
	# Стіна виходить на 0.1 м над терасою, по ній — кам'яна плита й
	# дерев'яні поручні: край тераси читається, а падати нікуди.
	var base := top + 0.1 - 3.12
	var offset := 0.32
	var sides := [
		[Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), Vector2(0, 1)],
		[Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y), Vector2(0, -1)],
		[Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y), Vector2(1, 0)],
		[Vector2(rect.position.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Vector2(-1, 0)],
	]
	for side: Array in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var normal: Vector2 = side[2]
		var dir := (b - a).normalized()
		for k in int(round(a.distance_to(b) / 2.0)):
			var mid := a + dir * (k * 2.0 + 1.0)
			if _stair_gap(mid, normal, top):
				continue
			var pos := mid + normal * offset
			var yaw := atan2(normal.x, normal.y)
			_place(V + "Wall_UnevenBrick_Straight.gltf", "Architecture/Walls", Vector3(pos.x, base, pos.y), yaw)
			# Плита лежить на стіні й трохи звисає назовні.
			var slab := mid - normal * 0.12
			_place(V + "Prop_ExteriorBorder_Straight1.gltf", "Architecture/Trim", Vector3(slab.x, top + 0.1, slab.y), yaw)
			var rail := mid + normal * 0.2
			_place(V + "Prop_WoodenFence_Single.gltf", "Architecture/Trim", Vector3(rail.x, top + 0.2, rail.y), yaw)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var c: Vector2 = corner
		var out := Vector2(signf(c.x - rect.get_center().x), signf(c.y - rect.get_center().y))
		var at := c + out * 0.2
		_pillar(Vector3(at.x, top + 0.5 - 3.6, at.y), Vector3(1.0, 3.6, 1.0))

## Чи цей шматок стіни — прохід під сходи.
func _stair_gap(mid: Vector2, normal: Vector2, top: float) -> bool:
	for s: Array in L.STAIRS:
		var dir: Vector2 = s[2]
		if not is_equal_approx(float(s[3]), top) or dir.dot(normal) < 0.9:
			continue
		var center := Vector2(s[0], s[1])
		var side := Vector2(-dir.y, dir.x)
		if absf((mid - center).dot(side)) < float(s[4]) * 0.5 + 0.9 and absf((mid - center).dot(dir)) < 1.5:
			return true
	return false

## Кам'яний стовп: коробка з тим самим камінням, що й підпірні стіни
## (текстура стіни плиткова: 2 м на повтор), зверху — кам'яна плита.
## base — центр низу, size — ширина, висота, глибина.
func _pillar(base: Vector3, size: Vector3) -> void:
	var key := "pillar_%d_%d_%d" % [roundi(size.x * 100), roundi(size.y * 100), roundi(size.z * 100)]
	if not _cache.has(key):
		var path := MESH_DIR + key + ".res"
		ResourceSaver.save(_brick_box(size), path)
		_cache[key] = load(path)
	_place_mesh(_cache[key], "Architecture/Pillars", base, 0.0, Vector3.ONE)
	_place(V + "Prop_ExteriorBorder_Straight1.gltf", "Architecture/Trim",
		base + Vector3(0, size.y, -(size.z + 0.2) * 0.5), 0.0, Vector3((size.x + 0.2) / 2.0, 1.0, (size.z + 0.2) / 0.7))

## Коробка без дна з камінням стін: чотири боки й верх.
func _brick_box(size: Vector3) -> ArrayMesh:
	if not _cache.has("brick_material"):
		var wall: Node3D = load(V + "Wall_UnevenBrick_Straight.gltf").instantiate()
		for visual: MeshInstance3D in wall.find_children("*", "MeshInstance3D", true, false):
			for surface in visual.mesh.get_surface_count():
				var material := visual.mesh.surface_get_material(surface) as BaseMaterial3D
				if material != null and material.albedo_texture != null and material.albedo_texture.resource_path.contains("UnevenBrick"):
					_cache["brick_material"] = material
		wall.free()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	# Боки: [нормаль, вісь уздовж грані, ширина].
	for face: Array in [[Vector3(0, 0, 1), Vector3(1, 0, 0), size.x, hz], [Vector3(0, 0, -1), Vector3(-1, 0, 0), size.x, hz],
			[Vector3(1, 0, 0), Vector3(0, 0, -1), size.z, hx], [Vector3(-1, 0, 0), Vector3(0, 0, 1), size.z, hx]]:
		var normal: Vector3 = face[0]
		var along: Vector3 = face[1]
		var width: float = face[2]
		var center: Vector3 = normal * float(face[3])
		var a := center - along * width * 0.5
		var b := center + along * width * 0.5
		var corners := [[a, 0.0, size.y], [b, width, size.y], [b + Vector3.UP * size.y, width, 0.0], [a + Vector3.UP * size.y, 0.0, 0.0]]
		for index in [0, 2, 1, 0, 3, 2]:
			var corner: Array = corners[index]
			st.set_normal(normal)
			st.set_uv(Vector2(float(corner[1]) / 2.0, float(corner[2]) / 2.11))
			st.add_vertex(corner[0])
	var top := [Vector3(-hx, size.y, -hz), Vector3(hx, size.y, -hz), Vector3(hx, size.y, hz), Vector3(-hx, size.y, hz)]
	for index in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(top[index].x / 2.0, top[index].z / 2.11))
		st.add_vertex(top[index])
	st.index()
	st.generate_tangents()
	var mesh := st.commit()
	mesh.surface_set_material(0, _cache["brick_material"])
	return mesh

## Масиви лише з тим, що потрібно простому мешу (без ваг, кольорів тощо).
func _plain_arrays(arrays: Array) -> Array:
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	for channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
		result[channel] = arrays[channel]
	return result

# --- сходи ---

## Марш — дві деталі сходів одна над одною (верхня стоїть на помості).
## Деталь 2 м завширшки розтягнута на всю ширину проходу: бічні стінки
## сходів стають по краях, а не посередині.
func _build_stairs() -> void:
	for s: Array in L.STAIRS:
		var center := Vector2(s[0], s[1])
		var dir: Vector2 = s[2]
		var top: float = s[3]
		var width: float = s[4]
		var side := Vector2(-dir.y, dir.x)
		var yaw := atan2(dir.x, dir.y)
		var scale := Vector3(width / 2.0, STAIR_Y_SCALE, 1.0)
		var upper := center + dir * 1.0
		var lower := center + dir * 3.0
		_place(V + "Stairs_Exterior_Straight.gltf", "Architecture/Stairs", Vector3(lower.x, top - 2.0, lower.y), yaw, scale)
		_place(V + "Stairs_Exterior_Platform.gltf", "Architecture/Stairs", Vector3(upper.x, top - 2.0, upper.y), yaw, scale)
		_place(V + "Stairs_Exterior_Straight.gltf", "Architecture/Stairs", Vector3(upper.x, top - 2.0 + STAIR_Y_SCALE, upper.y), yaw, scale)
		# Обабіч верху сходів — кам'яні стовпчики з вогнем.
		for k: int in [-1, 1]:
			var p := center - dir * 0.7 + side * (width * 0.5 + 0.75) * k
			_pillar(Vector3(p.x, top, p.y), Vector3(0.75, 1.3, 0.75))
			_fire_marker(Vector3(p.x, top + 1.5, p.y))

# --- площа ---

func _build_plaza() -> void:
	var r := L.PLAZA
	var y := L.LOW_HEIGHT + 0.03
	var x := r.position.x + 1.0
	while x < r.end.x:
		var z := r.position.y + 1.0
		while z < r.end.y:
			# Клумба посередині — трава й велике дерево.
			if Vector2(x - L.PLAZA_TREE.x, z - L.PLAZA_TREE.z).length() > L.PLAZA_TREE_RADIUS:
				_place(V + "Floor_UnevenBrick.gltf", "Architecture/Plaza", Vector3(x, y, z), 0.0)
			z += 2.0
		x += 2.0
	# Бруківка-стежка від площі до сходів (південь і північ).
	for z: float in [11.0, 13.0, -7.0, -9.0]:
		for x2: float in [-1.0, 1.0]:
			_place(V + "Floor_UnevenBrick.gltf", "Architecture/Plaza", Vector3(x2, y, z), 0.0)
	# Бордюр по краю площі.
	for i in int(r.size.x / 2.0):
		var cx := r.position.x + 1.0 + i * 2.0
		if absf(cx) < 2.0:
			continue
		_place(V + "Prop_ExteriorBorder_Straight1.gltf", "Architecture/Trim", Vector3(cx, L.LOW_HEIGHT, r.end.y), PI)
		_place(V + "Prop_ExteriorBorder_Straight1.gltf", "Architecture/Trim", Vector3(cx, L.LOW_HEIGHT, r.position.y), 0.0)

# --- будиночки (з модулів) ---

## Невеликий будинок: кам'яний перший поверх, тиньк із деревом нагорі, дах
## із черепиці, вікна й двері. w, d — у клітинках по 2 м; двері — з боку
## local +Z (його повертає yaw).
func _house(origin: Vector3, w: int, d: int, yaw: float) -> void:
	var holder := Node3D.new()
	holder.name = "House%d" % _group("Architecture/Houses").get_child_count()
	_group("Architecture/Houses").add_child(holder)
	holder.position = origin
	holder.rotation.y = yaw
	_shade.append([Vector2(origin.x, origin.z) + Vector2(1.5, 1.5), float(maxi(w, d)) * 2.2])
	var add := func(file: String, pos: Vector3, rot: float) -> void:
		var piece: Node3D = load(V + file).instantiate()
		holder.add_child(piece)
		piece.position = pos
		piece.rotation.y = rot
	for side in 4:
		var count := w if side < 2 else d
		for k in count:
			var t := (k * 2.0 + 1.0) - count
			var pos: Vector3
			var rot: float
			match side:
				0: pos = Vector3(t, 0, d); rot = 0.0
				1: pos = Vector3(-t, 0, -d); rot = PI
				2: pos = Vector3(w, 0, -t); rot = PI * 0.5
				_: pos = Vector3(-w, 0, t); rot = -PI * 0.5
			if side == 0 and k == count / 2:
				add.call("Wall_UnevenBrick_Door_Round.gltf", pos, rot)
				add.call("Door_1_Round.gltf", pos, rot)
			elif (k + side) % 2 == 1:
				add.call("Wall_UnevenBrick_Window_Wide_Round.gltf", pos, rot)
				add.call("Window_Wide_Round1.gltf", pos, rot)
			else:
				add.call("Wall_UnevenBrick_Straight.gltf", pos, rot)
			var up := pos + Vector3.UP * 3.0
			if (k + side) % 2 == 0:
				add.call("Wall_Plaster_Window_Wide_Round.gltf", up, rot)
				add.call("Window_Wide_Round1.gltf", up, rot)
			else:
				add.call("Wall_Plaster_WoodGrid.gltf", up, rot)
	for c in [Vector3(w, 0, d), Vector3(-w, 0, d), Vector3(w, 0, -d), Vector3(-w, 0, -d)]:
		for level in 2:
			add.call("Corner_Exterior_Wood.gltf", c + Vector3.UP * 3.0 * level, 0.0)
	# Дах: найближчий за розміром модуль черепиці.
	var roof_name := "Roof_RoundTiles_%dx%d.gltf" % [mini(w * 2, 8), mini(d * 2, 14)]
	if not ResourceLoader.exists(V + roof_name):
		roof_name = "Roof_RoundTiles_6x8.gltf"
	add.call(roof_name, Vector3(0, 6.0, 0), 0.0)
	add.call("Prop_Chimney.gltf", Vector3(w - 1.0, 6.3, -d + 1.0), 0.0)

func _build_houses() -> void:
	var y := L.LOW_HEIGHT
	# Будинки в кутах тераси, двері — до площі.
	_house(Vector3(-17.0, y, 9.0), 2, 2, PI * 0.5)
	_house(Vector3(17.0, y, 9.0), 2, 2, -PI * 0.5)
	_house(Vector3(-17.0, y, -24.0), 2, 3, PI * 0.5)
	_house(Vector3(17.0, y, -24.0), 2, 3, -PI * 0.5)
	_build_stations()

## Робочі місця жителів: реквізит довкола кожного — видно, хто чим зайнятий.
func _station(npc: StringName, items: Array) -> void:
	var info: Array = L.NPCS[npc]
	var origin: Vector3 = info[0]
	var yaw: float = info[1]
	var basis := Basis(Vector3.UP, yaw)
	for item: Array in items:
		var local: Vector3 = item[1]
		var pos: Vector3 = origin + basis * local
		_place(P + String(item[0]) + ".gltf", "Architecture/Stations", Vector3(pos.x, origin.y + local.y, pos.z),
			yaw + float(item[2]))

func _build_stations() -> void:
	# Наставниця героїв — тренувальні манекени, стійка зі зброєю, щит, лава.
	_station(&"mentor", [["Dummy", Vector3(-1.8, 0, -1.6), 0.4], ["Dummy", Vector3(1.6, 0, -2.2), -0.3],
		["WeaponStand", Vector3(-2.4, 0, 0.6), 1.2], ["Shield_Wooden", Vector3(0.4, 0, -2.6), 0.2], ["Bench", Vector3(2.6, 0, 0.8), -1.2]])
	# Коваль — ковадло на колоді, верстак, стійка зброї, бочка.
	_station(&"smith", [["Anvil_Log", Vector3(0.0, 0, 1.4), 0.0], ["Workbench", Vector3(-2.2, 0, -1.2), 0.3],
		["WeaponStand", Vector3(2.4, 0, -0.8), -0.8], ["Barrel", Vector3(-2.6, 0, 1.2), 0.0], ["Crate_Metal", Vector3(2.2, 0, 1.6), 0.4]])
	# Мудрець — пюпітр із книгою, свічки, казан, книжкова шафа, скриня.
	_station(&"sage", [["BookStand", Vector3(0.0, 0, 1.3), PI], ["CandleStick_Stand", Vector3(-1.4, 0, 1.0), 0.0],
		["CandleStick_Stand", Vector3(1.4, 0, 1.0), 0.0], ["Cauldron", Vector3(-2.4, 0, -1.0), 0.0], ["Bookcase_2", Vector3(1.8, 0, -2.0), -0.3],
		["Chest_Wood", Vector3(-1.2, 0, -2.2), 0.5]])
	# Торговка — візок-ятка, бочка з яблуками, ящики, мішки.
	_station(&"merchant", [["Stall_Cart_Empty", Vector3(0.6, 0, -1.4), PI], ["Barrel_Apples", Vector3(-2.2, 0, -0.2), 0.0],
		["FarmCrate_Apple", Vector3(-2.0, 0, 1.2), 0.3], ["Crate_Wooden", Vector3(2.6, 0, 0.4), 0.2], ["Bag", Vector3(1.8, 0, 1.6), 0.0],
		["Pouch_Large", Vector3(-1.0, 0, 1.8), 0.0]])
	# Старійшина — скриня і стіл із сувоями під деревом.
	_station(&"elder", [["Chest_Wood", Vector3(-2.0, 0, -0.4), 0.3], ["Table_Large", Vector3(2.2, 0, -0.4), -0.3],
		["Scroll_1", Vector3(2.0, 0.81, -0.4), 0.2], ["Scroll_2", Vector3(2.5, 0.81, -0.2), -0.4]])
	_shade.append([Vector2(L.PLAZA_TREE.x, L.PLAZA_TREE.z), 3.6])
	_place(N + "CommonTree_3.gltf", "Nature/BigTrees", L.PLAZA_TREE, 0.4, Vector3.ONE * 0.95)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		_place(P + "Bench.gltf", "Architecture/Stations", L.PLAZA_TREE + Vector3(cos(a), 0, sin(a)) * (L.PLAZA_TREE_RADIUS + 0.4),
			-a + PI * 0.5)

# --- поміст порталу (арка, бруківка, стовпчики; сам вихор малює HavenPortal) ---

func _build_portal_base() -> void:
	var o := L.PORTAL
	var group := "Architecture/Portal"
	for x in 3:
		for z in 3:
			_place(V + "Floor_UnevenBrick.gltf", "Architecture/Plaza", o + Vector3((x - 1) * 2.0, 0.03, (z - 1) * 2.0), 0.0)
	for k in 3:
		var t := (k - 1) * 2.0
		_place(V + "Prop_ExteriorBorder_Straight1.gltf", "Architecture/Trim", o + Vector3(t, 0.0, 3.0), PI)
		_place(V + "Prop_ExteriorBorder_Straight1.gltf", "Architecture/Trim", o + Vector3(t, 0.0, -3.0), 0.0)
		_place(V + "Prop_ExteriorBorder_Straight1.gltf", "Architecture/Trim", o + Vector3(3.0, 0.0, t), -PI * 0.5)
		_place(V + "Prop_ExteriorBorder_Straight1.gltf", "Architecture/Trim", o + Vector3(-3.0, 0.0, t), PI * 0.5)
	_place(V + "DoorFrame_Round_Brick.gltf", group, o + Vector3(0, 0.03, 0), 0.0, Vector3.ONE * L.PORTAL_ARCH_SCALE)
	for x: float in [-L.PORTAL_FIRE_X, L.PORTAL_FIRE_X]:
		_pillar(o + Vector3(x, 0.0, 0.6), Vector3(0.85, 1.68, 0.85))

# --- природа ---

func _scatter(files: Array, group: String, count: int, area: Rect2, avoid: Callable, scale_range: Vector2,
		min_gap: float = 2.0) -> void:
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < count and tries < count * 30:
		tries += 1
		var p := Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
		if avoid.call(p):
			continue
		var close := false
		for q in placed:
			if q.distance_to(p) < min_gap:
				close = true
				break
		if close:
			continue
		placed.append(p)
		var s := _rng.randf_range(scale_range.x, scale_range.y)
		if group.contains("Tree") or group.contains("Forest"):
			_shade.append([p, 2.6 * s])
		_place(files[_rng.randi() % files.size()], group, Vector3(p.x, _ground(p.x, p.y) - 0.05, p.y),
			_rng.randf() * TAU, Vector3.ONE * s)

## Чи місце зайняте (тераси, стежки, сходи, табір) — природі туди не можна.
func _busy(p: Vector2, margin: float = 1.5) -> bool:
	for rect: Rect2 in [L.LOW_TERRACE, L.HIGH_TERRACE]:
		if rect.grow(margin).has_point(p):
			return true
	if L.mask(p.x, p.y, 0.0).r > 0.05:
		return true
	for s: Array in L.STAIRS:
		var rel := p - Vector2(s[0], s[1])
		var dir: Vector2 = s[2]
		if absf(rel.dot(Vector2(-dir.y, dir.x))) < float(s[4]) * 0.5 + 1.5 and rel.dot(dir) > -1.0 and rel.dot(dir) < 7.0:
			return true
	if Vector2(L.SPAWN.x, L.SPAWN.z).distance_to(p) < 7.0:
		return true
	return false

func _build_nature() -> void:
	var big_trees := [N + "CommonTree_1.gltf", N + "CommonTree_2.gltf", N + "CommonTree_3.gltf", N + "Pine_1.gltf", N + "Pine_3.gltf"]
	var kay_trees := [F + "Tree_1_A_Color1.gltf", F + "Tree_2_A_Color1.gltf", F + "Tree_3_A_Color1.gltf",
		F + "Tree_4_A_Color1.gltf", F + "Tree_1_B_Color1.gltf", F + "Tree_2_B_Color1.gltf"]
	var outside := func(p: Vector2) -> bool:
		var e := Vector2((p.x - L.BOWL_CENTER.x) / L.BOWL_RADIUS.x, (p.y - L.BOWL_CENTER.y) / L.BOWL_RADIUS.y).length()
		return e < 0.92 or e > 1.45
	# Ліс на схилах довкола — легкі дерева KayKit, збільшені.
	_scatter(kay_trees, "Nature/Forest", 150, Rect2(-80, -80, 160, 160), outside, Vector2(1.7, 2.6), 4.2)
	# Кілька великих красенів Quaternius там, де їх видно.
	var near_edge := func(p: Vector2) -> bool:
		var e := Vector2((p.x - L.BOWL_CENTER.x) / L.BOWL_RADIUS.x, (p.y - L.BOWL_CENTER.y) / L.BOWL_RADIUS.y).length()
		return e < 0.7 or e > 0.95 or _busy(p)
	_scatter(big_trees, "Nature/BigTrees", 12, Rect2(-60, -60, 120, 120), near_edge, Vector2(0.9, 1.15), 7.0)
	# Кущі, квіти, папороть по галявинах.
	var meadow := func(p: Vector2) -> bool: return _busy(p, 0.5)
	_scatter([N + "Bush_Common.gltf", N + "Bush_Common_Flowers.gltf", N + "Fern_1.gltf", N + "Plant_1_Big.gltf"],
		"Nature/Bushes", 26, Rect2(-52, -54, 104, 108), meadow, Vector2(0.7, 1.2), 3.0)
	_scatter([F + "Bush_1_A_Color1.gltf", F + "Bush_2_A_Color1.gltf", F + "Bush_3_A_Color1.gltf", F + "Bush_4_A_Color1.gltf"],
		"Nature/Bushes", 40, Rect2(-52, -54, 104, 108), meadow, Vector2(3.5, 5.0), 3.0)
	_scatter([N + "Flower_3_Group.gltf", N + "Flower_4_Group.gltf"], "Nature/Grass", 40, Rect2(-52, -54, 104, 108),
		meadow, Vector2(0.45, 0.7), 2.5)
	_scatter([F + "Grass_1_A_Color1.gltf", F + "Grass_2_A_Color1.gltf", F + "Grass_1_B_Color1.gltf", F + "Grass_2_B_Color1.gltf"],
		"Nature/Grass", 320, Rect2(-52, -54, 104, 108), meadow, Vector2(1.2, 1.8), 1.4)
	_scatter([N + "Rock_Medium_1.gltf", N + "Rock_Medium_2.gltf", N + "Rock_Medium_3.gltf"],
		"Nature/Rocks", 26, Rect2(-60, -62, 120, 124), meadow, Vector2(0.8, 1.8), 6.0)
	# Скелі за верхньою терасою — тло для порталу.
	for i in 9:
		var x := -16.0 + i * 4.0 + _rng.randf_range(-1, 1)
		_place(N + "Rock_Medium_%d.gltf" % (1 + i % 3), "Nature/Cliffs",
			Vector3(x, L.LOW_HEIGHT - 0.5, -34.5 - _rng.randf_range(0, 3)), _rng.randf() * TAU,
			Vector3.ONE * _rng.randf_range(2.6, 3.6))

# --- ресурси для квестів (окремі вузли: їх рубають і збирають) ---

func _build_resources() -> void:
	var grove := Rect2(28, -6, 18, 26)
	var trees := [N + "CommonTree_2.gltf", N + "CommonTree_4.gltf", N + "CommonTree_5.gltf"]
	var spots: Array[Vector2] = []
	while spots.size() < 9:
		var p := Vector2(_rng.randf_range(grove.position.x, grove.end.x), _rng.randf_range(grove.position.y, grove.end.y))
		if L.mask(p.x, p.y, 0.0).r > 0.05:
			continue
		var ok := true
		for q in spots:
			if q.distance_to(p) < 4.5:
				ok = false
		if ok:
			spots.append(p)
	for p in spots:
		_shade.append([p, 2.8])
		var node := _place(trees[_rng.randi() % trees.size()], "Resources/Trees", Vector3(p.x, _ground(p.x, p.y) - 0.05, p.y),
			_rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.75, 0.9))
		node.set_meta(&"resource", "wood")
	var hill: Vector2 = L.WEST_HILL[0]
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := hill + Vector2(cos(a), sin(a)) * _rng.randf_range(4.0, 9.0)
		var node := _place(F + "Rock_3_%s_Color1.gltf" % ["A", "B", "C", "D", "E", "F"][i], "Resources/Stones",
			Vector3(p.x, _ground(p.x, p.y), p.y), _rng.randf() * TAU, Vector3.ONE * 1.6)
		node.set_meta(&"resource", "stone")
	for i in 7:
		var a := TAU * i / 7.0
		var p := hill + Vector2(cos(a), sin(a)) * _rng.randf_range(2.0, 12.0) + Vector2(4, 6)
		var file: String = [N + "Mushroom_Common.gltf", N + "Plant_7.gltf", N + "Flower_3_Group.gltf"][i % 3]
		var node := _place(file, "Resources/Herbs", Vector3(p.x, _ground(p.x, p.y), p.y), _rng.randf() * TAU, Vector3.ONE * 1.2)
		node.set_meta(&"resource", "herb")

# --- табір біля місця появи: багаття, лави, віз, менгіри ---

func _build_spawn_camp() -> void:
	var fire := Vector3(4.5, 0.0, 31.0)
	fire.y = _ground(fire.x, fire.z)
	_place("res://assets/models/dungeon/Woodfire.fbx", "Architecture/Camp", fire, 0.3, Vector3.ONE * 1.3)
	_fire_marker(fire + Vector3.UP * 0.35)
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var p := fire + Vector3(cos(a), 0, sin(a)) * 2.1
		p.y = _ground(p.x, p.z)
		_place(P + "Bench.gltf", "Architecture/Camp", p, -a + PI * 0.5, Vector3(0.7, 1.0, 1.0))
	var wagon := Vector3(-5.5, 0.0, 30.0)
	wagon.y = _ground(wagon.x, wagon.z)
	_place(V + "Prop_Wagon.gltf", "Architecture/Camp", wagon, 0.35)
	_place(P + "Barrel.gltf", "Architecture/Camp", wagon + Vector3(1.6, 0, 1.2), 0.0)
	_place(P + "Crate_Wooden.gltf", "Architecture/Camp", wagon + Vector3(1.9, 0, 0.1), 0.4)
	# Менгіри — старі камені на краю галявини.
	for i in 4:
		var a := -0.9 + i * 0.6
		var p := Vector3(sin(a) * 11.0, 0, 36.0 + cos(a) * 5.0)
		p.y = _ground(p.x, p.z) - 0.2
		_place(N + "Rock_Medium_%d.gltf" % (1 + i % 3), "Nature/Rocks", p, _rng.randf() * TAU,
			Vector3(0.55, 1.5 + 0.3 * (i % 2), 0.55))

func _fire_marker(pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = "Fire%d" % _group("Effects").get_child_count()
	_group("Effects").add_child(marker)
	marker.position = pos

# --- місця жителів і порталу (вузли-мітки: їх оживляє haven.gd) ---

func _build_markers() -> void:
	for id: StringName in L.NPCS:
		var info: Array = L.NPCS[id]
		var marker := Marker3D.new()
		marker.name = "Npc_%s" % id
		marker.set_meta(&"npc", id)
		_group("Npcs").add_child(marker)
		marker.position = info[0]
		marker.rotation.y = info[1]
	var portal := Marker3D.new()
	portal.name = "PortalSpot"
	_core.add_child(portal)
	portal.position = L.PORTAL
	var spawn := Marker3D.new()
	spawn.name = "SpawnSpot"
	_core.add_child(spawn)
	spawn.position = L.SPAWN + Vector3.UP * 0.1

# --- фізика: прості коробки замість точної форми кожної моделі ---

func _build_colliders() -> void:
	var body := StaticBody3D.new()
	body.name = "Colliders"
	_core.add_child(body)
	var count := 0
	for group: String in SOLID_GROUPS:
		var holder := _detail.get_node_or_null(group)
		if holder == null:
			continue
		var shrink: float = SOLID_GROUPS[group]
		for child in holder.get_children():
			var bounds := _bounds(child as Node3D)
			if bounds.size.length() < 0.2:
				continue
			_add_box(body, bounds.get_center(), Vector3(bounds.size.x * shrink, maxf(bounds.size.y, 2.0), bounds.size.z * shrink))
			count += 1
	# Бічні стінки сходів: зі сходів не зійти вбік (там фізичний пандус
	# ширший за видимі сходинки).
	for s: Array in L.STAIRS:
		var center := Vector2(s[0], s[1])
		var dir: Vector2 = s[2]
		var side := Vector2(-dir.y, dir.x)
		for k: int in [-1, 1]:
			var mid := center + dir * 2.0 + side * (float(s[4]) * 0.5 + 0.05) * k
			var size := Vector3(4.0 if absf(dir.x) > 0.5 else 0.3, 4.0, 4.0 if absf(dir.y) > 0.5 else 0.3)
			_add_box(body, Vector3(mid.x, float(s[3]) - 1.0, mid.y), size)
			count += 1
	print("HAVEN colliders: ", count)

func _add_box(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	shape.position = center

# --- герой, камера й шар інтерфейсу (сам інтерфейс складає haven.gd) ---

func _take_player_and_hud() -> void:
	var player: Node3D = load("res://scenes/world/player_3d.tscn").instantiate()
	player.name = "Player"
	_core.add_child(player)
	player.position = L.SPAWN + Vector3.UP * 0.1
	var rig: Node3D = load("res://scenes/world/camera_rig.tscn").instantiate()
	rig.name = "CameraRig"
	_core.add_child(rig)
	rig.set("target_path", NodePath("../Player"))
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	_core.add_child(hud)

# =====================================================================
# ПОЛЕГШЕНА ВЕРСІЯ ДЕТАЛЕЙ (низька якість)
# =====================================================================
#
# Що робимо з кожним нерухомим мешем сцени деталей:
#  1. беремо спрощений рівень моделі (LOD) під дозволену похибку групи;
#  2. переносимо його вершини у світові координати;
#  3. складаємо в одну "купу" з усіма мешами тієї ж зони й того ж матеріалу.
# Купа = одна команда відеокарті замість десятків. Матеріал — копія
# рідного, але без карт нерівностей і блиску та з освітленням у вершинах:
# на пласких стінах і з висоти камери різниці не видно, а піксельний
# шейдер стає в рази коротшим.

var _lite_materials := {}
var _lod_cache := {}

func _bake_lite() -> Node3D:
	# зона -> ключ матеріалу -> {v, n, uv, idx, material}
	var zones := {}
	var totals := {"instances": 0, "source_tris": 0, "tris": 0}
	for group: String in LITE_ERROR:
		var holder := _detail.get_node_or_null(group)
		if holder == null:
			continue
		var max_error: float = LITE_ERROR[group]
		var group_before: int = totals.source_tris
		var group_after: int = totals.tris
		for node in holder.find_children("*", "MeshInstance3D", true, false):
			var visual := node as MeshInstance3D
			if visual.mesh == null:
				continue
			var xf := _world_xf(visual)
			var zone := _zone_of(group, xf.origin)
			var scale := xf.basis.get_scale()
			var biggest := maxf(scale.x, maxf(scale.y, scale.z))
			totals.instances += 1
			for s in visual.mesh.get_surface_count():
				var source := visual.get_active_material(s)
				var lite := _lite_material(source)
				var geo: Dictionary = _lod_geometry(visual.mesh, s, max_error / maxf(biggest, 0.001))
				totals.source_tris += int(geo.source_tris)
				totals.tris += (geo.idx as PackedInt32Array).size() / 3
				if not zones.has(zone):
					zones[zone] = {}
				var key: String = lite.resource_path
				if not zones[zone].has(key):
					zones[zone][key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(),
						"idx": PackedInt32Array(), "material": lite}
				_append(zones[zone][key], geo, xf)
		print("HAVEN lite %-24s tris %6d -> %6d" % [group, totals.source_tris - group_before, totals.tris - group_after])
	var root := Node3D.new()
	root.name = "Lite"
	var names := zones.keys()
	names.sort()
	var surfaces := 0
	for zone: String in names:
		var importer := ImporterMesh.new()
		var keys: Array = zones[zone].keys()
		keys.sort()
		for key: String in keys:
			var bucket: Dictionary = zones[zone][key]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = bucket.v
			arrays[Mesh.ARRAY_NORMAL] = bucket.n
			arrays[Mesh.ARRAY_TEX_UV] = bucket.uv
			arrays[Mesh.ARRAY_INDEX] = bucket.idx
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, bucket.material)
			surfaces += 1
		# Далекі шматки природи відеокарта малює ще простішими.
		if zone.begins_with("nature"):
			importer.generate_lods(60.0, 25.0, [])
		var path := LITE_DIR + zone + ".res"
		ResourceSaver.save(importer.get_mesh(), path, ResourceSaver.FLAG_COMPRESS)
		var visual := MeshInstance3D.new()
		visual.name = zone.capitalize().replace(" ", "")
		visual.mesh = load(path)
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(visual)
	print("HAVEN lite: %d meshes -> %d zones, %d surfaces, tris %d -> %d, materials %d" % [totals.instances,
		names.size(), surfaces, totals.source_tris, totals.tris, _lite_materials.size()])
	return root

## Зона пакування: архітектура — три ділянки (табір, площа, верх із
## порталом), природа — квадрати NATURE_CELL. Зона поза кадром не малюється.
func _zone_of(group: String, at: Vector3) -> String:
	if group.begins_with("Architecture"):
		if at.z > 19.0:
			return "arch_camp"
		if at.z < -13.0 and absf(at.x) < 12.0:
			return "arch_upper"
		return "arch_plaza"
	return "nature_%d_%d" % [floori(at.x / NATURE_CELL) + 3, floori(at.z / NATURE_CELL) + 3]

## Спрощена геометрія поверхні меша: рівень деталізації з похибкою не
## більшою за max_error (у власних одиницях моделі), лише потрібні вершини.
func _lod_geometry(mesh: Mesh, surface: int, max_error: float) -> Dictionary:
	var key := "%d|%d|%.4f" % [mesh.get_instance_id(), surface, max_error]
	if _lod_cache.has(key):
		return _lod_cache[key]
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, _plain_arrays(mesh.surface_get_arrays(surface)))
	importer.generate_lods(60.0, 25.0, [])
	var arrays := importer.get_surface_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var source_tris := indices.size() / 3
	var best := -1.0
	for lod in importer.get_surface_lod_count(0):
		var size := importer.get_surface_lod_size(0, lod)
		if size <= max_error and size > best:
			best = size
			indices = importer.get_surface_lod_indices(0, lod)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var remap := {}
	var geo := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "idx": PackedInt32Array(),
		"source_tris": source_tris}
	for index in indices:
		if not remap.has(index):
			remap[index] = remap.size()
			geo.v.append(vertices[index])
			geo.n.append(normals[index])
			geo.uv.append(uvs[index] if uvs != null and uvs.size() > index else Vector2.ZERO)
		geo.idx.append(remap[index])
	_lod_cache[key] = geo
	return geo

## Додати геометрію в купу, перенісши у світ.
func _append(bucket: Dictionary, geo: Dictionary, xf: Transform3D) -> void:
	var base: int = (bucket.v as PackedVector3Array).size()
	bucket.v.append_array(xf * (geo.v as PackedVector3Array))
	var normal_basis := xf.basis.inverse().transposed()
	for normal: Vector3 in geo.n:
		bucket.n.append((normal_basis * normal).normalized())
	bucket.uv.append_array(geo.uv)
	var indices: PackedInt32Array = geo.idx
	# Дзеркальний масштаб вивертає грані — міняємо обхід трикутника.
	var flip := xf.basis.determinant() < 0.0
	for t in range(0, indices.size(), 3):
		bucket.idx.append(base + indices[t])
		bucket.idx.append(base + indices[t + (2 if flip else 1)])
		bucket.idx.append(base + indices[t + (1 if flip else 2)])

## Легкий матеріал: копія рідного без карт нерівностей/блиску, освітлення
## у вершинах. Однакові за виглядом матеріали різних моделей — один.
func _lite_material(source: Material) -> Material:
	var base := source as BaseMaterial3D
	if base == null:
		base = StandardMaterial3D.new()
	var texture_path := base.albedo_texture.resource_path if base.albedo_texture != null else ""
	var key := "%s|%s|%d|%d|%.2f|%s" % [texture_path, base.albedo_color.to_html(), base.transparency, base.cull_mode,
		base.alpha_scissor_threshold, base.vertex_color_use_as_albedo]
	if _lite_materials.has(key):
		return _lite_materials[key]
	var lite := StandardMaterial3D.new()
	lite.albedo_texture = base.albedo_texture
	lite.albedo_color = base.albedo_color
	lite.transparency = base.transparency
	lite.alpha_scissor_threshold = base.alpha_scissor_threshold
	lite.cull_mode = base.cull_mode
	lite.texture_filter = base.texture_filter
	lite.uv1_scale = base.uv1_scale
	lite.uv1_offset = base.uv1_offset
	lite.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	lite.roughness = 0.9
	lite.metallic = 0.0
	lite.metallic_specular = 0.3
	if base.emission_enabled:
		lite.emission_enabled = true
		lite.emission = base.emission
		lite.emission_energy_multiplier = base.emission_energy_multiplier
		lite.emission_texture = base.emission_texture
	var path := LITE_DIR + "mat_%02d.tres" % _lite_materials.size()
	lite.resource_name = base.resource_name
	ResourceSaver.save(lite, path)
	_lite_materials[key] = load(path)
	return _lite_materials[key]
