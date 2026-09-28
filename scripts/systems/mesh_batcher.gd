@tool
extends RefCounted
class_name MeshBatcher

## Збирає однакові моделі в один об'єкт малювання (MultiMesh).
##
## Навіщо: данж складається з сотень однакових шматків — плиток підлоги,
## стін, бочок. Якщо кожен шматок окремий вузол, відеокарта отримує
## сотні команд на кадр, а процесор щокадру обходить тисячі вузлів. На
## комп'ютері це непомітно, телефон від такого лагає.
##
## З пакетуванням усі 400 плиток підлоги малюються ОДНІЄЮ командою: у
## відеокарти є одна модель і список місць, де її поставити.
##
## Користування:
##   var batcher := MeshBatcher.new()
##   batcher.add(scene, transform)   # скільки завгодно разів
##   batcher.flush(parent)           # створює готові вузли

## Витягнуті з кожної сцени меші: PackedScene -> [{mesh, material, transform}]
var _scene_parts: Dictionary = {}

## Відтінок для всіх мешів пакета. Так кожен данж має свій колір каменю
## (зеленуваті печери, синя цитадель) з тих самих моделей — і без жодної
## додаткової ціни для відеокарти: пофарбовані копії мешів робляться
## один раз на рівень.
var tint := Color.WHITE

static var _tinted_meshes: Dictionary = {}

## Зібрані розміщення: ключ (меш + матеріал) -> {mesh, material, transforms}
var _batches: Dictionary = {}

## Додає одну модель у заданому місці. color — відтінок саме цієї
## моделі (стіни й підлога в кожного рівня свого кольору); білий — без
## зміни, тоді діє загальний tint.
func add(scene: PackedScene, transform: Transform3D, color: Color = Color.WHITE) -> void:
	var paint := color if color != Color.WHITE else tint
	for part: Dictionary in _get_parts(scene):
		var key := "%s|%s|%s" % [part.mesh.get_rid(), part.material.get_rid() if part.material else "-", paint.to_html()]
		if not _batches.has(key):
			_batches[key] = {
				"mesh": part.mesh,
				"material": part.material,
				"lod_scale": part.lod_scale,
				"tint": paint,
				"transforms": [],
			}
		_batches[key].transforms.append(transform * part.transform)

## Додає вже готовий меш (не сцену) — так місто пакує моделі, які
## розставлені в редакторі звичайними вузлами. cell — ключ ділянки:
## пакети різних ділянок малюються окремо, тож відеокарта може
## відкинути ті, що не потрапили в кадр.
func add_mesh(mesh: Mesh, material: Material, transform: Transform3D, cell: String = "") -> void:
	var key := "%s|%s|%s" % [mesh.get_rid(), material.get_rid() if material else "-", cell]
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "material": material, "lod_scale": 1.0, "transforms": []}
	var scale := transform.basis.get_scale()
	_batches[key].lod_scale = maxf(_batches[key].lod_scale, maxf(scale.x, maxf(scale.y, scale.z)))
	_batches[key].transforms.append(transform)

## Створює вузли малювання. Після цього пакетувальник можна викидати.
func flush(parent: Node3D) -> void:
	for key in _batches:
		var batch: Dictionary = _batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		var paint: Color = batch.get("tint", tint)
		multimesh.mesh = batch.mesh if paint == Color.WHITE else _tinted(batch.mesh, paint)
		multimesh.instance_count = batch.transforms.size()
		for i in batch.transforms.size():
			multimesh.set_instance_transform(i, batch.transforms[i])

		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		# Рушій вирішує, наскільки спростити модель (LOD), за масштабом
		# ВУЗЛА. У пакета вузол має масштаб 1, а моделі набору зроблені в
		# сантиметрах і збільшені всередині в сто разів. Без цієї поправки
		# рушій вважав стіну крихітною, брав найгрубшу версію сітки — і
		# від стін лишались уламки з дірами.
		instance.lod_bias = batch.lod_scale
		if batch.material != null:
			instance.material_override = batch.material
		# Тіні від дрібниць на телефоні коштують дорого, а видно їх ледве.
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	_batches.clear()

## Копія меша з перефарбованими матеріалами. Кешується: у данжі сотні
## шматків стін, а копія на кожен колір потрібна лише одна.
static func _tinted(mesh: Mesh, color: Color) -> Mesh:
	var key := "%s|%s" % [mesh.get_rid(), color.to_html()]
	if _tinted_meshes.has(key):
		return _tinted_meshes[key]
	var copy: Mesh = mesh.duplicate()
	for surface in copy.get_surface_count():
		var source := mesh.surface_get_material(surface) as StandardMaterial3D
		if source == null:
			continue
		var material: StandardMaterial3D = source.duplicate()
		material.albedo_color = source.albedo_color * color
		copy.surface_set_material(surface, material)
	_tinted_meshes[key] = copy
	return copy

## Розбирає сцену на меші один раз і запам'ятовує: далі та сама модель
## додається без повторного створення вузлів.
func _get_parts(scene: PackedScene) -> Array:
	if _scene_parts.has(scene):
		return _scene_parts[scene]

	var parts: Array = []
	var root: Node3D = scene.instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var relative := _relative_transform(mesh_instance, root)
		var scale := relative.basis.get_scale()
		parts.append({
			"mesh": mesh_instance.mesh,
			"material": mesh_instance.material_override,
			"transform": relative,
			"lod_scale": maxf(scale.x, maxf(scale.y, scale.z)),
		})
	root.free()
	_scene_parts[scene] = parts
	return parts

## Положення меша відносно кореня сцени: перемножуємо локальні
## перетворення вгору по дереву.
func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
