extends Node3D
class_name HealthBar3D

## Смужка здоров'я над головою: червона у ворогів, зелена у своїх.
##
## Будова — три пласкі прямокутники один над одним:
##   - тло з рамкою;
##   - світлий "слід" щойно втраченого здоров'я, який сповзає з
##     запізненням — так видно, скільки зняв останній удар;
##   - заповнення до поточного здоров'я.
## Скільки заповнено — це просто ширина прямокутника (масштаб по x), а
## шейдер повертає його до камери й тримає лівий край на місці.
##
## ЧОМУ НЕ "instance uniform". Попередня версія передавала частки
## здоров'я параметрами екземпляра. На телефоні (gl_compatibility) усі
## такі параметри лежать в одному спільному буфері разом із колами
## попереджень, калюжами тощо, які оновлюються щокадру, — і в деяких
## ворогів смужка читала чужі числа: блимала білим, доки ворог не впаде.
## Тепер жодних параметрів екземпляра: матеріали спільні (один на колір),
## а все, що змінюється, — це масштаб вузла.
##
## Ворожа смужка з'являється від першого удару й ховається через кілька
## секунд спокою; своя видима завжди.

const WIDTH := 1.0
const HEIGHT := 0.13
## Рамка: частка ширини (з кожного боку) і висоти (зверху й знизу).
const BORDER_X := 0.022
const BORDER_Y := 0.16
const INNER_WIDTH := WIDTH * (1.0 - 2.0 * BORDER_X)
const INNER_HEIGHT := HEIGHT * (1.0 - 2.0 * BORDER_Y)
const TRAIL_COLOR := Color(1.0, 0.92, 0.7)

## Скільки секунд ворожа смужка лишається видимою після удару.
const SHOW_TIME := 4.0
## Пауза перед тим, як слід почне сповзати, і швидкість сповзання.
const TRAIL_DELAY := 0.35
const TRAIL_SPEED := 0.9
## Менше за це — шматок ховаємо (нульовий масштаб рушій не любить).
const MIN_PART := 0.002

## Спільна частина шейдерів: обличчям до камери, розмір — з масштабу.
## Масштаб по y — це ширина всієї смужки (width_scale), по x — ширина
## разом із заповненням; left_edge — лівий край меша, він не рухається.
const VERTEX_CODE := """
uniform float left_edge = 0.0;

void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	VERTEX = vec3((VERTEX.x - left_edge) * sx + left_edge * sy, VERTEX.y * sy, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
"""
const HEADER := "shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;\n"

const BACK_SHADER := HEADER + VERTEX_CODE + """
uniform float border_x = 0.022;
uniform float border_y = 0.16;

void fragment() {
	bool frame = UV.x < border_x || UV.x > 1.0 - border_x || UV.y < border_y || UV.y > 1.0 - border_y;
	ALBEDO = frame ? vec3(0.02, 0.02, 0.03) : vec3(0.06, 0.06, 0.08);
	ALPHA = 0.92;
}
"""

const FILL_SHADER := HEADER + VERTEX_CODE + """
uniform vec4 fill_color : source_color = vec4(0.95, 0.25, 0.25, 1.0);
uniform float shade = 1.0;

void fragment() {
	// Легкий об'єм: верх світліший за низ (сліду — не треба).
	ALBEDO = fill_color.rgb * mix(mix(1.0, 1.25, shade), mix(1.0, 0.8, shade), UV.y);
	ALPHA = 0.92;
}
"""

static var _back_material: ShaderMaterial
static var _trail_material: ShaderMaterial
static var _fill_materials := {}
static var _back_mesh: QuadMesh
static var _inner_mesh: QuadMesh
static var _fill_shader: Shader

var _back: MeshInstance3D
var _trail_part: MeshInstance3D
var _fill: MeshInstance3D
var _width_scale := 1.0
var _always_visible := false
var _hide_left := 0.0
var _ratio := 1.0
var _trail := 1.0
var _trail_delay := 0.0

func setup(color: Color, height: float, always_visible: bool = false, width_scale: float = 1.0) -> void:
	_always_visible = always_visible
	_width_scale = width_scale
	position.y = height
	_back = _make_part(_get_back_mesh(), _get_back_material())
	_trail_part = _make_part(_get_inner_mesh(), _get_trail_material())
	_fill = _make_part(_get_inner_mesh(), _get_fill_material(color))
	_back.scale = Vector3(width_scale, width_scale, 1.0)
	visible = _always_visible
	_ratio = 1.0
	_trail = 1.0
	_push()
	set_process(false)

## Інший колір смужки (щит голема — жовтий, далі здоров'я — червоне).
func set_color(color: Color) -> void:
	if _fill != null:
		_fill.material_override = _get_fill_material(color)
	_ratio = 1.0
	_trail = 1.0
	_push()

func set_ratio(ratio: float) -> void:
	var new_ratio := clampf(ratio, 0.0, 1.0)
	if is_nan(new_ratio):
		return
	if new_ratio < _ratio:
		# Шкода: слід лишається там, де було здоров'я, і невдовзі сповзає.
		_trail = maxf(_trail, _ratio)
		_trail_delay = TRAIL_DELAY
		set_process(true)
	else:
		_trail = maxf(_trail, new_ratio)
	_ratio = new_ratio
	_push()

func flash() -> void:
	visible = true
	_hide_left = SHOW_TIME
	set_process(true)

func _process(delta: float) -> void:
	var busy := false
	if _trail > _ratio:
		if _trail_delay > 0.0:
			_trail_delay -= delta
		else:
			_trail = maxf(_trail - TRAIL_SPEED * delta, _ratio)
		_push()
		busy = true
	if not _always_visible and _hide_left > 0.0:
		_hide_left -= delta
		if _hide_left <= 0.0:
			visible = false
		else:
			busy = true
	# Нема чого анімувати — не витрачаємо кадри.
	if not busy:
		set_process(false)

func _make_part(mesh: QuadMesh, material: ShaderMaterial) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Поверх моделей і ефектів, щоб смужку не затуляв спалах удару.
	part.sorting_offset = 10.0
	add_child(part)
	return part

## Ширина заповнення й сліду — масштаб по x; порожні шматки ховаємо.
func _push() -> void:
	if _fill == null:
		return
	_place(_fill, _ratio)
	_place(_trail_part, _trail if _trail > _ratio else 0.0)

func _place(part: MeshInstance3D, share: float) -> void:
	part.visible = share > MIN_PART
	if part.visible:
		part.scale = Vector3(_width_scale * share, _width_scale, 1.0)

static func _get_back_mesh() -> QuadMesh:
	if _back_mesh == null:
		_back_mesh = QuadMesh.new()
		_back_mesh.size = Vector2(WIDTH, HEIGHT)
	return _back_mesh

static func _get_inner_mesh() -> QuadMesh:
	if _inner_mesh == null:
		_inner_mesh = QuadMesh.new()
		_inner_mesh.size = Vector2(INNER_WIDTH, INNER_HEIGHT)
	return _inner_mesh

## Тло малюється першим, далі слід, далі заповнення (render_priority).
static func _get_back_material() -> ShaderMaterial:
	if _back_material == null:
		var shader := Shader.new()
		shader.code = BACK_SHADER
		_back_material = ShaderMaterial.new()
		_back_material.shader = shader
		_back_material.set_shader_parameter(&"border_x", BORDER_X)
		_back_material.set_shader_parameter(&"border_y", BORDER_Y)
		_back_material.render_priority = 1
	return _back_material

static func _get_trail_material() -> ShaderMaterial:
	if _trail_material == null:
		_trail_material = _make_fill_material(TRAIL_COLOR, 0.0)
		_trail_material.render_priority = 2
	return _trail_material

static func _get_fill_material(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _fill_materials.has(key):
		var material := _make_fill_material(color, 1.0)
		material.render_priority = 3
		_fill_materials[key] = material
	return _fill_materials[key]

static func _make_fill_material(color: Color, shade: float) -> ShaderMaterial:
	if _fill_shader == null:
		_fill_shader = Shader.new()
		_fill_shader.code = FILL_SHADER
	var material := ShaderMaterial.new()
	material.shader = _fill_shader
	material.set_shader_parameter(&"fill_color", color)
	material.set_shader_parameter(&"shade", shade)
	material.set_shader_parameter(&"left_edge", -INNER_WIDTH * 0.5)
	return material
