extends Node

const L := preload("res://scenes/world/haven/haven_layout.gd")
const V := "res://assets/models/haven/village/"
const N := "res://assets/models/haven/nature/"
const P := "res://assets/models/haven/props/"
const F := "res://assets/models/haven/forest/"
const K := "res://assets/models/haven/castle/"
const OUT_DIR := "res://scenes/world/haven/"
const OUT_SCENE := OUT_DIR + "haven.tscn"
const OUT_DETAIL := OUT_DIR + "haven_detail.tscn"
const OUT_LITE := OUT_DIR + "haven_lite.tscn"
const OUT_MESH := OUT_DIR + "terrain_mesh.res"
const OUT_SHAPE := OUT_DIR + "terrain_shape.res"
const MESH_DIR := OUT_DIR + "meshes/"
const LITE_DIR := OUT_DIR + "lite/"

## БУДІВНИК МІСТА ПРИХИСТОК. Запуск у test_env:
##   godot --path test_env res://dev_scripts/town/town_builder.tscn
## Складає haven.tscn (основа: земля, гравець, мітки, колізії),
## haven_detail.tscn (будинки, бруківка, пропси, природа) і
## haven_lite.tscn (те саме, спрощене й злите для слабких телефонів).
## Будинки збирає HouseKit із модулів Medieval Village MegaKit.

const HOUSE_KIT := preload("res://dev_scripts/town/house_kit.gd")

const SOLID_GROUPS := {
	"Architecture/Stalls": 0.8,
	"Architecture/Props": 0.7,
	"Architecture/Fountain": 1.0,
	"Nature/BigTrees": 0.16,
	"Nature/Forest": 0.18,
	"Nature/Rocks": 0.7,
}

const LITE_ERROR := {
	"Architecture/Houses": 0.06, "Architecture/Walls": 0.08, "Architecture/Paving": 0.05,
	"Architecture/Stalls": 0.05, "Architecture/Props": 0.04, "Architecture/Fountain": 0.03,
	"Architecture/Fences": 0.05, "Architecture/Decor": 0.04,
	"Nature/Forest": 1.5, "Nature/BigTrees": 0.35, "Nature/Bushes": 0.12, "Nature/Grass": 0.35,
	"Nature/Flowers": 0.1, "Nature/Rocks": 1.0, "Nature/Windmill": 0.2,
}
const NATURE_CELL := 32.0

var _core: Node3D
var _detail: Node3D
var _rng := RandomNumberGenerator.new()
var _shade: Array = []
var _cache := {}
## Сліди будинків (прямокутники XZ з відступом) — щоб природа туди не лізла.
var _footprints: Array = []
## Тверді коробки, задані явно: [центр, розмір].
var _boxes: Array = []

func _ready() -> void:
	_rng.seed = 20261119
	for dir in [MESH_DIR, LITE_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)
	_core = Node3D.new()
	_core.name = "Haven"
	_detail = Node3D.new()
	_detail.name = "Detail"
	_build_environment()
	_build_houses()
	_build_town_wall()
	_build_fountain()
	_build_market()
	_build_training_yard()
	_build_smithy()
	_build_tavern()
	_build_library()
	_build_townhall_square()
	_build_portal_area()
	_build_gate_road()
	_build_nature()
	_build_terrain()
	_build_markers()
	_build_colliders()
	_take_player_and_hud()
	_core.set_script(load("res://scenes/world/haven/haven.gd"))
	print("HAVEN core err=", _save_scene(_core, OUT_SCENE))
	print("HAVEN detail err=", _save_scene(_detail, OUT_DETAIL))
	var lite := _bake_lite()
	print("HAVEN lite err=", _save_scene(lite, OUT_LITE))
	get_tree().quit(0)

# --- середовище: тепле сонце, ясне небо, без туману ---

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.55, 0.9)
	sky_mat.sky_horizon_color = Color(0.78, 0.86, 0.95)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.72, 0.78, 0.6)
	sky_mat.ground_bottom_color = Color(0.36, 0.44, 0.28)
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.68, 0.62)
	e.ambient_light_energy = 0.85
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 5.5
	e.fog_enabled = false
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.06
	e.adjustment_contrast = 1.06
	e.adjustment_brightness = 1.03
	env.environment = e
	_core.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# Тепле пообіднє сонце з південного заходу: фасади, що дивляться на
	# камеру, освітлені, тіні лягають назад і вбік.
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.8
	sun.directional_shadow_max_distance = 48.0
	_core.add_child(sun)

# --- будинки ---

func _house_xf(center: Vector2, yaw_deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), Vector3(center.x, 0.0, center.y))

func _build_houses() -> void:
	for entry: Array in L.HOUSES:
		var spec: Dictionary = entry[3].duplicate()
		spec["name"] = entry[0]
		var house: Node3D = HOUSE_KIT.build(spec)
		_group("Architecture/Houses").add_child(house)
		house.transform = _house_xf(entry[1], entry[2])
		var w: float = float(spec.get("w", 2)) * 2.0
		var d: float = float(spec.get("d", 2)) * 2.0
		# Колізія — точно по стінах (дах і ґанок над головою не заважають).
		var rotated := absf(sin(deg_to_rad(float(entry[2])))) > 0.7
		var size := Vector3(d if rotated else w, 6.0, w if rotated else d)
		if absf(float(entry[2])) > 1.0 and absf(float(entry[2])) < 89.0:
			size = Vector3(maxf(w, d) * 1.15, 6.0, maxf(w, d) * 1.15)
		_boxes.append([Vector3(entry[1].x, 3.0, entry[1].y), size + Vector3(0.3, 0, 0.3)])
		_footprints.append(Rect2(entry[1].x - size.x * 0.5 - 1.5, entry[1].y - size.z * 0.5 - 1.5, size.x + 3.0, size.z + 3.0))
		_shade.append([entry[1], maxf(w, d) * 0.9])
		_decorate_house(house, spec)

## Ліхтар біля дверей, квіти під вікнами, плющ на кутах.
func _decorate_house(house: Node3D, spec: Dictionary) -> void:
	var w: float = float(spec.get("w", 2))
	var d: float = float(spec.get("d", 2))
	var door: int = spec.get("door", 0)
	var front := d + 0.35
	var xf := house.transform
	if door >= 0:
		var door_x := -w + 1.0 + door * 2.0
		_place(P + "Lantern_Wall.gltf", "Architecture/Decor", xf * Vector3(door_x + 1.25, 2.3, front - 0.25), house.rotation.y)
	for i in int(w):
		if i == door:
			continue
		var x := -w + 1.0 + i * 2.0
		if _rng.randf() < 0.75:
			_place(N + ["Bush_Common_Flowers.gltf", "Flower_3_Group.gltf", "Flower_4_Group.gltf"][_rng.randi() % 3], "Nature/Flowers",
				xf * Vector3(x, 0.0, front + 0.3), _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.7, 1.0))
	if _rng.randf() < 0.6:
		_place(V + "Prop_Vine%d.gltf" % [1, 2, 4, 5, 6, 9][_rng.randi() % 6], "Architecture/Decor",
			xf * Vector3(w + 0.1, 0.0, front - 0.4), house.rotation.y)

## Міська стіна з брамою на півдні: дві вежі брами (у HOUSES), над
## проїздом — перекриття, від веж — мури на захід і схід до кутових веж.
func _build_town_wall() -> void:
	var z := L.GATE.z
	# Перекриття над брамою: стіни на висоті поверху + дах-місток.
	for x: float in [-2.0, 0.0, 2.0]:
		_place(V + "Wall_UnevenBrick_Straight.gltf", "Architecture/Walls", Vector3(x, 3.0, z + 1.0), 0.0)
		_place(V + "Wall_UnevenBrick_Straight.gltf", "Architecture/Walls", Vector3(x, 3.0, z - 1.0), PI)
		_place(V + "Floor_Brick.gltf", "Architecture/Walls", Vector3(x, 3.0, z), 0.0)
		_place(V + "Floor_Brick.gltf", "Architecture/Walls", Vector3(x, 6.0, z), 0.0)
	_place(K + "flag-banner-long.glb", "Architecture/Decor", Vector3(-1.2, 3.4, z + 1.35), 0.0, Vector3.ONE * 1.6)
	_place(K + "flag-banner-long.glb", "Architecture/Decor", Vector3(1.2, 3.4, z + 1.35), 0.0, Vector3.ONE * 1.6)
	# Мури: подвійна цегляна стіна (лицем назовні й усередину), 2 м заввишки.
	for side: int in [-1, 1]:
		var x := 7.0 * side
		while absf(x) < 34.0:
			_place(V + "Wall_UnevenBrick_Straight.gltf", "Architecture/Walls", Vector3(x + side, 0.0, z + 0.3), 0.0)
			_place(V + "Wall_UnevenBrick_Straight.gltf", "Architecture/Walls", Vector3(x + side, 0.0, z - 0.3), PI)
			x += 2.0 * side
		_boxes.append([Vector3(20.5 * side, 1.5, z), Vector3(27.0, 3.0, 1.2)])
		# Кутова вежа.
		var tower: Node3D = HOUSE_KIT.build({"w": 2, "d": 2, "floors": 2, "base": "brick", "upper": "brick", "door": -1,
			"windows": "few", "tower": true, "seed": 30 + side, "name": "corner_%d" % side})
		_group("Architecture/Houses").add_child(tower)
		tower.position = Vector3(36.0 * side, 0.0, z)
		_boxes.append([Vector3(36.0 * side, 3.0, z), Vector3(4.4, 6.0, 4.4)])
		_footprints.append(Rect2(36.0 * side - 4.0, z - 4.0, 8.0, 8.0))
	_fire_marker(Vector3(-3.4, 2.5, z + 2.4))
	_fire_marker(Vector3(3.4, 2.5, z + 2.4))
	_place(P + "Torch_Metal.gltf", "Architecture/Props", Vector3(-3.4, 0.0, z + 2.4), 0.0, Vector3.ONE * 1.4)
	_place(P + "Torch_Metal.gltf", "Architecture/Props", Vector3(3.4, 0.0, z + 2.4), 0.0, Vector3.ONE * 1.4)

# --- бруківка: плитки 2×2 м ---

# --- фонтан посеред площі ---


# --- ринок (Торговка Олеся) ---

# --- тренувальний двір (Наставниця Дарина) ---

# --- кузня (Коваль Богдан) ---

# --- таверна «Золотий Кабан» ---

# --- бібліотека-вежа (Мудрець Велимир) ---

# --- ратуша й площа (Старійшина Остап) ---

# --- північ: стара каплиця й вхід до склепів ---

func _build_portal_area() -> void:
	var chapel: Node3D = HOUSE_KIT.build({"w": 3, "d": 2, "floors": 2, "base": "brick", "upper": "brick", "door": 1,
		"windows": "few", "seed": 40, "name": "chapel"})
	_group("Architecture/Houses").add_child(chapel)
	chapel.position = Vector3(0, 0, L.PORTAL.z - 6.0)
	_boxes.append([Vector3(0, 3.0, L.PORTAL.z - 6.0), Vector3(6.4, 6.0, 4.4)])
	_footprints.append(Rect2(-5.0, L.PORTAL.z - 10.0, 10.0, 8.0))
	for x: float in [-L.PORTAL_FIRE_X, L.PORTAL_FIRE_X]:
		_place(P + "Torch_Metal.gltf", "Architecture/Props", L.PORTAL + Vector3(x, 0, 1.2), 0.0, Vector3.ONE * 1.5)
	for i in 6:
		var a := -1.2 + i * 0.48
		var p := L.PORTAL + Vector3(sin(a) * 7.5, 0, 2.0 + cos(a) * 2.5)
		_place(N + "Rock_Medium_%d.gltf" % (1 + i % 3), "Nature/Rocks", p, _rng.randf() * TAU, Vector3(0.45, 1.1 + 0.2 * (i % 2), 0.45))

# --- дорога до брами ---

func _build_gate_road() -> void:
	var fence := V + "Prop_WoodenFence_Single.gltf"
	for side: int in [-1, 1]:
		for i in 6:
			_place(fence, "Architecture/Fences", Vector3(4.5 * side, L.ground(4.5 * side, 46.0 + i * 2.0), 46.0 + i * 2.0), PI * 0.5)
	_place(P + "Crate_Wooden.gltf", "Architecture/Props", Vector3(-5.0, 0, 44.0), 0.3)
	_place(P + "Barrel.gltf", "Architecture/Props", Vector3(-5.8, 0, 44.6), 0.0)

# --- природа: ліс по краю, поля, вітряк, квіти ---

func _busy(p: Vector2, margin: float = 1.0) -> bool:
	for rect: Rect2 in _footprints:
		if rect.grow(margin).has_point(p):
			return true
	for rect: Rect2 in [L.SQUARE, L.MAIN_STREET, L.SMITH_STREET, L.NORTH_LANE, Rect2(-6.0, 34.0, 12.0, 60.0)]:
		if rect.grow(margin + 1.0).has_point(p):
			return true
	if Vector2(p.x - L.FOUNTAIN.x, p.y - L.FOUNTAIN.z).length() < L.FOUNTAIN_RADIUS + 4.0:
		return true
	return false

func _inside_town(p: Vector2) -> bool:
	return p.x > -34.0 and p.x < 34.0 and p.y > -50.0 and p.y < 40.0

func _build_nature() -> void:
	# Ліс: кільце дерев за містом і на пагорбах.
	var trees := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5", "Pine_1", "Pine_2", "Pine_3"]
	var placed := 0
	var tries := 0
	while placed < 230 and tries < 6000:
		tries += 1
		var p := Vector2(_rng.randf_range(-95, 95), _rng.randf_range(-95, 95))
		var e := Vector2((p.x - L.BOWL_CENTER.x) / L.BOWL_RADIUS.x, (p.y - L.BOWL_CENTER.y) / L.BOWL_RADIUS.y).length()
		if e < 0.78 or _busy(p, 2.0) or _inside_town(p):
			continue
		# Дорога на південь і стежка до вітряка — вільні.
		if absf(p.x) < 7.0 and p.y > 30.0:
			continue
		if Vector2(p.x - 50.0, p.y - 14.0).length() < 9.0:
			continue
		var name: String = trees[_rng.randi() % trees.size()]
		var scale := _rng.randf_range(0.9, 1.45) * (1.0 + clampf(e - 1.0, 0.0, 0.5))
		_place(N + name + ".gltf", "Nature/Forest", Vector3(p.x, L.ground(p.x, p.y) - 0.1, p.y), _rng.randf() * TAU, Vector3.ONE * scale)
		placed += 1
	# Дерева й кущі в місті (між будинками, біля мурів).
	for p: Vector2 in [Vector2(-28, 20), Vector2(-27, -2), Vector2(28, 18), Vector2(26, -24), Vector2(-28, -32), Vector2(16, -34),
			Vector2(-16, 30), Vector2(18, 34), Vector2(-17, 16), Vector2(17, 21)]:
		if _busy(p, 0.5):
			continue
		_place(N + "CommonTree_%d.gltf" % (1 + _rng.randi() % 5), "Nature/BigTrees", Vector3(p.x, 0, p.y), _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.8, 1.1))
		_shade.append([p, 2.8])
	var bushes := ["Bush_Common", "Bush_Common_Flowers", "Plant_1_Big", "Fern_1", "Plant_7_Big"]
	for i in 70:
		var p := Vector2(_rng.randf_range(-33, 33), _rng.randf_range(-48, 38))
		if _busy(p, 0.6):
			continue
		_place(N + bushes[_rng.randi() % bushes.size()] + ".gltf", "Nature/Bushes", Vector3(p.x, 0, p.y), _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.8, 1.3))
	var flowers := ["Flower_3_Group", "Flower_4_Group", "Flower_3_Single", "Flower_4_Single", "Clover_1", "Clover_2"]
	for i in 160:
		var p := Vector2(_rng.randf_range(-70, 70), _rng.randf_range(-70, 75))
		if _busy(p, 0.3):
			continue
		var e := Vector2((p.x - L.BOWL_CENTER.x) / L.BOWL_RADIUS.x, (p.y - L.BOWL_CENTER.y) / L.BOWL_RADIUS.y).length()
		if e > 1.0:
			continue
		_place(N + flowers[_rng.randi() % flowers.size()] + ".gltf", "Nature/Flowers", Vector3(p.x, L.ground(p.x, p.y), p.y), _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.8, 1.2))
	var grass := ["Grass_Common_Short", "Grass_Wispy_Short", "Grass_Common_Tall"]
	for i in 140:
		var p := Vector2(_rng.randf_range(-70, 70), _rng.randf_range(-70, 75))
		if _busy(p, 0.3) or (_inside_town(p) and _rng.randf() < 0.6):
			continue
		_place(N + grass[_rng.randi() % grass.size()] + ".gltf", "Nature/Grass", Vector3(p.x, L.ground(p.x, p.y), p.y), _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.9, 1.4))
	for i in 24:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(1.05, 1.35)
		var p := Vector2(L.BOWL_CENTER.x + cos(a) * L.BOWL_RADIUS.x * r, L.BOWL_CENTER.y + sin(a) * L.BOWL_RADIUS.y * r)
		_place(N + "Rock_Medium_%d.gltf" % (1 + i % 3), "Nature/Rocks", Vector3(p.x, L.ground(p.x, p.y) - 0.3, p.y), _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(1.2, 2.6))
	# Кам'яний вітряк на горбі на схід від міста.
	var mill := Vector3(50.0, 0, 14.0)
	mill.y = L.ground(mill.x, mill.z) - 0.2
	_place("res://assets/models/haven/farm/TowerWindmill.fbx", "Nature/Windmill", mill, -0.9, Vector3.ONE * 1.1)
	# Поле на захід: грядки з рослин і огорожа.
	for row in 5:
		for col in 7:
			var p := Vector2(-52.0 + col * 1.6, 8.0 + row * 2.2)
			_place(N + ["Plant_7", "Plant_1", "Fern_1"][row % 3] + ".gltf", "Nature/Bushes", Vector3(p.x, L.ground(p.x, p.y), p.y), _rng.randf() * TAU, Vector3.ONE * 0.8)

# --- мітки, колізії ---

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

func _build_colliders() -> void:
	var body := StaticBody3D.new()
	body.name = "Colliders"
	_core.add_child(body)
	var count := 0
	for box: Array in _boxes:
		_add_box(body, box[0], box[1])
		count += 1
	for group: String in SOLID_GROUPS:
		var holder := _detail.get_node_or_null(group)
		if holder == null:
			continue
		var shrink: float = SOLID_GROUPS[group]
		for child in holder.get_children():
			var bounds := _bounds(child as Node3D)
			if bounds.size.length() < 0.4:
				continue
			_add_box(body, bounds.get_center(), Vector3(bounds.size.x * shrink, maxf(bounds.size.y, 2.0), bounds.size.z * shrink))
			count += 1
	# Межа світу: далі пагорби й ліс.
	for p: Array in [[Vector3(0, 2, 96), Vector3(200, 6, 2)], [Vector3(0, 2, -96), Vector3(200, 6, 2)],
			[Vector3(96, 2, 0), Vector3(2, 6, 200)], [Vector3(-96, 2, 0), Vector3(2, 6, 200)]]:
		_add_box(body, p[0], p[1])
	print("TOWN colliders: ", count)

func _zone_of(group: String, at: Vector3) -> String:
	if group.begins_with("Architecture"):
		if at.z > 14.0:
			return "arch_gate"
		if at.z < -16.0:
			return "arch_north"
		return "arch_square_%d" % (0 if at.x < 0.0 else 1)
	return "nature_%d_%d" % [floori(at.x / NATURE_CELL) + 4, floori(at.z / NATURE_CELL) + 4]

# --- спільне з давнім будівником ---

var _lite_materials := {}
var _lod_cache := {}

func _save_scene(root: Node, path: String) -> int:
	_set_owner(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	return err

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
	material.shader = load(OUT_DIR + "town_ground.gdshader")
	for key: String in ["grass", "dirt", "cobble"]:
		material.set_shader_parameter(key + "_tex", load("res://assets/textures/town/%s.png" % key))
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

func _plain_arrays(arrays: Array) -> Array:
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	for channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
		result[channel] = arrays[channel]
	return result

func _fire_marker(pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = "Fire%d" % _group("Effects").get_child_count()
	_group("Effects").add_child(marker)
	marker.position = pos

func _add_box(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	shape.position = center

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


## Куток жителя: предмети в локальних координатах відносно точки й кута
## (локальне +Z — куди дивиться житель, -Z — за ним).
func _cluster(origin: Vector3, yaw: float, items: Array, group: String = "Architecture/Props") -> void:
	var basis := Basis(Vector3.UP, yaw)
	for item: Array in items:
		var path: String = item[0] if String(item[0]).begins_with("res://") else P + String(item[0]) + ".gltf"
		var scale: float = item[3] if item.size() > 3 else 1.0
		_place(path, group, origin + basis * (item[1] as Vector3), yaw + float(item[2]), Vector3.ONE * scale)

# --- ринок (Торговка Олеся) ---

func _build_market() -> void:
	var m: Vector3 = L.NPCS[&"merchant"][0]
	_cluster(m, -PI * 0.5, [
		["Stall_Empty", Vector3(-3.0, 0, -1.6), 0.0], ["Stall_Empty", Vector3(3.0, 0, -1.6), 0.0],
		["Stall_Cart_Empty", Vector3(0.0, 0, -2.2), 0.0],
		["FarmCrate_Apple", Vector3(-3.6, 0, -0.4), 0.2], ["FarmCrate_Carrot", Vector3(-2.4, 0, -0.4), -0.2],
		["Barrel_Apples", Vector3(2.2, 0, -0.3), 0.0], ["Bag", Vector3(3.6, 0, -0.2), 0.6], ["Bag", Vector3(4.2, 0, -0.9), 1.2],
		["Table_Large", Vector3(0.0, 0, 1.4), PI * 0.5],
		["Coin_Pile", Vector3(-0.2, 0.92, 1.2), 0.0], ["Pouch_Large", Vector3(0.3, 0.92, 1.7), 0.4],
		["Vase_2", Vector3(-0.1, 0.92, 2.1), 0.0], ["Chalice", Vector3(0.25, 0.92, 0.8), 0.0],
		["Potion_2", Vector3(-0.3, 0.92, 0.7), 0.0],
		["Crate_Wooden", Vector3(-4.8, 0, -1.8), 0.3], ["Crate_Wooden", Vector3(-4.7, 0.75, -1.7), 0.9, 0.8],
		["Barrel", Vector3(4.9, 0, -2.0), 0.0], ["Pot_1", Vector3(1.4, 0, 1.0), 0.0], ["Vase_4", Vector3(-1.4, 0, 1.1), 0.0],
		["Banner_2_Cloth", Vector3(-5.6, 0, -0.5), 0.0, 1.2],
	])
	_place(V + "Prop_Wagon.gltf", "Architecture/Props", Vector3(6.5, 0, 34.5), 0.3)
	_place("res://assets/models/haven/farm/Well.fbx", "Architecture/Props", L.WELL, 0.4, Vector3.ONE * 1.5)
	for lamp: Vector3 in L.LAMPS:
		_place(P + "Torch_Metal.gltf", "Architecture/Props", lamp, 0.0, Vector3.ONE * 1.4)
		_fire_marker(lamp + Vector3(0, 2.1, 0))
	for spot: Vector3 in [Vector3(-6.0, 0, 15.5), Vector3(7.2, 0, 21.0), Vector3(17.5, 0, -20.0),
			Vector3(-20.0, 0, 13.0), Vector3(24.0, 0, -8.0)]:
		_place(P + "Crate_Wooden.gltf", "Architecture/Props", spot, _rng.randf() * TAU)
		_place(P + "Barrel.gltf", "Architecture/Props", spot + Vector3(0.9, 0, 0.5), 0.0)

# --- тренувальний двір (Наставниця Дарина) ---

func _build_training_yard() -> void:
	for p: Vector3 in [Vector3(-19.5, 0, -2.5), Vector3(-19.5, 0, 0.5), Vector3(-19.5, 0, 3.5)]:
		_place(P + "Dummy.gltf", "Architecture/Props", p, PI * 0.5, Vector3.ONE * 1.25)
	var fence := V + "Prop_WoodenFence_Single.gltf"
	for i in 4:
		_place(fence, "Architecture/Fences", Vector3(-22.0 + i * 2.0, 0, -5.0), 0.0)
		_place(fence, "Architecture/Fences", Vector3(-22.0 + i * 2.0, 0, 5.0), 0.0)
	var d: Vector3 = L.NPCS[&"mentor"][0]
	_cluster(d, PI * 0.5, [
		["WeaponStand", Vector3(-2.4, 0, -2.2), 0.0], ["WeaponStand", Vector3(2.4, 0, -2.2), 0.0],
		["Table_Large", Vector3(0.0, 0, -2.4), 0.0],
		["Sword_Bronze", Vector3(-0.4, 0.95, -2.4), 0.3], ["Axe_Bronze", Vector3(0.5, 0.95, -2.3), -0.4],
		["Shield_Wooden", Vector3(0.0, 0.95, -2.7), 0.0],
		["Peg_Rack", Vector3(-3.6, 0, -0.6), PI * 0.5], ["Shield_Wooden", Vector3(-3.7, 1.2, -0.6), PI * 0.5],
		["Chest_Wood", Vector3(3.4, 0, -0.6), -PI * 0.5], ["Barrel_Holder", Vector3(3.6, 0, 1.2), 0.0],
		["Bench", Vector3(-3.4, 0, 2.0), PI * 0.5], ["Bucket_Wooden_1", Vector3(2.8, 0, 2.4), 0.0],
		["Banner_2_Cloth", Vector3(0.0, 0, -3.6), 0.0, 1.3],
	])

# --- кузня (Коваль Богдан) ---

func _build_smithy() -> void:
	var a := L.ANVIL
	_place(P + "Anvil_Log.gltf", "Architecture/Props", a, 0.2, Vector3.ONE * 1.3)
	_place(V + "Prop_Chimney.gltf", "Architecture/Props", a + Vector3(2.2, 0, -0.6), 0.0, Vector3(1.1, 0.7, 1.1))
	_fire_marker(a + Vector3(2.2, 2.3, -0.6))
	var s: Vector3 = L.NPCS[&"smith"][0]
	_cluster(s, -PI * 0.5, [
		["Workbench", Vector3(-2.6, 0, -2.4), 0.0], ["Workbench_Drawers", Vector3(2.8, 0, -2.6), 0.0],
		["Sword_Bronze", Vector3(-2.8, 0.95, -2.4), 0.5], ["Pickaxe_Bronze", Vector3(-2.2, 0.95, -2.5), -0.3],
		["WeaponStand", Vector3(-4.2, 0, -0.6), PI * 0.5], ["Peg_Rack", Vector3(4.4, 0, -0.8), -PI * 0.5],
		["Shield_Wooden", Vector3(4.5, 1.2, -0.8), -PI * 0.5],
		["Whetstone", Vector3(-3.4, 0, 1.6), 0.4], ["Chain_Coil", Vector3(1.0, 0, -3.0), 0.0],
		["Crate_Metal", Vector3(3.6, 0, 1.6), 0.2], ["Crate_Metal", Vector3(3.5, 0.7, 1.5), 0.9, 0.8],
		["Bucket_Metal", Vector3(-1.2, 0, 1.4), 0.0], ["Barrel", Vector3(4.6, 0, 2.6), 0.0], ["Rope_2", Vector3(-4.0, 0, 2.6), 0.0],
	])

# --- таверна «Золотий Кабан» ---

func _build_tavern() -> void:
	var t := L.TAVERN_TABLE
	for p: Vector3 in [t, t + Vector3(0, 0, -4.0)]:
		_cluster(p, PI * 0.5, [
			["Table_Large", Vector3.ZERO, 0.0], ["Bench", Vector3(0, 0, 1.0), 0.0], ["Bench", Vector3(0, 0, -1.0), PI],
			["Mug", Vector3(0.3, 0.9, 0.1), 0.0], ["Mug", Vector3(-0.4, 0.9, -0.2), 0.0], ["Table_Plate", Vector3(0.0, 0.9, 0.25), 0.0],
		])
	_cluster(t, 0.0, [
		["Barrel", Vector3(1.6, 0, 3.0), 0.0], ["Barrel", Vector3(1.4, 0, 4.0), 0.7], ["Barrel", Vector3(1.5, 0.95, 3.5), PI * 0.5, 0.9],
		["Torch_Metal", Vector3(-1.4, 0, 2.2), 0.0, 1.3], ["Chair_1", Vector3(-1.6, 0, -6.0), 0.5], ["Crate_Wooden", Vector3(1.7, 0, -6.4), 0.2],
	])
	_fire_marker(t + Vector3(-1.4, 1.95, 2.2))
	_place(K + "flag-banner-short.glb", "Architecture/Decor", Vector3(7.6, 2.6, 28.5), -PI * 0.5, Vector3.ONE * 1.5)

# --- бібліотека-вежа (Мудрець Велимир) ---

func _build_library() -> void:
	var c := L.CAULDRON
	_place(P + "Cauldron.gltf", "Architecture/Props", c, 0.0, Vector3.ONE * 1.3)
	_fire_marker(c + Vector3(0, 0.25, 0))
	var v: Vector3 = L.NPCS[&"sage"][0]
	_cluster(v, float(L.NPCS[&"sage"][1]), [
		["Bookcase_2", Vector3(-2.2, 0, -2.4), 0.0], ["Bookcase_2", Vector3(-0.6, 0, -2.6), 0.0],
		["Table_Large", Vector3(2.0, 0, -1.6), 0.0],
		["Potion_1", Vector3(1.6, 0.95, -1.5), 0.0], ["Potion_2", Vector3(1.9, 0.95, -1.8), 0.0], ["Potion_4", Vector3(2.3, 0.95, -1.4), 0.0],
		["SmallBottles_1", Vector3(2.6, 0.95, -1.8), 0.0], ["Scroll_2", Vector3(1.6, 0.95, -1.9), 0.4],
		["CandleStick_Triple", Vector3(2.5, 0.95, -1.3), 0.0], ["Book_Stack_2", Vector3(1.4, 0.95, -1.4), 0.2],
		["BookStand", Vector3(-2.6, 0, 0.4), 0.6], ["CandleStick_Stand", Vector3(-3.0, 0, -1.0), 0.0],
		["Chest_Wood", Vector3(3.4, 0, 0.2), -0.6], ["Shelf_Small_Bottles", Vector3(0.9, 0, -3.0), 0.0],
		["Cage_Small", Vector3(3.6, 0, -2.6), 0.3], ["Book_Stack_1", Vector3(-1.6, 0, 0.6), 0.0],
	])

# --- ратуша й площа (Старійшина Остап) ---

func _build_townhall_square() -> void:
	for x: float in [-3.0, 3.0]:
		_place(P + "Banner_1_Cloth.gltf", "Architecture/Decor", Vector3(x, 3.2, -18.6), 0.0, Vector3.ONE * 1.3)
	for x: float in [-5.0, 5.0]:
		_place(P + "Torch_Metal.gltf", "Architecture/Props", Vector3(x, 0, -14.6), 0.0, Vector3.ONE * 1.4)
		_fire_marker(Vector3(x, 2.1, -14.6))
	var e: Vector3 = L.NPCS[&"elder"][0]
	_cluster(e, 0.0, [
		["Table_Large", Vector3(-2.6, 0, -1.4), PI * 0.5], ["Chair_1", Vector3(-2.6, 0, -2.6), 0.0],
		["Scroll_1", Vector3(-2.8, 0.95, -1.2), 0.3], ["Scroll_2", Vector3(-2.3, 0.95, -1.6), -0.5],
		["Book_Stack_1", Vector3(-2.5, 0.95, -0.8), 0.0], ["CandleStick_Triple", Vector3(-2.9, 0.95, -1.8), 0.0],
		["Key_Gold", Vector3(-2.2, 0.95, -1.1), 0.7],
		["Chest_Wood", Vector3(2.6, 0, -1.8), 0.0], ["Coin_Pile_2", Vector3(2.6, 0.62, -1.8), 0.0],
		["Vase_2", Vector3(-4.2, 0, -2.4), 0.0], ["Vase_2", Vector3(4.2, 0, -2.4), 0.0],
		["Bench", Vector3(-5.6, 0, 0.6), PI * 0.5], ["Bench", Vector3(5.6, 0, 0.6), -PI * 0.5],
		["Banner_2_Cloth", Vector3(3.8, 0, -0.8), 0.0, 1.2],
	])
	for p: Vector3 in [e + Vector3(-4.2, 0, -2.4), e + Vector3(4.2, 0, -2.4)]:
		_place(N + "Flower_4_Group.gltf", "Nature/Flowers", p + Vector3(0, 0.55, 0), 0.0, Vector3.ONE * 0.55)

## ФОНТАН: восьмикутний, дворівневий, світлий мармур із темною облямівкою
## (контраст із темно-синьою бруківкою), жива вода й бризки, довкола —
## квіткові вазони й лавки.
func _stone(color: Color, texture: String = "T_RockTrim_BaseColor.png", scale: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(V + texture):
		m.albedo_texture = load(V + texture)
	m.albedo_color = color
	m.uv1_scale = Vector3(scale, 1.0, 1.0)
	m.roughness = 0.75
	return m

func _cyl(top: float, bottom: float, height: float, sides: int, material: Material, at: Vector3, group: String) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mesh.material = material
	_place_mesh(mesh, group, at + Vector3(0, height * 0.5, 0), PI / sides, Vector3.ONE)

func _water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode specular_schlick_ggx, cull_back;
uniform vec3 deep : source_color = vec3(0.05, 0.32, 0.42);
uniform vec3 shallow : source_color = vec3(0.32, 0.72, 0.78);
void fragment() {
	vec2 p = UV * 7.0;
	float w = sin(p.x * 2.3 + TIME * 1.6) * sin(p.y * 2.1 - TIME * 1.3) + 0.5 * sin((p.x + p.y) * 3.7 + TIME * 2.2);
	ALBEDO = mix(deep, shallow, 0.45 + 0.25 * w);
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	EMISSION = ALBEDO * 0.18;
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _build_fountain() -> void:
	var at := L.FOUNTAIN
	var marble := _stone(Color(0.97, 0.94, 0.88))
	var slate := _stone(Color(0.42, 0.47, 0.58), "T_Brick_BaseColor.png", 3.0)
	var trim := _stone(Color(0.95, 0.82, 0.55))
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.32)
	gold.metallic = 0.8
	gold.roughness = 0.3
	var g := "Architecture/Fountain"
	# Сходинка-основа й чаша.
	_cyl(4.5, 4.7, 0.22, 8, slate, at, g)
	_cyl(3.6, 3.75, 0.85, 8, marble, at + Vector3(0, 0.22, 0), g)
	_cyl(3.82, 3.82, 0.14, 8, trim, at + Vector3(0, 1.0, 0), g)
	# Центральна колона, середня чаша, верхня колонка, мала чаша, золота маківка.
	_cyl(0.55, 0.75, 1.9, 8, marble, at + Vector3(0, 0.22, 0), g)
	_cyl(1.7, 0.6, 0.5, 8, marble, at + Vector3(0, 2.0, 0), g)
	_cyl(1.78, 1.78, 0.1, 8, trim, at + Vector3(0, 2.48, 0), g)
	_cyl(0.28, 0.36, 1.0, 8, marble, at + Vector3(0, 2.5, 0), g)
	_cyl(0.75, 0.3, 0.32, 8, marble, at + Vector3(0, 3.45, 0), g)
	var finial := SphereMesh.new()
	finial.radius = 0.24
	finial.height = 0.48
	finial.material = gold
	_place_mesh(finial, g, at + Vector3(0, 3.98, 0), 0.0, Vector3.ONE)
	# Вода — в основі сцени (жива, не запікається в легку версію).
	var water := _water_material()
	for w: Array in [[3.45, 0.98], [1.58, 2.46], [0.66, 3.74]]:
		var disk := CylinderMesh.new()
		disk.top_radius = w[0]
		disk.bottom_radius = w[0]
		disk.height = 0.03
		disk.radial_segments = 24
		disk.material = water
		var node := MeshInstance3D.new()
		node.mesh = disk
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_group("Water").add_child(node)
		node.position = at + Vector3(0, float(w[1]), 0)
	# Мітка для бризок (їх оживляє haven.gd, як і вогонь).
	var spray := Marker3D.new()
	spray.name = "Spray"
	_group("Water").add_child(spray)
	spray.position = at + Vector3(0, 3.9, 0)
	_boxes.append([at + Vector3(0, 1.0, 0), Vector3(7.4, 2.0, 7.4)])
	# Вазони з квітами по діагоналях і лавки на чотири боки.
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var p := at + Vector3(sin(a), 0, cos(a)) * 5.6
		_place(P + "Pot_1.gltf", "Architecture/Props", p, 0.0, Vector3.ONE * 2.2)
		_place(N + ["Flower_4_Group", "Flower_3_Group", "Bush_Common_Flowers"][i % 3] + ".gltf", "Nature/Flowers", p + Vector3(0, 0.7, 0), a, Vector3.ONE * 0.7)
	for i in 4:
		var a := i * PI * 0.5
		var p := at + Vector3(sin(a), 0, cos(a)) * 6.2
		_place(P + "Bench.gltf", "Architecture/Props", p, a + PI)
	for corner: Vector2 in [Vector2(-13.5, 9.0), Vector2(13.5, 9.0)]:
		_place(N + "CommonTree_%d.gltf" % (1 + _rng.randi() % 3), "Nature/BigTrees", Vector3(corner.x, 0, corner.y), _rng.randf() * TAU, Vector3.ONE * 0.9)
		_shade.append([corner, 3.0])
