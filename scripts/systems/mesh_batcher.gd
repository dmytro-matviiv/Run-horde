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

## Зібрані розміщення: ключ (меш + матеріал) -> {mesh, material, transforms}
var _batches: Dictionary = {}

## Додає одну модель у заданому місці.
func add(scene: PackedScene, transform: Transform3D) -> void:
	for part: Dictionary in _get_parts(scene):
		var key := "%s|%s" % [part.mesh.get_rid(), part.material.get_rid() if part.material else "-"]
		if not _batches.has(key):
			_batches[key] = {"mesh": part.mesh, "material": part.material, "transforms": []}
		_batches[key].transforms.append(transform * part.transform)

## Створює вузли малювання. Після цього пакетувальник можна викидати.
func flush(parent: Node3D) -> void:
	for key in _batches:
		var batch: Dictionary = _batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = batch.mesh
		multimesh.instance_count = batch.transforms.size()
		for i in batch.transforms.size():
			multimesh.set_instance_transform(i, batch.transforms[i])

		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		if batch.material != null:
			instance.material_override = batch.material
		# Тіні від дрібниць на телефоні коштують дорого, а видно їх ледве.
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	_batches.clear()

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
		parts.append({
			"mesh": mesh_instance.mesh,
			"material": mesh_instance.material_override,
			"transform": _relative_transform(mesh_instance, root),
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
