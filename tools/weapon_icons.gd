extends Node

## Іконки зброї для арсеналу — рендер справжніх 3D-моделей на прозорому
## тлі, 128×128. Запусти цю сцену (F6 у редакторі), і для кожної зброї,
## що має модель, з'явиться assets/ui/icons/weapons/<id>.png.
##   godot --path . res://tools/weapon_icons.tscn -- --out=D:/папка
##
## Клинки лягають по діагоналі вістрям угору-праворуч (у моделі вістря —
## вісь +Y, як і вимагає ART_GUIDE), стволи — дулом праворуч, так, як їх
## тримає рука. Стартовий меч вартової вбудований у модель героїні — його
## беремо звідти.

const OUT_DIR := "res://assets/ui/icons/weapons"
const SIZE := 128
## Інший напрям вістря в моделі, якщо вона не за правилом "+Y".
const TIP_OVERRIDES := {}

func _ready() -> void:
	var out_dir := OUT_DIR
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.get_slice("=", 1)
	if out_dir.begins_with("res://"):
		out_dir = ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)

	var viewport := SubViewport.new()
	# Рендеримо вдвічі більше і зменшуємо — краї виходять гладкими.
	viewport.size = Vector2i(SIZE * 2, SIZE * 2)
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.55
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -35, 0)
	key.light_energy = 1.3
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 150, 0)
	fill.light_energy = 0.45
	viewport.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 0, 10)
	viewport.add_child(camera)

	var made := 0
	for weapon: WeaponDef in WeaponPool.ALL_WEAPONS:
		var model := _model(weapon)
		if model == null:
			continue   # моделі ще немає — в арсеналі лишається намальована заглушка
		var holder := Node3D.new()
		viewport.add_child(holder)
		holder.add_child(model)
		if weapon.ranged_3d:
			# Стволи — як у руці: там дуло дивиться вздовж +Y кістки.
			var grip := Basis.from_euler(weapon.grip_rotation_deg * (PI / 180.0))
			model.basis = Basis(Vector3.BACK, deg_to_rad(12.0 - 90.0)) * grip
		else:
			var tip: Vector3 = TIP_OVERRIDES.get(weapon.id, Vector3.UP)
			model.basis = Basis(Vector3.BACK, deg_to_rad(45.0) - atan2(tip.y, tip.x)) * model.basis
		# Легкий поворот, щоб було видно об'єм, а не пласку тінь.
		holder.rotation_degrees = Vector3(12, -18, 0)
		await get_tree().process_frame
		var bounds := _bounds(holder)
		holder.position = -bounds.get_center()
		camera.size = maxf(bounds.size.x, bounds.size.y) * 1.08
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		image.save_png("%s/%s.png" % [out_dir, weapon.id])
		print("ICON: ", weapon.id)
		made += 1
		holder.queue_free()
		await get_tree().process_frame
	print("ICON: готово, іконок ", made, " у ", out_dir)
	get_tree().quit(0)

func _model(weapon: WeaponDef) -> Node3D:
	var scene := ArtSlots.weapon_model(weapon.id, weapon.model_scene)
	if scene != null:
		return scene.instantiate()
	if weapon.style_3d != "sword":
		return null
	# Меч без власної моделі — той, що вбудований у модель героя.
	var hero := HeroPool.get_def(weapon.hero_id)
	var hero_scene := ArtSlots.hero_model(hero.id, hero.model_scene)
	if hero_scene == null:
		return null
	var hero_model: Node3D = hero_scene.instantiate()
	var builtin := hero_model.find_child(String(hero.builtin_weapon_node), true, false) as MeshInstance3D
	var root: Node3D = null
	if builtin != null:
		var sword := builtin.duplicate() as MeshInstance3D
		sword.transform = Transform3D.IDENTITY
		root = Node3D.new()
		root.add_child(sword)
		# У моделі героїні вістря меча дивиться вздовж -Y.
		sword.basis = Basis(Vector3.BACK, PI)
	hero_model.free()
	return root

func _bounds(object: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in object.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		var box: AABB = visual.global_transform * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
