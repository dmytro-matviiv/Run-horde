extends RefCounted
class_name HavenLayout

## ПЛАН ПРИХИСТКУ — усі розміри в одному місці (метри; X — схід, Z — південь,
## камера дивиться на північ, тобто в -Z). Будівник (haven_builder.gd) і
## рельєф беруть цифри звідси, тож зсунути терасу чи сходи — правка тут.
##
##   південь  — галявина появи героя (висота 0), стежка до сходів;
##   центр    — НИЖНЯ ТЕРАСА (висота 2): площа з бруківкою, п'ятеро NPC,
##              будиночки; сходи на південь, схід (гай) і захід (пагорб);
##   північ   — ВЕРХНЯ ТЕРАСА (висота 4): портал, сходи з площі;
##   схід     — гай (дерева на зруб);
##   захід    — кам'янистий пагорб (камінь, трави, гриби);
##   довкола  — пагорби й ліс: краю світу не видно.

const SIZE := 160.0          # бік квадрата рельєфу
const STEP := 1.0            # крок сітки рельєфу

const LOW_TERRACE := Rect2(-22.0, -32.0, 44.0, 46.0)   # x, z, ширина, глибина
const LOW_HEIGHT := 2.0
const HIGH_TERRACE := Rect2(-9.0, -30.0, 18.0, 16.0)   # край на z = -14
const HIGH_HEIGHT := 4.0
## Площа з бруківкою на нижній терасі.
const PLAZA := Rect2(-10.0, -6.0, 20.0, 16.0)

## Сходи: [центр x, центр z, напрямок спуску (вектор XZ), висота верху, ширина].
## Кожен марш — дві деталі по 2 м (підйом 1 м кожна).
const STAIRS := [
	[0.0, 14.0, Vector2(0, 1), 2.0, 4.0],      # з площі на південь, до галявини
	[22.0, 0.0, Vector2(1, 0), 2.0, 4.0],      # на схід, до гаю
	[-22.0, 0.0, Vector2(-1, 0), 2.0, 4.0],    # на захід, до пагорба
	[0.0, -14.0, Vector2(0, 1), 4.0, 4.0],     # з площі вгору до порталу
]

## Чаша: за цим еліпсом земля здіймається пагорбами.
const BOWL_RADIUS := Vector2(58.0, 60.0)
const BOWL_CENTER := Vector2(0.0, 2.0)
## Західний пагорб (камінь і трави) — плавний горб.
const WEST_HILL := [Vector2(-40.0, 4.0), Vector2(11.0, 15.0), 1.8]

const SPAWN := Vector3(0.0, 0.0, 34.0)
const PORTAL := Vector3(0.0, HIGH_HEIGHT, -24.0)

## Місця NPC (на площі, висота нижньої тераси) і куди вони дивляться (кут
## навколо Y; 0 — на південь, до камери).
const NPCS := {
	&"elder": [Vector3(0.0, LOW_HEIGHT, 7.6), 0.0],
	&"mentor": [Vector3(-12.5, LOW_HEIGHT, 4.0), 0.9],
	&"smith": [Vector3(12.5, LOW_HEIGHT, 4.0), -0.9],
	&"sage": [Vector3(-12.5, LOW_HEIGHT, -12.0), 0.7],
	&"merchant": [Vector3(12.5, LOW_HEIGHT, -12.0), -0.7],
}
## Центр площі: клумба з великим деревом.
const PLAZA_TREE := Vector3(0.0, LOW_HEIGHT, 2.0)
const PLAZA_TREE_RADIUS := 3.2

## Стежки (ламані) для маски ґрунту.
const PATHS := [
	[Vector2(0, 50), Vector2(0, 40), Vector2(-2, 30), Vector2(0, 22), Vector2(0, 18)],
	[Vector2(26, 0), Vector2(32, 3), Vector2(38, 8), Vector2(42, 16)],
	[Vector2(-26, 0), Vector2(-32, -2), Vector2(-38, 2), Vector2(-42, 10)],
	[Vector2(0, 14), Vector2(0, 11)],
]

# --- рельєф ---

static func height(x: float, z: float) -> float:
	var h := _bowl(x, z) + _bumps(x, z)
	var hill: Array = WEST_HILL
	var c: Vector2 = hill[0]
	var r: Vector2 = hill[1]
	var d := Vector2((x - c.x) / r.x, (z - c.y) / r.y).length()
	h = maxf(h, float(hill[2]) * (1.0 - smoothstep(0.35, 1.0, d)) + _bumps(x, z))
	h = maxf(h, _terrace(x, z, LOW_TERRACE, LOW_HEIGHT))
	h = maxf(h, _terrace(x, z, HIGH_TERRACE, HIGH_HEIGHT))
	for s: Array in STAIRS:
		h = maxf(h, _ramp(x, z, s))
	return h

## Чаша довкола: рівно в середині, за краєм — пагорби вгору.
static func _bowl(x: float, z: float) -> float:
	var p := Vector2((x - BOWL_CENTER.x) / BOWL_RADIUS.x, (z - BOWL_CENTER.y) / BOWL_RADIUS.y)
	var a := atan2(p.y, p.x)
	var wobble := 1.0 + 0.08 * sin(a * 3.0 + 0.7) + 0.05 * sin(a * 7.0 + 2.1)
	var e := p.length() * wobble
	if e <= 1.0:
		return 0.0
	return minf(pow((e - 1.0) * 3.2, 1.4) * 9.0, 22.0)

## Легкі горбики на траві (не на терасах — там рівно).
static func _bumps(x: float, z: float) -> float:
	return 0.18 * sin(x * 0.21 + z * 0.13) + 0.14 * sin(x * 0.07 - z * 0.19 + 1.3) \
		+ 0.1 * sin(x * 0.43 + 2.0) * sin(z * 0.37)

## Тераса: рівний верх, по краю — крутий схил 0.8 м (його ховає стіна).
static func _terrace(x: float, z: float, rect: Rect2, top: float) -> float:
	var dx := maxf(rect.position.x - x, x - rect.end.x)
	var dz := maxf(rect.position.y - z, z - rect.end.y)
	var d := maxf(dx, dz)
	return top * (1.0 - smoothstep(0.0, 0.8, d))

## Пандус під сходами: від висоти верху до верх-2 на 4 м спуску.
static func _ramp(x: float, z: float, stair: Array) -> float:
	var center := Vector2(stair[0], stair[1])
	var dir: Vector2 = stair[2]
	var top: float = stair[3]
	var width: float = stair[4]
	var rel := Vector2(x, z) - center
	var along := rel.dot(dir)          # 0 — початок спуску, +4 — низ
	var side := absf(rel.dot(Vector2(-dir.y, dir.x)))
	if side > width * 0.5 + 0.3 or along < -0.2 or along > 4.2:
		return 0.0
	return top - 2.0 * clampf(along / 4.0, 0.0, 1.0)

# --- маски для шейдера землі (колір вершини) ---

## r — стежка, g — камінь, b — тінь.
static func mask(x: float, z: float, h: float) -> Color:
	var path := 0.0
	for line: Array in PATHS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var d := Geometry2D.get_closest_point_to_segment(Vector2(x, z), a, b).distance_to(Vector2(x, z))
			path = maxf(path, 1.0 - smoothstep(1.0, 2.2, d))
	var rock := 0.0
	if h > 3.0 and not _inside(x, z, LOW_TERRACE, 0.5):
		rock = clampf((h - 3.0) / 6.0, 0.0, 1.0) * (0.5 + 0.5 * sin(x * 0.3) * sin(z * 0.27))
	var hill: Array = WEST_HILL
	var hd := Vector2((x - hill[0].x) / hill[1].x, (z - hill[0].y) / hill[1].y).length()
	rock = maxf(rock, (1.0 - smoothstep(0.2, 0.75, hd)) * 0.55)
	# Тінь біля підніжжя терас.
	var shade := 0.0
	for rect: Rect2 in [LOW_TERRACE, HIGH_TERRACE]:
		var dx := maxf(rect.position.x - x, x - rect.end.x)
		var dz := maxf(rect.position.y - z, z - rect.end.y)
		var d := maxf(dx, dz)
		if d > 0.0:
			shade = maxf(shade, 1.0 - smoothstep(0.6, 2.6, d))
	return Color(path, rock, shade * 0.8)

static func _inside(x: float, z: float, rect: Rect2, margin: float) -> bool:
	return x > rect.position.x - margin and x < rect.end.x + margin and z > rect.position.y - margin and z < rect.end.y + margin
