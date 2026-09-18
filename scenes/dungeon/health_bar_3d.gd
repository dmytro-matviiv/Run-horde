extends Node3D
class_name HealthBar3D

## Смужка здоров'я над головою: червона у ворогів, зелена у своїх.
##
## ЧОМУ ШЕЙДЕР. Попередня версія зменшувала заповнення масштабом, але
## смужка повернута до камери (білборд), а в такому режимі рушій масштаб
## ігнорує — заповнення завжди лишалось повним, і здавалось, що шкода не
## знімається. Тепер уся смужка — один прямокутник, а шейдер сам малює:
##   - заповнення до поточного здоров'я;
##   - світлий "слід" щойно втраченого здоров'я, який сповзає з
##     запізненням — так видно, скільки зняв останній удар;
##   - темне тло й рамку.
## Колір і частки передаються параметрами екземпляра, тож матеріал
## один на всіх: двадцять ворогів — один матеріал.
##
## Ворожа смужка з'являється від першого удару й ховається через кілька
## секунд спокою; своя видима завжди.

const WIDTH := 1.0
const HEIGHT := 0.13

## Скільки секунд ворожа смужка лишається видимою після удару.
const SHOW_TIME := 4.0
## Пауза перед тим, як слід почне сповзати, і швидкість сповзання.
const TRAIL_DELAY := 0.35
const TRAIL_SPEED := 0.9

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 fill_color : source_color = vec4(0.95, 0.25, 0.25, 1.0);
instance uniform float ratio = 1.0;
instance uniform float trail = 1.0;

void vertex() {
	// Завжди обличчям до камери, але зі збереженням розміру.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
}

void fragment() {
	float border_x = 0.022;
	float border_y = 0.16;
	bool frame = UV.x < border_x || UV.x > 1.0 - border_x || UV.y < border_y || UV.y > 1.0 - border_y;
	float x = (UV.x - border_x) / (1.0 - 2.0 * border_x);
	vec3 back = vec3(0.06, 0.06, 0.08);
	vec3 color = back;
	if (x <= ratio) {
		// Легкий об'єм: верх світліший за низ.
		color = fill_color.rgb * mix(1.25, 0.8, UV.y);
	} else if (x <= trail) {
		color = vec3(1.0, 0.92, 0.7);
	}
	if (frame) {
		color = vec3(0.02, 0.02, 0.03);
	}
	ALBEDO = color;
	ALPHA = 0.92;
}
"""

static var _material: ShaderMaterial
static var _mesh: QuadMesh

var _bar: MeshInstance3D
var _always_visible := false
var _hide_left := 0.0
var _ratio := 1.0
var _trail := 1.0
var _trail_delay := 0.0

func setup(color: Color, height: float, always_visible: bool = false, width_scale: float = 1.0) -> void:
	_always_visible = always_visible
	position.y = height
	_bar = MeshInstance3D.new()
	_bar.mesh = _get_mesh()
	_bar.material_override = _get_material()
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.scale = Vector3(width_scale, width_scale, 1.0)
	# Поверх моделей і ефектів, щоб смужку не затуляв спалах удару.
	_bar.sorting_offset = 10.0
	add_child(_bar)
	_bar.set_instance_shader_parameter(&"fill_color", color)
	visible = _always_visible
	set_ratio(1.0)
	_trail = 1.0
	_push()
	set_process(false)

func set_ratio(ratio: float) -> void:
	var new_ratio := clampf(ratio, 0.0, 1.0)
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

func _push() -> void:
	if _bar == null:
		return
	_bar.set_instance_shader_parameter(&"ratio", _ratio)
	_bar.set_instance_shader_parameter(&"trail", _trail)

static func _get_mesh() -> QuadMesh:
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2(WIDTH, HEIGHT)
	return _mesh

static func _get_material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material
