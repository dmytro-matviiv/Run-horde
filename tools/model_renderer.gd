extends Node

## Інструмент розробника: перетворює 3D-модель (GLB) на спрайти для
## гри. Godot уміє й читати ці моделі, і рендерити їх, тож окремий
## Blender не потрібен — весь конвеєр лишається в одному проєкті.
##
## Як це працює: модель ставиться перед камерою, нахиленою згори (як в
## Archero), обертається на потрібні боки, кожен ракурс знімається у
## прозорий PNG. Якщо в моделі є анімації — знімається послідовність
## кадрів і складається в спрайт-лист, який гра вже вміє програвати
## (VfxDef/SpriteAnimator).
##
## Запуск (вікно відкриється на кілька секунд і закриється само):
##   godot --path <проєкт> tools/render_models.tscn
##
## Результат кладеться в assets/sprites/ і одразу підхоплюється
## описами ворогів (EnemyDef.texture / EnemyDef.sheet).

## Кут камери згори: 0° — збоку, 90° — точно згори. 55° дає той самий
## "3D-вигляд згори", що й у мобільних іграх цього жанру.
const CAMERA_PITCH_DEG := 55.0
const FRAME_SIZE := 256
const MARGIN := 1.12          # запас навколо моделі, щоб не обрізало краї

## Що рендеримо: id -> {path, кольорові варіанти текстур, поворот}.
const JOBS := [
	{
		"id": "imp",
		"model": "res://assets_incoming/bestiary/Bestiary - Dungeon Monsters Kit[Standard]/Exports/GLB (Godot-Unreal)/Imp.glb",
		"variants": [
			{"suffix": "red", "texture": "res://assets_incoming/bestiary/Bestiary - Dungeon Monsters Kit[Standard]/Textures/T_Imp_BaseColor_1.png"},
			{"suffix": "green", "texture": "res://assets_incoming/bestiary/Bestiary - Dungeon Monsters Kit[Standard]/Textures/T_Imp_BaseColor_2.png"},
			{"suffix": "blue", "texture": "res://assets_incoming/bestiary/Bestiary - Dungeon Monsters Kit[Standard]/Textures/T_Imp_BaseColor_3.png"},
		],
	},
	{
		"id": "puglin",
		"model": "res://assets_incoming/bestiary/Bestiary - Dungeon Monsters Kit[Standard]/Exports/GLB (Godot-Unreal)/Puglin.glb",
		"variants": [
			{"suffix": "red", "texture": "res://assets_incoming/bestiary/Bestiary - Dungeon Monsters Kit[Standard]/Textures/T_Puglin_BaseColor_1.png"},
			{"suffix": "green", "texture": "res://assets_incoming/bestiary/Bestiary - Dungeon Monsters Kit[Standard]/Textures/T_Puglin_BaseColor_2.png"},
			{"suffix": "blue", "texture": "res://assets_incoming/bestiary/Bestiary - Dungeon Monsters Kit[Standard]/Textures/T_Puglin_BaseColor_3.png"},
		],
	},
]

## Ракурси: спереду (йде на гравця) і ззаду (йде від гравця). Боки
## гра робить дзеркаленням, тож рендерити їх окремо немає сенсу.
const VIEWS := [
	{"suffix": "", "yaw_deg": 180.0},
	{"suffix": "_back", "yaw_deg": 0.0},
]

const OUTPUT_DIR := "res://assets/sprites/"

var _viewport: SubViewport
var _camera: Camera3D
var _pivot: Node3D

func _ready() -> void:
	_build_studio()
	await get_tree().process_frame
	for job: Dictionary in JOBS:
		await _render_job(job)
	print("RENDER: готово")
	get_tree().quit(0)

## "Фотостудія": окремий 3D-світ із прозорим тлом і двома джерелами
## світла, щоб модель була об'ємною, а не пласкою плямою.
func _build_studio() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(FRAME_SIZE, FRAME_SIZE)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	var world := Node3D.new()
	_viewport.add_child(world)

	_pivot = Node3D.new()
	world.add_child(_pivot)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(_camera)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	key_light.light_energy = 1.6
	world.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-20.0, 140.0, 0.0)
	fill_light.light_energy = 0.7
	fill_light.light_color = Color(0.75, 0.82, 1.0)
	world.add_child(fill_light)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.47, 0.55)
	environment.ambient_light_energy = 1.0
	var camera_attributes := CameraAttributesPractical.new()
	_camera.environment = environment
	_camera.attributes = camera_attributes

func _render_job(job: Dictionary) -> void:
	var scene: PackedScene = load(job.model)
	if scene == null:
		push_error("Не знайшов модель: %s" % job.model)
		return

	for variant: Dictionary in job.variants:
		for view: Dictionary in VIEWS:
			var model: Node3D = scene.instantiate()
			_pivot.add_child(model)
			_apply_texture(model, variant.texture)
			model.rotation_degrees = Vector3(0.0, view.yaw_deg, 0.0)
			_frame_camera(model)

			# Два кадри очікування: перший — щоб модель стала на місце,
			# другий — щоб SubViewport устиг намалювати саме її.
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw

			var image := _viewport.get_texture().get_image()
			var file_name := "enemy_%s_%s%s.png" % [job.id, variant.suffix, view.suffix]
			image.save_png(OUTPUT_DIR + file_name)
			print("RENDER: %s" % file_name)

			model.queue_free()
			await get_tree().process_frame

## Ставимо камеру так, щоб модель заповнювала кадр незалежно від її
## справжнього розміру — моделі з різних наборів бувають різного масштабу.
func _frame_camera(model: Node3D) -> void:
	var bounds := _get_bounds(model)
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 0.01)

	var pitch := deg_to_rad(CAMERA_PITCH_DEG)
	var offset := Vector3(0.0, sin(pitch), cos(pitch)) * radius * 4.0
	_camera.position = center + offset
	_camera.look_at(center, Vector3.UP)
	_camera.size = radius * 2.0 * MARGIN

## Габарити моделі разом з усіма її частинами (тіло, зброя, деталі).
func _get_bounds(node: Node) -> AABB:
	var bounds := AABB()
	var first := true
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var instance := child as VisualInstance3D
		var child_bounds := instance.global_transform * instance.get_aabb()
		if first:
			bounds = child_bounds
			first = false
		else:
			bounds = bounds.merge(child_bounds)
	return bounds

## Кольорові варіанти: у наборі кілька текстур базового кольору на одну
## модель, тож один монстр дає кілька різних на вигляд ворогів.
func _apply_texture(model: Node3D, texture_path: String) -> void:
	var texture: Texture2D = load(texture_path)
	if texture == null:
		return
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var material := StandardMaterial3D.new()
			material.albedo_texture = texture
			material.roughness = 0.85
			mesh_instance.set_surface_override_material(surface, material)
