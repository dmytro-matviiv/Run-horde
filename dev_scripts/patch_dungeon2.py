# -*- coding: utf-8 -*-
import os
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:70])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


# --- 1. Масштаб ворогів рахувався по локальних габаритах мешів, а ті в
# --- скелетних моделях майже нульові — звідси роздуття в сотню разів.
patch('scenes/dungeon/enemy_3d.gd', [
    ("""## Масштабує модель так, щоб її висота дорівнювала target_height.
func _normalize_size() -> void:
	var bounds := AABB()
	var first := true
	for child in _model.find_children("*", "VisualInstance3D", true, false):
		var instance := child as VisualInstance3D
		var child_bounds: AABB = instance.transform * instance.get_aabb()
		if first:
			bounds = child_bounds
			first = false
		else:
			bounds = bounds.merge(child_bounds)
	if bounds.size.y <= 0.01:
		return
	_model.scale = Vector3.ONE * (target_height / bounds.size.y)
	# Модель має стояти на підлозі, а не тонути в ній.
	_model.position.y = -bounds.position.y * _model.scale.y""",
     """## Масштабує модель так, щоб її висота дорівнювала target_height.
##
## Габарити рахуємо у СВІТОВИХ координатах і переводимо в систему
## моделі. Локальні габарити тут не годяться: у моделей зі скелетом
## меш лежить у системі кістки, його власний розмір крихітний — і
## масштаб виходив у сотню разів більшим за потрібний.
func _normalize_size() -> void:
	var bounds := _get_model_bounds()
	if bounds.size.y <= 0.01:
		return
	var factor := target_height / bounds.size.y
	# Запобіжник на випадок дивних моделей: краще лишити як є, ніж
	# отримати ворога завбільшки з будинок.
	if factor < 0.01 or factor > 100.0:
		push_warning("Дивний масштаб моделі ворога: %f" % factor)
		return
	_model.scale = Vector3.ONE * factor
	# Модель має стояти на підлозі, а не тонути в ній.
	_model.position.y = -bounds.position.y * factor

func _get_model_bounds() -> AABB:
	var to_local := _model.global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for child in _model.find_children("*", "VisualInstance3D", true, false):
		var instance := child as VisualInstance3D
		var child_bounds: AABB = to_local * (instance.global_transform * instance.get_aabb())
		if first:
			bounds = child_bounds
			first = false
		else:
			bounds = bounds.merge(child_bounds)
	return bounds"""),
    # Ближній бій теж має бачити ціль: інакше ворог лупить крізь стіну.
    ("""func _try_attack() -> void:
	if _attack_left > 0.0:
		return""",
     """func _try_attack() -> void:
	if _attack_left > 0.0:
		return
	# Б'ємо лише те, що бачимо: інакше ворог дістає героя крізь стіну,
	# просто стоячи впритул з іншого боку.
	if not _has_line_of_sight():
		return"""),
    ("""@export var aggro_range := 14.0""",
     """@export var aggro_range := 11.0"""),
])

# --- 2. Смерть героя більше не "застрягання": показуємо екран і
# --- повертаємо на базу.
patch('scenes/dungeon/dungeon.gd', [
    ("""	_spawn_enemies(markers)
	_setup_hud(level.title)""",
     """	_spawn_enemies(markers)
	_setup_hud(level.title)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)"""),
    ("""func _on_joystick_moved(direction: Vector2) -> void:""",
     """## Герой загинув — це має бути видно, а не виглядати як "застряг".
func _on_player_died() -> void:
	status_label.text = "Ви загинули. Повертаємось на базу…"
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/world/base_island.tscn")

func _on_player_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HP %d / %d" % [int(current), int(maximum)]

func _on_joystick_moved(direction: Vector2) -> void:"""),
    ("""@onready var status_label: Label = $HUD/StatusLabel""",
     """@onready var status_label: Label = $HUD/StatusLabel
@onready var health_label: Label = $HUD/HealthLabel"""),
])

# --- 3. Підлога однією плитою замість сотні плиток: герой більше не
# --- чіпляється за стики.
patch('scenes/dungeon/dungeon_builder.gd', [
    ("""static func _add_floor(parent: Node3D, position: Vector3) -> void:
	var tile: Node3D = FLOOR_SCENE.instantiate()
	tile.position = position
	parent.add_child(tile)
	_add_box_collision(tile, Vector3(CELL, 0.25, CELL), Vector3.ZERO)""",
     """## Підлогу малюємо плитками, а фізику для неї робимо суцільною плитою
## на весь рівень (див. _add_floor_collision). Сто окремих коробок
## давали стики, на яких герой чіплявся й "застрягав на рівному місці".
static func _add_floor(parent: Node3D, position: Vector3) -> void:
	var tile: Node3D = FLOOR_SCENE.instantiate()
	tile.position = position
	parent.add_child(tile)

## Одна велика плита під усім рівнем: рівно на висоті плиток, без
## жодного шва.
static func _add_floor_collision(parent: Node3D, map_rows: Array) -> void:
	var width := float(map_rows[0].length()) * CELL
	var depth := float(map_rows.size()) * CELL
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width + CELL, 0.5, depth + CELL)
	shape.shape = box
	shape.position = Vector3(width * 0.5 - CELL * 0.5, -0.125, depth * 0.5 - CELL * 0.5)
	body.add_child(shape)
	parent.add_child(body)"""),
    ("""	_add_columns(parent, map_rows)
	return result""",
     """	_add_floor_collision(parent, map_rows)
	_add_columns(parent, map_rows)
	_decorate(parent, map_rows)
	return result"""),
])
print('done')
