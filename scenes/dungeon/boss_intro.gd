extends Control
class_name BossIntro

## ВИХІД МЕГА-БОСА: ворота щойно зачинились, і перш ніж почнеться бій,
## екран на кілька секунд показує самого боса — кіно, а не бойовку.
## Чорні смуги зверху й знизу, модель боса виїжджає з тіні під плавним
## обертанням у власній 3D-вітрині (той самий прийом, що й вітрина
## героя в меню, лише на весь екран), а тоді вибухає агресивний напис
## з його іменем. Торкнувся екрана — кіно можна пропустити одразу.
##
## Своєї анімації в моделі нема (лише поза спокою) — драму тут продає
## монтаж: наїзд камери, спалах, розмальовка й самі кольори боса, а не
## рух скелета.

signal finished

const AUTO_ADVANCE := 3.4
const ENTER_TIME := 1.0
const ROTATE_SPEED := 0.5

var _pivot: Node3D
var _viewport: SubViewport
var _camera: Camera3D
var _title_label: Label
var _done := false

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(model_scene: PackedScene, tint: Color, glow: Color, title: String, flavor: String) -> void:
	_build(model_scene, tint, glow, title, flavor)

func _build(model_scene: PackedScene, tint: Color, glow: Color, title: String, flavor: String) -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var stage := SubViewportContainer.new()
	stage.stretch = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.modulate.a = 0.0
	add_child(stage)
	_build_stage(stage, model_scene, tint, glow)

	var bar_top := ColorRect.new()
	bar_top.color = Color(0.02, 0.02, 0.03)
	bar_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar_top.offset_bottom = 0.0
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_top)

	var bar_bottom := ColorRect.new()
	bar_bottom.color = Color(0.02, 0.02, 0.03)
	bar_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar_bottom.offset_top = 0.0
	bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_bottom)

	var text_holder := CenterContainer.new()
	text_holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	text_holder.offset_top = -190.0
	text_holder.offset_bottom = -70.0
	text_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text_holder)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	text_holder.add_child(column)

	_title_label = Label.new()
	_title_label.text = title.to_upper()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.hud_text(_title_label, 42, UiTheme.DANGER)
	_title_label.add_theme_constant_override("outline_size", 6)
	_title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.01, 0.01))
	_title_label.scale = Vector2.ZERO
	column.add_child(_title_label)

	var flavor_label: Label
	if flavor != "":
		flavor_label = Label.new()
		flavor_label.text = flavor
		flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		flavor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavor_label.custom_minimum_size = Vector2(520, 0)
		UiTheme.hud_text(flavor_label, 18, UiTheme.TEXT_DIM)
		flavor_label.modulate.a = 0.0
		column.add_child(flavor_label)

	var hint := Label.new()
	hint.text = "Торкнись, щоб пропустити"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -230.0
	hint.offset_top = -34.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.hud_text(hint, 13, UiTheme.TEXT_DIM)
	hint.modulate.a = 0.0
	add_child(hint)

	var sequence := create_tween()
	sequence.tween_property(backdrop, "color:a", 0.78, 0.3)
	sequence.parallel().tween_property(bar_top, "offset_bottom", 92.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sequence.parallel().tween_property(bar_bottom, "offset_top", -92.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sequence.parallel().tween_property(stage, "modulate:a", 1.0, 0.4)
	sequence.parallel().tween_property(_pivot, "position:x", 0.0, ENTER_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sequence.tween_callback(_punch_title)
	if flavor_label != null:
		sequence.tween_property(flavor_label, "modulate:a", 1.0, 0.35)
	sequence.tween_property(hint, "modulate:a", 0.6, 0.3)
	sequence.tween_interval(maxf(AUTO_ADVANCE - ENTER_TIME - 1.0, 0.4))
	sequence.tween_callback(_finish)

func _build_stage(stage: SubViewportContainer, model_scene: PackedScene, tint: Color, glow: Color) -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.add_child(_viewport)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var instance: Node3D = model_scene.instantiate()
	_pivot.add_child(instance)
	Enemy3D.paint_model(instance, tint, glow)

	var bounds := _visual_bounds(instance)
	var height: float = maxf(bounds.size.y, 1.0)
	instance.position.y -= bounds.position.y

	_camera = Camera3D.new()
	_camera.fov = 32.0
	var distance: float = (height * 0.62) / tan(deg_to_rad(_camera.fov * 0.5))
	_camera.position = Vector3(0, height * 0.55, distance)
	_viewport.add_child(_camera)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -25, 0)
	key.light_energy = 1.5
	key.light_color = Color(1.0, 0.92, 0.85)
	_viewport.add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(0, height * 0.7, -2.0)
	rim.light_energy = 2.2
	rim.light_color = tint if tint != Color.WHITE else Color(0.9, 0.3, 0.35)
	rim.omni_range = height * 3.0
	_viewport.add_child(rim)

	# Виходить з темряви: старт збоку й у тіні, тоді сунеться в кадр.
	_pivot.position.x = -height * 1.6

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

func _punch_title() -> void:
	_title_label.pivot_offset = _title_label.size * 0.5
	var tween := _title_label.create_tween()
	tween.tween_property(_title_label, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title_label, "scale", Vector2.ONE, 0.12)
	var flicker := _title_label.create_tween().set_loops(3)
	flicker.tween_property(_title_label, "modulate", Color(1.4, 1.2, 1.1), 0.08)
	flicker.tween_property(_title_label, "modulate", Color.WHITE, 0.1)

func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotate_y(ROTATE_SPEED * delta)

func _gui_input(event: InputEvent) -> void:
	if not _done and (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: finished.emit())
