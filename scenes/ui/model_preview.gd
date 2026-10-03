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
## Зброя на вітрині. Моделі різного розміру й лежать хто як (меч — уздовж
## Y, гвинтівка — уздовж Z), тож раніше одна займала пів екрана, а інша
## ледь виднілась, а довга, повернувшись до камери, вилазила на весь кадр.
## Тепер кожну зводимо до однієї довжини, кладемо довгою віссю по
## діагоналі боком до гравця і лише погойдуємо, без повного оберту.
## Камера — без перспективи: розмір не стрибає, коли зброя повертається.
const WEAPON_LENGTH := 1.0
const WEAPON_TILT_DEG := 28.0
## Висота кадру в одиницях зброї (довжина 1): що менше — то більша зброя.
const WEAPON_VIEW := 0.72
const SWAY_ANGLE := 0.45
const SWAY_SPEED := 0.9

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _placeholder := false
## true — показуємо зброю: погойдуємо, а не крутимо.
var _sway := false
var _sway_time := 0.0

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

	# Контрове світло ззаду — світлий обвід по краю силуету, щоб темна
	# модель не зливалась із темним тлом вітрини.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 160, 0)
	rim.light_energy = 1.4
	rim.light_color = Color(1.0, 0.92, 0.8)
	_viewport.add_child(rim)

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
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
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
	# pivot (погойдування) -> tilt (діагональ) -> holder (поворот довгою
	# віссю вбік, масштаб, центр) -> модель.
	var tilt := Node3D.new()
	_pivot.add_child(tilt)
	var holder := Node3D.new()
	tilt.add_child(holder)
	holder.add_child(instance)
	_pose_weapon(holder, instance)
	tilt.rotation_degrees.z = WEAPON_TILT_DEG
	# Широка зброя (сокира) у діагоналі вища — тоді кадр трохи більший,
	# щоб не обрізало; решта — однакового розміру.
	var tilted := _visual_bounds(instance)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = maxf(WEAPON_VIEW, tilted.size.y * 1.2)
	_camera.position = Vector3(0, 0, 4.0)
	_camera.rotation_degrees = Vector3.ZERO
	_sway = true
	return _placeholder

## Найдовшу вісь моделі — вбік (X), довжину — WEAPON_LENGTH, центр — у вісь
## погойдування. Меч стоїть уздовж Y, гвинтівка лежить уздовж Z — обидва
## опиняються боком до гравця, плоскою стороною до камери.
func _pose_weapon(holder: Node3D, instance: Node3D) -> void:
	var bounds := _visual_bounds(instance)
	var extent := bounds.size
	var longest := maxf(extent.x, maxf(extent.y, extent.z))
	if longest <= 0.001:
		return
	var turn := Basis.IDENTITY
	if extent.z >= extent.x and extent.z >= extent.y:
		turn = Basis(Vector3.UP, deg_to_rad(90.0))
	elif extent.y >= extent.x:
		turn = Basis(Vector3.BACK, deg_to_rad(-90.0))
	holder.transform = Transform3D(turn.scaled(Vector3.ONE * (WEAPON_LENGTH / longest)), Vector3.ZERO)
	holder.position = -_visual_bounds(instance).get_center()

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
		_pivot.remove_child(child)
		child.queue_free()
	_pivot.rotation = Vector3.ZERO
	_sway = false
	_sway_time = 0.0

func _process(delta: float) -> void:
	if _pivot == null:
		return
	if _sway:
		_sway_time += delta
		_pivot.rotation.y = sin(_sway_time * SWAY_SPEED) * SWAY_ANGLE
	else:
		_pivot.rotate_y(ROTATION_SPEED * delta)

func _notification(what: int) -> void:
	# Поки вітрини не видно на екрані, не малюємо її взагалі.
	if what == NOTIFICATION_VISIBILITY_CHANGED and _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() \
			else SubViewport.UPDATE_DISABLED
