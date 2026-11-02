import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:70])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


# --- колайдери: лише меші, зони будівель не тверді ---
edit('scenes/world/town_batcher.gd', [
('''## shrink — наскільки зменшити коробку від габаритів моделі (дахи й
## ґанки виступають, і повна коробка не пускала б героя до дверей).
static func add_box_colliders(root: Node3D, body: StaticBody3D, shrink: float = 0.8) -> void:
	for child in root.get_children():
		var object := child as Node3D
		if object == null:
			continue''', '''## shrink — наскільки зменшити коробку від габаритів моделі (дахи й
## ґанки виступають, і повна коробка не пускала б героя до дверей).
##
## Зони будівель (Area3D) пропускаємо: це не стіни. Раніше напис над
## зоною ставав невидимою брилою посеред неї — і герой, якого після
## екрана будівлі ставили туди, застрягав.
static func add_box_colliders(root: Node3D, body: StaticBody3D, shrink: float = 0.8) -> void:
	for child in root.get_children():
		var object := child as Node3D
		if object == null or object is CollisionObject3D:
			continue'''),
('''## Габарити всього видимого в об'єкті, у світових координатах.
static func visual_bounds(object: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in object.find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		var box: AABB = visual.global_transform * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first and object is VisualInstance3D:
		bounds = (object as VisualInstance3D).global_transform * (object as VisualInstance3D).get_aabb()
	return bounds''', '''## Габарити мешів об'єкта у світових координатах. Лише меші: написи,
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
	return bounds'''),
])

# --- камера: миттєво стати над героєм ---
edit('scenes/world/camera_rig.gd', [
('''func _physics_process(delta: float) -> void:
	if _target == null:
		return''', '''## Миттєво стати над героєм. Коли героя переставили (повернувся з
## будівлі), камера інакше летіла б до нього через усе місто.
func snap_to_target() -> void:
	if _target != null:
		global_position = _target.global_position + Vector3.UP * HEIGHT_OFFSET

func _physics_process(delta: float) -> void:
	if _target == null:
		return'''),
])

# --- місто: повертаємо туди, де герой стояв ---
edit('scenes/world/base_island.gd', [
('''	# Повернулись з екрана будівлі — стоїмо біля її дверей, а не на вході.
	if GameState.town_return_spot != Vector3.INF:
		var spot := GameState.town_return_spot
		player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
		GameState.town_return_spot = Vector3.INF''', '''	# Повернулись з екрана будівлі — стоїмо там, де стояли біля її дверей
	# (а не на вході в місто). Саме там, де стояв герой: центр зони
	# будівлі може бути впритул до стіни.
	if GameState.town_return_spot != Vector3.INF:
		player.global_position = GameState.town_return_spot + Vector3.UP * 0.05
		GameState.town_return_spot = Vector3.INF
		$CameraRig.snap_to_target()'''),
('''		# "Назад" на екрані будівлі поверне героя сюди ж, до її дверей.
		GameState.open_from_town(path, _nearby.global_position)''', '''		# "Назад" на екрані будівлі поверне героя сюди ж, до її дверей.
		GameState.open_from_town(path, player.global_position)'''),
])
print('ok')
