extends SubViewportContainer
class_name ModelPreview

## Вітрина 3D-моделі в меню: герой зі своєю зброєю або сама зброя,
## повільно обертається на місці.
##
## Раніше на екрані вибору героя була пласка картинка, і гравець не
## бачив, ким насправді гратиме. Тепер тут та сама модель, що й у бою:
## помінялась зброя — видно в руці.
##
## Поки в героя немає власної моделі, показується тимчасова в його
## кольорі, а екран пише про це чесно.

const ROTATION_SPEED := 0.6

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _placeholder := false

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	# Вітрина маленька, тож малюємо її ощадливо: без згладжування й тіней.
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)

	_camera = Camera3D.new()
	_camera.position = Vector3(0, 1.1, 2.6)
	_camera.rotation_degrees = Vector3(-8, 0, 0)
	_camera.fov = 40.0
	_viewport.add_child(_camera)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.3
	_viewport.add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.5, 1.5, 2.0)
	fill.light_energy = 1.2
	fill.omni_range = 6.0
	_viewport.add_child(fill)

## Герой зі своєю зброєю. Повертає true, якщо модель тимчасова.
func show_hero(hero: HeroDef, weapon: WeaponDef) -> bool:
	_clear()
	var built := HeroBuilder.build_model(hero)
	var instance: Node3D = built[0]
	_placeholder = built[1]
	if instance == null:
		return true
	_pivot.add_child(instance)
	HeroBuilder.attach_weapon(instance, hero, weapon)
	HeroBuilder.play_idle(instance)
	_frame(instance, 1.15)
	return _placeholder

## Сама зброя великим планом.
func show_weapon(weapon: WeaponDef) -> bool:
	_clear()
	var scene := ArtSlots.weapon_model(weapon.id, weapon.model_scene)
	var instance: Node3D
	_placeholder = scene == null
	if scene != null:
		instance = scene.instantiate()
	else:
		instance = WeaponModels.build(weapon.style_3d, weapon.color)
	_pivot.add_child(instance)
	_frame(instance, 1.4)
	return _placeholder

## Ставить камеру так, щоб модель уміщалась повністю. Раніше камера
## стояла на фіксованій відстані, і високому героєві зрізало голову.
func _frame(instance: Node3D, margin: float) -> void:
	var bounds := _visual_bounds(instance)
	if bounds.size.y <= 0.01:
		_camera.position = Vector3(0, 1.0, 2.6)
		return
	var height: float = maxf(bounds.size.y, bounds.size.x * 0.8)
	var distance: float = (height * 0.5) / tan(deg_to_rad(_camera.fov * 0.5)) * margin
	var center_y: float = bounds.position.y + bounds.size.y * 0.5
	_camera.position = Vector3(0, center_y, distance)
	_camera.rotation_degrees = Vector3.ZERO

## Габарити всього, що видно в моделі (у її власних координатах).
func _visual_bounds(instance: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in instance.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		var box: AABB = visual.global_transform * visual.get_aabb()
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	return bounds

func _clear() -> void:
	for child in _pivot.get_children():
		child.queue_free()
	_pivot.rotation = Vector3.ZERO

func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotate_y(ROTATION_SPEED * delta)

func _notification(what: int) -> void:
	# Поки вітрини не видно на екрані, не малюємо її взагалі.
	if what == NOTIFICATION_VISIBILITY_CHANGED and _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() \
			else SubViewport.UPDATE_DISABLED
