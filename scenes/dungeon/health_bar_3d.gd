extends Node3D
class_name HealthBar3D

## Смужка здоров'я над головою. Один компонент на всіх: ворогам вішаємо
## червону, дружнім NPC — зелену, і поводяться вони трохи по-різному.
##
## Ворожа смужка з'являється лише тоді, коли по цілі почали бити, і сама
## зникає, якщо бій припинився: інакше данж перетворюється на купу
## смужок, що висять над кожним кутом.
##
## Дружня видима завжди — по NPC ніхто не б'є, а знати його стан корисно.
##
## Малюємо двома площинами (тло і заповнення) без освітлення й завжди
## обличчям до камери. Заповнення зменшується ВІД ЛІВОГО КРАЮ, а не від
## центру, тож смужка спадає звично.

const WIDTH := 1.0
const HEIGHT := 0.13
const BACKGROUND_COLOR := Color(0.05, 0.05, 0.07, 0.75)

## Скільки смужка ворога лишається на екрані після останнього удару.
const SHOW_TIME := 4.0

## Матеріали спільні для всіх смужок одного кольору: двадцять ворогів —
## два матеріали, а не сорок. Відеокарта малює однакове разом.
static var _materials: Dictionary = {}

var _background: MeshInstance3D
var _fill: MeshInstance3D
var _always_visible := false
var _hide_left := 0.0
var _ratio := 1.0

## color — колір заповнення; height — на якій висоті висіти;
## always_visible — true для дружніх NPC, false для ворогів.
func setup(color: Color, height: float, always_visible: bool = false, width_scale: float = 1.0) -> void:
	_always_visible = always_visible
	position.y = height
	_background = _make_quad(BACKGROUND_COLOR, WIDTH * width_scale, HEIGHT)
	_fill = _make_quad(color, WIDTH * width_scale, HEIGHT * 0.78)
	add_child(_background)
	add_child(_fill)
	# Заповнення трохи ближче до камери, щоб не блимало крізь тло.
	_fill.position.z = 0.01
	visible = _always_visible
	# Таймер зникнення потрібен лише після удару.
	set_process(false)
	set_ratio(1.0)

func _make_quad(color: Color, width: float, height: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)

	var instance := MeshInstance3D.new()
	instance.mesh = quad
	instance.material_override = _get_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

## Частка здоров'я від 0 до 1.
static func _get_material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = 1
	_materials[color] = material
	return material

func set_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	if _fill == null:
		return
	var full_width: float = (_background.mesh as QuadMesh).size.x
	_fill.scale.x = maxf(_ratio, 0.001)
	# Зсуваємо вліво рівно на стільки, на скільки звузились: лівий край
	# смужки лишається на місці, спадає правий.
	_fill.position.x = -full_width * (1.0 - _ratio) * 0.5

## Показати смужку (ворога вдарили).
func flash() -> void:
	visible = true
	_hide_left = SHOW_TIME
	set_process(not _always_visible)

func _process(delta: float) -> void:
	if _always_visible or _hide_left <= 0.0:
		return
	_hide_left -= delta
	if _hide_left <= 0.0:
		visible = false
		set_process(false)
