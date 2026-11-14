extends RefCounted
class_name HavenLite

## ЛЕГКІ МАТЕРІАЛИ для низької якості (слабкий телефон). Нерухому
## архітектуру й природу Прихистку полегшує будівник заздалегідь
## (haven_lite.tscn). А для окремих моделей, що лишаються вузлами (дерева
## на зруб, каміння, трави), легкий матеріал робиться тут, на ходу: копія
## рідного без карт нерівностей і блиску, з освітленням у вершинах.
## Колір і малюнок ті самі — з висоти камери різниці не видно, а
## відеочипу рахувати в рази менше.

static var _cache := {}

static func material(source: Material) -> Material:
	var base := source as BaseMaterial3D
	if base == null:
		return source
	var id := base.get_instance_id()
	if _cache.has(id) and is_instance_valid(_cache[id]):
		return _cache[id]
	var lite := base.duplicate() as BaseMaterial3D
	lite.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	lite.normal_enabled = false
	lite.normal_texture = null
	lite.roughness_texture = null
	lite.metallic_texture = null
	lite.ao_enabled = false
	lite.ao_texture = null
	lite.heightmap_enabled = false
	lite.roughness = 0.9
	lite.metallic = 0.0
	lite.metallic_specular = 0.3
	_cache[id] = lite
	return lite

## Увімкнути/вимкнути легкі матеріали на всіх мешах вузла.
static func apply(root: Node, enabled: bool) -> void:
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var visual := node as MeshInstance3D
		if visual.mesh == null:
			continue
		for surface in visual.mesh.get_surface_count():
			if enabled:
				visual.set_surface_override_material(surface, material(visual.mesh.surface_get_material(surface)))
			else:
				visual.set_surface_override_material(surface, null)
