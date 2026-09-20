extends RefCounted
class_name WeaponModels

## ТИМЧАСОВІ МОДЕЛІ ЗБРОЇ.
##
## Поки немає справжніх моделей, зброя в руці героя збирається з простих
## фігур: лезо, держак, вістря. Виглядає скромно, зате ГРА ПРАЦЮЄ і
## видно головне — сокира не схожа на глефу, а глефа довша за меч.
##
## Щойно ви покладете файл res://assets/models/weapons/<id зброї>.glb,
## замість заглушки візьметься справжня модель (див. ArtSlots).
##
## Усі фігури зроблені в масштабі метрів і дивляться вперед по -Z, як
## їх тримає рука.

const STEEL := Color(0.78, 0.81, 0.86)
const WOOD := Color(0.35, 0.24, 0.15)

static var _materials: Dictionary = {}

## Збирає зброю за стилем. accent — колір із опису зброї: ним
## підсвічуються камінь у руків'ї та кромка леза, тож кожна зброя
## впізнавана навіть заглушкою.
static func build(style: String, accent: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "WeaponModel"
	match style:
		"axe":
			_add_box(root, Vector3(0.05, 0.9, 0.05), Vector3(0, 0.3, 0), WOOD)
			_add_box(root, Vector3(0.09, 0.34, 0.26), Vector3(0, 0.72, -0.06), STEEL)
			_add_box(root, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.72, 0.1), accent)
		"glaive":
			_add_box(root, Vector3(0.05, 1.7, 0.05), Vector3(0, 0.55, 0), WOOD)
			_add_box(root, Vector3(0.04, 0.5, 0.14), Vector3(0, 1.55, -0.03), STEEL)
			_add_box(root, Vector3(0.08, 0.08, 0.08), Vector3(0, 1.28, 0), accent)
		"twin_blades":
			_add_box(root, Vector3(0.04, 0.62, 0.1), Vector3(0.06, 0.35, 0), STEEL)
			_add_box(root, Vector3(0.04, 0.62, 0.1), Vector3(-0.06, 0.35, 0), STEEL)
			_add_box(root, Vector3(0.16, 0.06, 0.06), Vector3(0, 0.05, 0), accent)
		"pistol":
			_add_box(root, Vector3(0.06, 0.16, 0.06), Vector3(0, 0.05, 0), Color(0.2, 0.2, 0.22))
			_add_box(root, Vector3(0.05, 0.09, 0.26), Vector3(0, 0.17, 0.08), Color(0.28, 0.29, 0.32))
			_add_box(root, Vector3(0.03, 0.03, 0.06), Vector3(0, 0.17, 0.22), accent)
		"rifle":
			_add_box(root, Vector3(0.06, 0.1, 0.8), Vector3(0, 0.2, 0.15), Color(0.24, 0.25, 0.28))
			_add_box(root, Vector3(0.05, 0.16, 0.08), Vector3(0, 0.08, -0.05), Color(0.18, 0.18, 0.2))
			_add_box(root, Vector3(0.03, 0.03, 0.1), Vector3(0, 0.2, 0.58), accent)
		"staff":
			_add_box(root, Vector3(0.05, 1.5, 0.05), Vector3(0, 0.5, 0), WOOD)
			_add_sphere(root, 0.13, Vector3(0, 1.32, 0), accent, true)
		"daggers":
			_add_box(root, Vector3(0.03, 0.38, 0.08), Vector3(0, 0.25, 0), STEEL)
			_add_box(root, Vector3(0.1, 0.05, 0.05), Vector3(0, 0.06, 0), accent)
		_:  # меч
			_add_box(root, Vector3(0.05, 0.9, 0.12), Vector3(0, 0.5, 0), STEEL)
			_add_box(root, Vector3(0.26, 0.05, 0.06), Vector3(0, 0.08, 0), accent)
			_add_box(root, Vector3(0.05, 0.18, 0.05), Vector3(0, -0.04, 0), WOOD)
	return root

static func _add_box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, false)
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

static func _add_sphere(parent: Node3D, radius: float, position: Vector3, color: Color, glowing: bool) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, glowing)
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

## Матеріали спільні для всіх однакових кольорів: телефон малює таку
## зброю разом з іншою, а не окремо.
static func _material(color: Color, glowing: bool) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), glowing]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45 if not glowing else 0.9
	if glowing:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	_materials[key] = material
	return material
