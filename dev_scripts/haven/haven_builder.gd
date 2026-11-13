extends Node
## БУДІВНИК ПРИХИСТКУ: складає сцену res://scenes/world/haven/haven.tscn за
## планом HavenLayout — рельєф (меш + фізика), тераси з підпірними стінами,
## сходи, площа з бруківкою, будиночки, природа, ресурси для квестів, місця
## NPC і портал. Запуск (test_env або редактор, зупинивши гру):
##   godot --path <проєкт> res://dev_scripts/haven/haven_builder.tscn
## Готова сцена — звичайні вузли: правиться в редакторі як завгодно.
## Перезапуск будівника перезапише сцену (ручні правки — у плані чи тут).

const L := preload("res://dev_scripts/haven/haven_layout.gd")
const V := "res://assets/models/haven/village/"
const N := "res://assets/models/haven/nature/"
const P := "res://assets/models/haven/props/"
const F := "res://assets/models/haven/forest/"
const OUT_SCENE := "res://scenes/world/haven/haven.tscn"
const OUT_MESH := "res://scenes/world/haven/terrain_mesh.res"
const OUT_SHAPE := "res://scenes/world/haven/terrain_shape.res"

var _root: Node3D
var _rng := RandomNumberGenerator.new()
## Де запекти тінь у землю (без справжніх тіней на телефоні): [точка XZ, радіус].
var _shade: Array = []
var _cache := {}

func _ready() -> void:
	_rng.seed = 20261113
	_root = Node3D.new()
	_root.name = "Haven"
	_root.set_script(load("res://scenes/world/haven/haven.gd"))
	_build_environment()
	_build_terraces()
	_build_stairs()
	_build_plaza()
	_build_houses()
	_build_nature()
	_build_resources()
	_build_terrain()
	_build_spawn_camp()
	_build_stair_fires()
	_build_markers()
	_take_player_and_hud()
	_set_owner(_root, _root)
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_SCENE)
	print("HAVEN saved err=", err)
	get_tree().quit(0)

# --- допоміжне ---

func _group(path: String) -> Node3D:
	var node := _root.get_node_or_null(path) as Node3D
	if node != null:
		return node
	var parts := path.split("/")
	var parent: Node = _root
	for part in parts:
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

## Висота землі в точці (за планом — те саме, що в меші й фізиці).
func _ground(x: float, z: float) -> float:
	return L.height(x, z)

func _set_owner(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		# Усередину вставлених сцен не лізем — їхні вузли належать їм.
		if child.scene_file_path == "":
			_set_owner(child, owner)

# --- середовище ---

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
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
	_root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# Тепле низьке сонце збоку-ззаду: схили й стіни мають світлий і тіньовий бік.
	sun.rotation_degrees = Vector3(-48.0, 38.0, 0.0)
	sun.light_color = Color(1.0, 0.9, 0.74)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	_root.add_child(sun)

# --- рельєф ---

func _build_terrain() -> void:
	var count := int(L.SIZE / L.STEP) + 1
	var half := L.SIZE * 0.5
	var heights := PackedFloat32Array()
	heights.resize(count * count)
	for j in count:
		for i in count:
			heights[j * count + i] = _ground(-half + i * L.STEP, -half + j * L.STEP)
	var material := ShaderMaterial.new()
	material.shader = load("res://scenes/world/haven/haven_terrain.gdshader")
	material.set_shader_parameter(&"detail", load("res://assets/textures/town/town_noise.png"))
	var body := StaticBody3D.new()
	body.name = "Terrain"
	_root.add_child(body)
	# Шматки: 4×4 — те, що поза кадром, відеокарта не малює.
	var pieces := 4
	var cells := (count - 1) / pieces
	for pj in pieces:
		for pi in pieces:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in cells + 1:
				for i in cells + 1:
					var gi := pi * cells + i
					var gj := pj * cells + j
					var x := -half + gi * L.STEP
					var z := -half + gj * L.STEP
					var h := heights[gj * count + gi]
					st.set_color(_terrain_mask(x, z, h))
					st.add_vertex(Vector3(x, h, z))
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
			visual.set_meta(&"no_batch", true)
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
	_terrace_walls(L.LOW_TERRACE, L.LOW_HEIGHT, 0.0)
	_terrace_walls(L.HIGH_TERRACE, L.HIGH_HEIGHT, L.LOW_HEIGHT)

func _terrace_walls(rect: Rect2, top: float, below: float) -> void:
	var group := "Architecture/Walls"
	# Стіна виходить на 0.1 м над терасою, по ній — бордюр і дерев'яні
	# поручні (як балюстрада): край тераси читається, а падати нікуди.
	var base := top + 0.1 - 3.12
	var offset := 0.32
	# Сторони: [початок, кінець, нормаль назовні].
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
		# Верхня тераса стоїть на нижній — північну стіну ховає скеля позаду.
		var length := a.distance_to(b)
		var dir := (b - a).normalized()
		var pieces := int(round(length / 2.0))
		for k in pieces:
			var mid := a + dir * (k * 2.0 + 1.0)
			if _stair_gap(mid, normal, top):
				continue
			var pos := mid + normal * offset
			var yaw := atan2(normal.x, normal.y)
			var wall := _place(V + "Wall_UnevenBrick_Straight.gltf", group, Vector3(pos.x, base, pos.y), yaw)
			wall.set_meta(&"solid", true)
			# Камінь-бордюр по верху стіни — гарний край тераси.
			_place(V + "Prop_ExteriorBorder_Straight1.gltf", "Architecture/Trim",
				Vector3(pos.x - normal.x * 0.05, top + 0.1, pos.y - normal.y * 0.05), yaw)
			_place(V + "Prop_WoodenFence_Single.gltf", "Architecture/Trim",
				Vector3(pos.x - normal.x * 0.15, top + 0.14, pos.y - normal.y * 0.15), yaw)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var c: Vector2 = corner
		var out := Vector2(signf(c.x - rect.get_center().x), signf(c.y - rect.get_center().y)) * offset
		_pillar(Vector3(c.x + out.x, top + 0.45, c.y + out.y), Vector3(0.9, 3.12 + 0.35, 0.9), "Architecture/Walls")

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

# --- сходи ---

func _build_stairs() -> void:
	for s: Array in L.STAIRS:
		var center := Vector2(s[0], s[1])
		var dir: Vector2 = s[2]
		var top: float = s[3]
		var width: float = s[4]
		var side := Vector2(-dir.y, dir.x)
		var yaw := atan2(dir.x, dir.y)
		var lanes := int(round(width / 2.0))
		for step in 2:
			for lane in lanes:
				var lateral := (lane - (lanes - 1) * 0.5) * 2.0
				var p := center + dir * (step * 2.0 + 1.0) + side * lateral
				_place(V + "Stairs_Exterior_Straight.gltf", "Architecture/Stairs", Vector3(p.x, top - 1.0 - step, p.y), yaw)
			# Бічні щоки сходів (камінь), щоб марш не висів у повітрі.
			for k: int in [-1, 1]:
				var cheek := center + dir * (step * 2.0 + 1.0) + side * (width * 0.5 + 0.35) * k
				_place(V + "Wall_BottomCover.gltf", "Architecture/Stairs", Vector3(cheek.x, top - 1.0 - step + 0.8, cheek.y),
					yaw + PI * 0.5, Vector3(1.0, 4.0, 1.0))

# --- площа ---

func _build_plaza() -> void:
	var r := L.PLAZA
	var x := r.position.x + 1.0
	while x < r.end.x:
		var z := r.position.y + 1.0
		while z < r.end.y:
			# Клумба посередині — трава й велике дерево.
			if Vector2(x - L.PLAZA_TREE.x, z - L.PLAZA_TREE.z).length() > L.PLAZA_TREE_RADIUS:
				_place(V + "Floor_UnevenBrick.gltf", "Architecture/Plaza", Vector3(x, L.LOW_HEIGHT + 0.015, z), 0.0)
			z += 2.0
		x += 2.0
	# Бруківка-стежка від площі до сходів (південь і північ).
	for z: float in [12.0, -8.0, -10.0, -12.0]:
		for x2: float in [-1.0, 1.0]:
			_place(V + "Floor_UnevenBrick.gltf", "Architecture/Plaza", Vector3(x2, L.LOW_HEIGHT + 0.015, z), 0.0)
	# Бордюр по краю площі.
	for i in int(r.size.x / 2.0):
		var cx := r.position.x + 1.0 + i * 2.0
		if absf(cx) < 2.0:
			continue
		_place(V + "Prop_ExteriorBorder_Straight1.gltf", "Architecture/Trim", Vector3(cx, L.LOW_HEIGHT, r.end.y), PI)
		_place(V + "Prop_ExteriorBorder_Straight1.gltf", "Architecture/Trim", Vector3(cx, L.LOW_HEIGHT, r.position.y), 0.0)

# --- будиночки (з модулів) ---

## Невеликий будинок: стіни з тиньку на кам'яному цоколі, дах із черепиці.
## w, d — у клітинках по 2 м. Двері з боку door_side (0 — південь).
func _house(origin: Vector3, w: int, d: int, yaw: float, door_side: int = 0) -> void:
	var group := "Architecture/Houses"
	var holder := Node3D.new()
	holder.name = "House%d" % _group(group).get_child_count()
	_group(group).add_child(holder)
	holder.position = origin
	holder.rotation.y = yaw
	holder.set_meta(&"solid", true)
	_shade.append([Vector2(origin.x, origin.z) + Vector2(1.5, 1.5), float(maxi(w, d)) * 2.2])
	var hw := w
	var hd := d
	# Стіни по чотирьох боках: спершу кам'яні (нижній ярус), вище тиньк.
	for side in 4:
		var count := w if side < 2 else d
		for k in count:
			var t := (k * 2.0 + 1.0) - count
			var pos: Vector3
			var rot: float
			match side:
				0: pos = Vector3(t, 0, hd); rot = 0.0
				1: pos = Vector3(-t, 0, -hd); rot = PI
				2: pos = Vector3(hw, 0, -t); rot = PI * 0.5
				_: pos = Vector3(-hw, 0, t); rot = -PI * 0.5
			var file := "Wall_UnevenBrick_Straight.gltf"
			if side == door_side and k == count / 2:
				file = "Wall_UnevenBrick_Door_Round.gltf"
			elif (k + side) % 2 == 1:
				file = "Wall_UnevenBrick_Window_Wide_Round.gltf"
			var piece: Node3D = load(V + file).instantiate()
			holder.add_child(piece)
			piece.position = pos
			piece.rotation.y = rot
			var upper: Node3D = load(V + ("Wall_Plaster_Window_Wide_Round.gltf" if (k + side) % 2 == 0 else "Wall_Plaster_WoodGrid.gltf")).instantiate()
			holder.add_child(upper)
			upper.position = pos + Vector3.UP * 3.0
			upper.rotation.y = rot
	for c in [Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd)]:
		for level in 2:
			var corner: Node3D = load(V + "Corner_Exterior_Wood.gltf").instantiate()
			holder.add_child(corner)
			corner.position = c + Vector3.UP * 3.0 * level
	# Дах: найближчий за розміром модуль черепиці.
	var roof_name := "Roof_RoundTiles_%dx%d.gltf" % [mini(w * 2, 8), mini(d * 2, 14)]
	if not ResourceLoader.exists(V + roof_name):
		roof_name = "Roof_RoundTiles_6x8.gltf"
	var roof: Node3D = load(V + roof_name).instantiate()
	holder.add_child(roof)
	roof.position = Vector3(0, 6.0, 0)
	var chimney: Node3D = load(V + "Prop_Chimney.gltf").instantiate()
	holder.add_child(chimney)
	chimney.position = Vector3(hw - 1.0, 6.3, -hd + 1.0)

func _build_houses() -> void:
	var y := L.LOW_HEIGHT
	# Будинки в кутах тераси, двері — до площі.
	_house(Vector3(-17.0, y, 9.0), 2, 2, PI * 0.5)
	_house(Vector3(17.0, y, 9.0), 2, 2, -PI * 0.5)
	_house(Vector3(-17.0, y, -24.0), 2, 3, PI * 0.5)
	_house(Vector3(17.0, y, -24.0), 2, 3, -PI * 0.5)
	_build_stations()

## Робочі місця NPC: реквізит довкола кожного — видно, хто чим зайнятий.
func _station(npc: StringName, items: Array) -> void:
	var info: Array = L.NPCS[npc]
	var origin: Vector3 = info[0]
	var yaw: float = info[1]
	var basis := Basis(Vector3.UP, yaw)
	for item: Array in items:
		var local: Vector3 = item[1]
		var pos: Vector3 = origin + basis * local
		var node := _place(P + String(item[0]) + ".gltf", "Architecture/Stations", Vector3(pos.x, origin.y, pos.z),
			yaw + float(item[2]), Vector3.ONE * float(item[3]) if item.size() > 3 else Vector3.ONE)
		node.set_meta(&"solid", true)

func _build_stations() -> void:
	# Наставниця героїв — тренувальні манекени, стійка зі зброєю, прапор.
	_station(&"mentor", [["Dummy", Vector3(-1.8, 0, -1.6), 0.4], ["Dummy", Vector3(1.6, 0, -2.2), -0.3],
		["WeaponStand", Vector3(-2.4, 0, 0.6), 1.2], ["Shield_Wooden", Vector3(0.4, 0, -2.6), 0.2], ["Bench", Vector3(2.6, 0, 0.8), -1.2]])
	# Зброяр — ковадло на колоді, верстак, стійка зброї, бочка.
	_station(&"smith", [["Anvil_Log", Vector3(0.0, 0, 1.4), 0.0], ["Workbench", Vector3(-2.2, 0, -1.2), 0.3],
		["WeaponStand", Vector3(2.4, 0, -0.8), -0.8], ["Barrel", Vector3(-2.6, 0, 1.2), 0.0], ["Crate_Metal", Vector3(2.2, 0, 1.6), 0.4]])
	# Мудрець талантів — пюпітр із книгою, свічки, казан, книжкова шафа.
	_station(&"sage", [["BookStand", Vector3(0.0, 0, 1.3), PI], ["CandleStick_Stand", Vector3(-1.4, 0, 1.0), 0.0],
		["CandleStick_Stand", Vector3(1.4, 0, 1.0), 0.0], ["Cauldron", Vector3(-2.4, 0, -1.0), 0.0], ["Bookcase_2", Vector3(1.8, 0, -2.0), -0.3],
		["Chest_Wood", Vector3(-1.2, 0, -2.2), 0.5]])
	# Торговець — візок-ятка, бочки з яблуками, ящики, мішки.
	_station(&"merchant", [["Stall_Cart_Empty", Vector3(0.6, 0, -1.4), PI], ["Barrel_Apples", Vector3(-2.2, 0, -0.2), 0.0],
		["FarmCrate_Apple", Vector3(-2.0, 0, 1.2), 0.3], ["Crate_Wooden", Vector3(2.6, 0, 0.4), 0.2], ["Bag", Vector3(1.8, 0, 1.6), 0.0],
		["Pouch_Large", Vector3(-1.0, 0, 1.8), 0.0]])
	# Старійшина — дошка оголошень (прапор із сувоями) і лава під деревом.
	_station(&"elder", [["Chest_Wood", Vector3(-2.0, 0, -0.4), 0.3], ["Table_Large", Vector3(2.2, 0, -0.4), -0.3],
		["Scroll_1", Vector3(2.0, 0.81, -0.4), 0.2], ["Scroll_2", Vector3(2.5, 0.81, -0.2), -0.4]])
	_shade.append([Vector2(L.PLAZA_TREE.x, L.PLAZA_TREE.z), 3.6])
	var tree := _place(N + "CommonTree_3.gltf", "Nature/BigTrees", L.PLAZA_TREE, 0.4, Vector3.ONE * 0.95)
	tree.set_meta(&"solid", true)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		_place(P + "Bench.gltf", "Architecture/Stations", L.PLAZA_TREE + Vector3(cos(a), 0, sin(a)) * (L.PLAZA_TREE_RADIUS + 0.4),
			-a + PI * 0.5)

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
		var node := _place(files[_rng.randi() % files.size()], group, Vector3(p.x, _ground(p.x, p.y) - 0.05, p.y),
			_rng.randf() * TAU, Vector3.ONE * s)
		node.set_meta(&"solid", true)

## Чи місце зайняте (тераси, стежки, сходи, будинки) — природі туди не можна.
func _busy(p: Vector2, margin: float = 1.5) -> bool:
	for rect: Rect2 in [L.LOW_TERRACE, L.HIGH_TERRACE]:
		if rect.grow(margin).has_point(p):
			return true
	if L.mask(p.x, p.y, 0.0).r > 0.05:
		return true
	if Vector2(L.SPAWN.x, L.SPAWN.z).distance_to(p) < 6.0:
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
			Vector3(x, L.LOW_HEIGHT - 0.5, -34.0 - _rng.randf_range(0, 3)), _rng.randf() * TAU,
			Vector3.ONE * _rng.randf_range(2.6, 3.6)).set_meta(&"solid", true)

# --- ресурси для квестів (не пакуються: їх рубають і збирають) ---

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
		_place(P + "Bench.gltf", "Architecture/Camp", p, -a + PI * 0.5, Vector3(0.7, 1.0, 1.0)).set_meta(&"solid", true)
	var wagon := Vector3(-5.5, 0.0, 30.0)
	wagon.y = _ground(wagon.x, wagon.z)
	_place(V + "Prop_Wagon.gltf", "Architecture/Camp", wagon, 0.35).set_meta(&"solid", true)
	_place(P + "Barrel.gltf", "Architecture/Camp", wagon + Vector3(1.6, 0, 1.2), 0.0)
	_place(P + "Crate_Wooden.gltf", "Architecture/Camp", wagon + Vector3(1.9, 0, 0.1), 0.4)
	# Менгіри — старі камені на краю галявини.
	for i in 4:
		var a := -0.9 + i * 0.6
		var p := Vector3(sin(a) * 11.0, 0, 36.0 + cos(a) * 5.0)
		p.y = _ground(p.x, p.z) - 0.2
		_place(N + "Rock_Medium_%d.gltf" % (1 + i % 3), "Nature/Rocks", p, _rng.randf() * TAU,
			Vector3(0.55, 1.5 + 0.3 * (i % 2), 0.55)).set_meta(&"solid", true)

## Біля верху кожних сходів — кам'яні стовпці з вогнем.
func _build_stair_fires() -> void:
	for s: Array in L.STAIRS:
		var center := Vector2(s[0], s[1])
		var dir: Vector2 = s[2]
		var side := Vector2(-dir.y, dir.x)
		var top: float = s[3]
		for k: int in [-1, 1]:
			var p := center - dir * 0.6 + side * (float(s[4]) * 0.5 + 0.9) * k
			_pillar(Vector3(p.x, top + 1.25, p.y), Vector3(0.7, 1.3, 0.7), "Architecture/Walls")
			_fire_marker(Vector3(p.x, top + 1.32, p.y))

## Кам'яний стовп: проста коробка з цегляною текстурою набору (дешево).
## top_center — центр верху; size — ширина, висота, глибина.
func _pillar(top_center: Vector3, size: Vector3, group: String) -> void:
	if not _cache.has("pillar_mesh"):
		var brick: Node3D = load(V + "Wall_UnevenBrick_Straight.gltf").instantiate()
		var source: MeshInstance3D = brick.find_children("*", "MeshInstance3D", true, false)[0]
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		box.material = source.mesh.surface_get_material(0)
		_cache["pillar_mesh"] = box
		brick.free()
	var node := MeshInstance3D.new()
	node.mesh = _cache["pillar_mesh"]
	_group(group).add_child(node)
	node.scale = size
	node.position = top_center - Vector3(0, size.y * 0.5, 0)
	node.set_meta(&"solid", true)
	var cap := _place(V + "Prop_ExteriorBorder_Straight1.gltf", "Architecture/Trim", top_center + Vector3(0, 0, -size.z * 0.5), 0.0,
		Vector3(size.x / 2.0 + 0.1, 1.0, (size.z + 0.15) / 0.7))

func _fire_marker(pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = "Fire%d" % _group("Effects").get_child_count()
	_group("Effects").add_child(marker)
	marker.position = pos

# --- місця NPC і портал (вузли-мітки: їх оживляє haven.gd) ---

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
	_root.add_child(portal)
	portal.position = L.PORTAL
	var spawn := Marker3D.new()
	spawn.name = "SpawnSpot"
	_root.add_child(spawn)
	spawn.position = L.SPAWN + Vector3.UP * 0.1

# --- герой, камера й шар інтерфейсу (сам інтерфейс складає haven.gd) ---

func _take_player_and_hud() -> void:
	var player: Node3D = load("res://scenes/world/player_3d.tscn").instantiate()
	player.name = "Player"
	_root.add_child(player)
	player.position = L.SPAWN + Vector3.UP * 0.1
	var rig: Node3D = load("res://scenes/world/camera_rig.tscn").instantiate()
	rig.name = "CameraRig"
	_root.add_child(rig)
	rig.set("target_path", NodePath("../Player"))
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	_root.add_child(hud)
