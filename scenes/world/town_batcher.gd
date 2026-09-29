extends RefCounted
class_name TownBatcher

## Місто в редакторі й місто в грі — різні речі.
##
## У РЕДАКТОРІ кожен будинок, дерево чи скеля — звичайний вузол: його
## видно, можна перетягнути мишею, скопіювати, видалити.
##
## У ГРІ такий підхід дорогий: сорок однакових ялинок — сорок окремих
## команд відеокарті, і телефон гальмує. Тому під час запуску гри все,
## що лежить у групах міста, збирається в пакети (MultiMesh): однакові
## моделі малюються однією командою на ділянку.
##
## Для гравця картинка та сама, а для телефона — у рази легше.

## Розмір ділянки пакування в метрах за замовчуванням. Пакети різних
## ділянок відкидаються, коли вони поза кадром, — але кожна ділянка це
## ще одна команда. Місто невелике й видно майже все одразу, тож його
## пакуємо однією ділянкою; ліс і гори довкола — дрібнішими.
const CELL_SIZE := 40.0

## Пакує всі звичайні меші всередині root. Повертає, скільки мешів
## зібрано. Анімовані (зі скелетом) не чіпаємо — їм потрібен свій вузол.
static func batch(root: Node3D, cell_size: float = CELL_SIZE) -> int:
	var batcher := MeshBatcher.new()
	var packed: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		if mesh_instance.skin != null or mesh_instance.has_meta(&"no_batch"):
			continue
		var position := mesh_instance.global_position
		# cell_size <= 0 — усе однією ділянкою.
		var cell := "all" if cell_size <= 0.0 else "%d_%d" % [floori(position.x / cell_size), floori(position.z / cell_size)]
		batcher.add_mesh(mesh_instance.mesh, mesh_instance.material_override, mesh_instance.global_transform, cell)
		packed.append(mesh_instance)

	var holder := Node3D.new()
	holder.name = "Batched"
	root.add_child(holder)
	# Пакети отримують світові координати, тож тримач стоїть у нулі.
	holder.global_transform = Transform3D.IDENTITY
	batcher.flush(holder)
	for mesh_instance in packed:
		mesh_instance.queue_free()
	return packed.size()

## Прості фізичні коробки для будівель — замість точної форми кожного
## меша. Точна форма коштувала процесорові телефона чимало, а гравець
## різниці не відчуває: у будинок і так не зайдеш.
##
## shrink — наскільки зменшити коробку від габаритів моделі (дахи й
## ґанки виступають, і повна коробка не пускала б героя до дверей).
##
## Зони будівель (Area3D) пропускаємо: це не стіни. Раніше напис над
## зоною ставав невидимою брилою посеред неї — і герой, якого після
## екрана будівлі ставили туди, застрягав.
static func add_box_colliders(root: Node3D, body: StaticBody3D, shrink: float = 0.8) -> void:
	for child in root.get_children():
		var object := child as Node3D
		if object == null or object is CollisionObject3D:
			continue
		var bounds := visual_bounds(object)
		if bounds.size.length() < 0.2:
			continue
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(bounds.size.x * shrink, maxf(bounds.size.y, 2.0), bounds.size.z * shrink)
		shape.shape = box
		body.add_child(shape)
		shape.global_position = bounds.get_center()

## Габарити мешів об'єкта у світових координатах. Лише меші: написи,
## частинки й світло мають свої "габарити" (напис-білборд — цілий куб
## навколо себе), а стінами вони не є.
static func visual_bounds(object: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in object.find_children("*", "MeshInstance3D", true, false):
		var visual := node as MeshInstance3D
		var box: AABB = visual.global_transform * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first and object is MeshInstance3D:
		bounds = (object as MeshInstance3D).global_transform * (object as MeshInstance3D).get_aabb()
	return bounds
