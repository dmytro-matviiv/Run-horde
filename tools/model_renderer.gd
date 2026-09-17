extends Node

## Інструмент розробника: пече з 3D-моделей (GLB) анімовані спрайт-листи
## для гри. Godot і читає моделі, і рендерить їх, тож окремий Blender не
## потрібен — увесь конвеєр лишається в одному проєкті.
##
## Модель ставиться під камеру, нахилену згори (як у мобільних іграх
## цього жанру), програється кожна анімація, і кадри знімаються у
## прозорі PNG, складені в один аркуш.
##
## РОЗКЛАДКА АРКУША (однакова для всіх монстрів, щоб описи ворогів були
## простими): 8 колонок, 8 рядків, по рядку на стан:
##   рядок 0..3 — спокій, хода, атака, смерть (вигляд СПЕРЕДУ)
##   рядок 4..7 — те саме ЗЗАДУ (коли ворог іде від гравця)
##
## Моделі лежать ПОЗА проєктом (D:/Claude code/assets_incoming) і
## читаються напряму з диска. Так сирі файли не потрапляють ні в
## репозиторій, ні у збірку гри — у грі опиняються лише готові аркуші.
##
## Запуск (відкриється вікно й закриється само):
##   godot --path "D:/Claude code/idle survivor_like" tools/render_models.tscn

const MODELS_DIR := "D:/Claude code/assets_incoming/monsters/"
const OUTPUT_DIR := "res://assets/sprites/monsters/"

const CAMERA_PITCH_DEG := 55.0
const FRAME_SIZE := 128
const COLUMNS := 8
const MARGIN := 1.1

## Скільки кадрів знімаємо з кожної анімації. Хода й атака — головні,
## тож їм повний рядок; спокій коротший, бо це майже нерухома поза.
const CLIP_FRAMES := {
	"idle": 6,
	"walk": 8,
	"attack": 8,
	"death": 8,
}
const CLIP_ORDER := ["idle", "walk", "attack", "death"]

## У різних моделей анімації звуться по-різному (хтось ходить, хтось
## літає; хтось б'є кулаком, хтось кусає). Беремо перше, що знайдеться.
const CLIP_ALIASES := {
	"idle": ["Idle", "Flying_Idle"],
	"walk": ["Walk", "Run", "Fast_Flying"],
	"attack": ["Punch", "Bite_Front", "Headbutt"],
	"death": ["Death"],
}

## Кого рендеримо: файл моделі -> ім'я спрайта в грі.
const JOBS := [
	{"model": "Armabee.glb", "id": "armabee"},
	{"model": "Orc Enemy.glb", "id": "orc"},
	{"model": "Wizard.glb", "id": "wizard"},
	{"model": "Yeti.glb", "id": "yeti"},
	{"model": "Green Spiky Blob.glb", "id": "spiky_blob"},
	{"model": "Demon-LnfIziKv4o.glb", "id": "demon"},
	{"model": "Dragon Evolved.glb", "id": "dragon"},
]

const VIEWS := [180.0, 0.0]   # спереду, ззаду

var _viewport: SubViewport
var _camera: Camera3D
var _world: Node3D

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_build_studio()
	await get_tree().process_frame
	for job: Dictionary in JOBS:
		await _render_monster(job)
	print("RENDER: готово")
	get_tree().quit(0)

## "Фотостудія": прозоре тло й два джерела світла, щоб модель була
## об'ємною, а не пласкою плямою.
func _build_studio() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(FRAME_SIZE, FRAME_SIZE)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	_world = Node3D.new()
	_viewport.add_child(_world)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_world.add_child(_camera)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	key_light.light_energy = 1.7
	_world.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-20.0, 140.0, 0.0)
	fill_light.light_energy = 0.8
	fill_light.light_color = Color(0.75, 0.82, 1.0)
	_world.add_child(fill_light)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.52, 0.54, 0.62)
	environment.ambient_light_energy = 1.0
	_camera.environment = environment
	_camera.attributes = CameraAttributesPractical.new()

## Читає GLB з диска без імпорту в проєкт.
func _load_model(file_name: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(MODELS_DIR + file_name, state) != OK:
		push_error("Не вдалось прочитати модель %s" % file_name)
		return null
	return document.generate_scene(state) as Node3D

func _find_player(model: Node3D) -> AnimationPlayer:
	for child in model.find_children("*", "AnimationPlayer", true, false):
		return child as AnimationPlayer
	return null

## Шукає анімацію за списком можливих назв: "CharacterArmature|Walk"
## збігається з "Walk".
func _resolve_animation(player: AnimationPlayer, clip: String) -> String:
	var names := player.get_animation_list()
	for wanted: String in CLIP_ALIASES[clip]:
		for name: String in names:
			if name.get_slice("|", name.get_slice_count("|") - 1) == wanted:
				return name
	return ""

func _render_monster(job: Dictionary) -> void:
	var model := _load_model(job.model)
	if model == null:
		return
	_world.add_child(model)
	var player := _find_player(model)
	if player == null:
		push_error("У моделі %s немає анімацій" % job.model)
		model.queue_free()
		return

	await get_tree().process_frame
	_frame_camera(model)

	var sheet := Image.create(COLUMNS * FRAME_SIZE, COLUMNS * FRAME_SIZE, false, Image.FORMAT_RGBA8)
	var row := 0
	for view_index in VIEWS.size():
		model.rotation_degrees = Vector3(0.0, VIEWS[view_index], 0.0)
		for clip: String in CLIP_ORDER:
			await _render_clip(player, sheet, clip, row)
			row += 1

	var path := OUTPUT_DIR + "enemy_%s.png" % job.id
	sheet.save_png(path)
	print("RENDER: %s" % path.get_file())

	model.queue_free()
	await get_tree().process_frame

## Знімає один стан (рядок аркуша): рівномірно проходить анімацію й
## зберігає кадри. Якщо такої анімації в моделі немає — лишаємо рядок
## порожнім, гра просто не використає цей стан.
func _render_clip(player: AnimationPlayer, sheet: Image, clip: String, row: int) -> void:
	var animation_name := _resolve_animation(player, clip)
	if animation_name == "":
		return
	var length: float = player.get_animation(animation_name).length
	var frames: int = CLIP_FRAMES[clip]
	player.play(animation_name)

	for i in frames:
		# Смерть програємо до кінця, циклічні стани — без останнього
		# кадру, щоб цикл не "затинався" на повторі першого.
		var t: float = length * (float(i) / float(frames - 1) if clip == "death" else float(i) / float(frames))
		player.seek(t, true)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var frame_image := _viewport.get_texture().get_image()
		sheet.blit_rect(
			frame_image,
			Rect2i(Vector2i.ZERO, frame_image.get_size()),
			Vector2i(i * FRAME_SIZE, row * FRAME_SIZE),
		)

## Ставимо камеру так, щоб модель заповнювала кадр незалежно від її
## власного масштабу.
func _frame_camera(model: Node3D) -> void:
	var bounds := _get_bounds(model)
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 0.01)

	var pitch := deg_to_rad(CAMERA_PITCH_DEG)
	_camera.position = center + Vector3(0.0, sin(pitch), cos(pitch)) * radius * 4.0
	_camera.look_at(center, Vector3.UP)
	_camera.size = radius * 2.0 * MARGIN

func _get_bounds(node: Node) -> AABB:
	var bounds := AABB()
	var first := true
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var instance := child as VisualInstance3D
		var child_bounds: AABB = instance.global_transform * instance.get_aabb()
		if first:
			bounds = child_bounds
			first = false
		else:
			bounds = bounds.merge(child_bounds)
	return bounds
