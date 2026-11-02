import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:70])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


# --- темна скеля навколо залів ---
edit('scenes/dungeon/dungeon_builder.gd', [
('''const CELL := 2.0          # розмір клітинки в метрах
const WALL_HEIGHT := 2.0
''', '''const CELL := 2.0          # розмір клітинки в метрах
const WALL_HEIGHT := 2.0

## Верх скелі навколо залів — трохи нижче за верх стін, щоб гребінь стіни
## лишався видно й кімната читалась вирубаною в камені.
const ROCK_TOP_HEIGHT := WALL_HEIGHT - 0.03
## На скільки клітинок скеля виходить за край карти: край рівня теж не
## має виглядати проваллям.
const ROCK_MARGIN := 12
## Скільки метрів займає один повтор текстури каменю.
const ROCK_TEXTURE_METERS := 7.0
const ROCK_TEXTURE := preload("res://assets/textures/rock_top.png")
## Колір верху скелі до відтінку теми: темний, як камінь у тіні.
const ROCK_COLOR := Color(0.2, 0.19, 0.18)
'''),
('''	_add_merged_walls(obstacles, wall_runs)
	_add_floor_collision(obstacles, map_rows)
	_add_column_obstacles(obstacles, map_rows)
	_create_chunks(parent, map_rows, result)
	return result
''', '''	_add_merged_walls(obstacles, wall_runs)
	_add_floor_collision(obstacles, map_rows)
	_add_column_obstacles(obstacles, map_rows)
	_create_chunks(parent, map_rows, result)
	_add_rock_top(parent, map_rows, theme)
	return result

## ТЕМНА СКЕЛЯ НАВКОЛО ЗАЛІВ
##
## Камера дивиться на данж згори, а стіни — по пояс. Раніше за ними була
## порожнеча: чорні провалля між залами, що різали око. Тепер над кожною
## непрохідною клітинкою (і ще трохи за краєм карти) лежить темний камінь
## на висоті верху стін — зали читаються як вирубані в скелі.
##
## Це ОДИН меш на весь рівень і один виклик малювання. Камінь не
## освітлюється (unshaded): смолоскипам не треба його рахувати, а далеке
## однаково ховає туман.
static func _add_rock_top(parent: Node3D, map_rows: Array, theme: Dictionary) -> void:
	var width := 0
	for row: String in map_rows:
		width = maxi(width, row.length())
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-ROCK_MARGIN, map_rows.size() + ROCK_MARGIN):
		# Суцільні відрізки рядка зливаються в одну смугу — вершин менше.
		var run_start := -1
		for x in range(-ROCK_MARGIN, width + ROCK_MARGIN + 1):
			var solid := x < width + ROCK_MARGIN and not _is_walkable(map_rows, x, z)
			if solid and run_start == -1:
				run_start = x
			elif not solid and run_start != -1:
				_add_rock_strip(surface, run_start, x - 1, z)
				run_start = -1
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = ROCK_TEXTURE
	material.albedo_color = ROCK_COLOR * theme.get("stone", Color.WHITE)
	# Згори видно лише один бік, але так не залежимо від порядку вершин.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rock := MeshInstance3D.new()
	rock.name = "RockTop"
	rock.mesh = mesh
	rock.material_override = material
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rock)

## Смуга скелі над клітинками first..last одного рядка. Текстура
## прив'язана до світу, а не до смуги: шви між смугами не видно.
static func _add_rock_strip(surface: SurfaceTool, first: int, last: int, z: int) -> void:
	var half := CELL * 0.5
	var left := first * CELL - half
	var right := last * CELL + half
	var top := z * CELL - half
	var bottom := z * CELL + half
	var corners := [
		Vector3(left, ROCK_TOP_HEIGHT, top), Vector3(right, ROCK_TOP_HEIGHT, top),
		Vector3(right, ROCK_TOP_HEIGHT, bottom), Vector3(left, ROCK_TOP_HEIGHT, bottom),
	]
	for index: int in [0, 1, 2, 0, 2, 3]:
		var corner: Vector3 = corners[index]
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(corner.x, corner.z) / ROCK_TEXTURE_METERS)
		surface.add_vertex(corner)
'''),
])

# --- камера: межі нахилу ---
edit('scenes/world/camera_rig.gd', [
('''## Нахил камери вгору-вниз тим самим пальцем.
func pitch_by(amount: float) -> void:''', '''## Межі нахилу й початковий нахил — для місць, де потрібен свій кут
## (у данжі камера дивиться круто згори).
func set_pitch_limits(min_degrees: float, max_degrees: float, start_degrees: float) -> void:
	min_pitch_degrees = min_degrees
	max_pitch_degrees = max_degrees
	_pitch = deg_to_rad(clampf(start_degrees, min_degrees, max_degrees))
	spring_arm.rotation.x = _pitch

## Нахил камери вгору-вниз тим самим пальцем.
func pitch_by(amount: float) -> void:'''),
])

# --- данж: крута камера ---
edit('scenes/dungeon/dungeon.gd', [
('''## Скільки досвіду треба на наступний рівень героя в данжі.
const XP_PER_LEVEL := 12
''', '''## Скільки досвіду треба на наступний рівень героя в данжі.
const XP_PER_LEVEL := 12

## КАМЕРА. У данжі вона дивиться круто згори і не нахиляється пологіше
## за CAMERA_MAX_PITCH: з пологого кута було видно горизонт, далекі зали
## й темряву між ними. Гравцеві потрібна його зала, а не весь рівень.
const CAMERA_PITCH := -54.0
const CAMERA_MIN_PITCH := -66.0
const CAMERA_MAX_PITCH := -46.0
'''),
('''	camera_touch.rotate_requested.connect($CameraRig.rotate_by)
	camera_touch.pitch_requested.connect($CameraRig.pitch_by)
	camera_touch.tap_attack.connect(player.attack)''', '''	$CameraRig.set_pitch_limits(CAMERA_MIN_PITCH, CAMERA_MAX_PITCH, CAMERA_PITCH)
	camera_touch.rotate_requested.connect($CameraRig.rotate_by)
	camera_touch.pitch_requested.connect($CameraRig.pitch_by)
	camera_touch.tap_attack.connect(player.attack)'''),
])
print('ok')
