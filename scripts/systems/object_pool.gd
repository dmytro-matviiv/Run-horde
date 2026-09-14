extends RefCounted
class_name ObjectPool

## Пул об'єктів: перевикористовує вже створені інстанси сцени замість
## того, щоб instantiate()/queue_free() їх щокадру. На 5-й хвилині рану
## на екрані живе 200+ ворогів і снарядів одночасно — без пулу постійне
## створення й видалення нод просадить FPS на телефоні.
##
## Контракт: сцена, яку кладуть у пул, повинна мати методи
## set_pool(pool), pool_activate() і pool_deactivate().

var _scene: PackedScene
var _parent: Node
var _available: Array[Node] = []

func _init(scene: PackedScene, parent: Node, preload_count: int = 0) -> void:
	_scene = scene
	_parent = parent
	for i in preload_count:
		_available.append(_create_instance())

func _create_instance() -> Node:
	var instance: Node = _scene.instantiate()
	_parent.add_child(instance)
	instance.set_pool(self)
	instance.pool_deactivate()
	return instance

## Дістає готовий до використання інстанс із пулу (або створює новий,
## якщо вільних не залишилось).
func acquire() -> Node:
	var instance: Node = _available.pop_back() if not _available.is_empty() else _create_instance()
	instance.pool_activate()
	return instance

## Повертає інстанс у пул замість того, щоб знищувати його.
func release(instance: Node) -> void:
	instance.pool_deactivate()
	_available.append(instance)
