extends RefCounted
class_name HavenLayout

## ПЛАН МІСТА ПРИХИСТОК — середньовічне містечко (метри; X — схід,
## Z — південь; камера дивиться на північ, тобто в -Z). Будівник
## (dev_scripts/town/town_builder.gd) і гра беруть цифри звідси.
##
##   південь — дорога з полів і міська брама з двома вежами;
##   вулиця  — від брами на північ: дім героя, таверна «Золотий Кабан»;
##   центр   — Ринкова площа з фонтаном: ратуша (Старійшина Остап) на
##             півночі, ринок (Торговка Олеся) на сході, тренувальний
##             двір (Наставниця Дарина) на заході;
##   схід    — вулиця Ковалів: кузня Богдана;
##   північний захід — вежа-бібліотека Мудреця Велимира;
##   північ  — стара каплиця й вхід до склепів (портал у данжі);
##   довкола — поля, кам'яний вітряк, ліс і пагорби.

const SIZE := 200.0          # бік квадрата рельєфу
const STEP := 1.0

## Місто рівне (висота 0); за еліпсом — пагорби.
const BOWL_RADIUS := Vector2(66.0, 72.0)
const BOWL_CENTER := Vector2(0.0, -2.0)

const SPAWN := Vector3(0.0, 0.0, 54.0)
const GATE := Vector3(0.0, 0.0, 40.0)
const SQUARE := Rect2(-16.0, -16.0, 32.0, 28.0)          # x, z, ширина, глибина
const MAIN_STREET := Rect2(-3.5, 12.0, 7.0, 30.0)
const SMITH_STREET := Rect2(16.0, -5.5, 14.0, 7.0)
const NORTH_LANE := Rect2(-3.0, -40.0, 6.0, 24.0)
const FOUNTAIN := Vector3(0.0, 0.0, -1.0)
const FOUNTAIN_RADIUS := 3.4

const PORTAL := Vector3(0.0, 0.0, -42.0)
const PORTAL_ARCH_SCALE := 1.75
const PORTAL_FIRE_X := 3.6

## NPC: [місце, кут (0 — обличчям на південь, до камери)].
const NPCS := {
	&"elder": [Vector3(0.0, 0.0, -11.5), 0.0],
	&"mentor": [Vector3(-13.0, 0.0, -1.0), 1.2],
	&"smith": [Vector3(20.5, 0.0, -0.5), -0.6],
	&"sage": [Vector3(-16.0, 0.0, -14.5), 0.8],
	&"merchant": [Vector3(12.0, 0.0, -3.0), -1.2],
}

## Місця переваг перед походом: вечеря в таверні, точило в кузні,
## казан Мудреця; скриня вдома.
const TAVERN_TABLE := Vector3(6.4, 0.0, 26.0)
const ANVIL := Vector3(22.5, 0.0, 1.8)
const CAULDRON := Vector3(-13.6, 0.0, -16.6)
const HOME_CHEST := Vector3(-6.6, 0.0, 30.5)
const WELL := Vector3(-6.0, 0.0, 21.0)
## Ліхтарні стовпи вздовж вулиць (з вогнем).
const LAMPS := [Vector3(4.4, 0, 34.0), Vector3(-4.4, 0, 24.0), Vector3(4.4, 0, 14.0), Vector3(-17.0, 0, -15.0),
	Vector3(17.0, 0, 12.5), Vector3(3.6, 0, -30.0)]

## Будинки: [ім'я, центр XZ, поворот (0 — фасад на південь), spec для HouseKit].
## Поворот 90 — фасад на схід (+X), -90 — на захід.
const HOUSES := [
	# Біля брами.
	["home", Vector2(-9.0, 30.0), 90.0, {"w": 2, "d": 2, "floors": 2, "base": "brick", "door": 0, "chimney": true, "seed": 11}],
	["house_w1", Vector2(-9.5, 19.5), 90.0, {"w": 2, "d": 3, "floors": 3, "base": "plaster", "door": 1, "seed": 12}],
	["tavern", Vector2(11.0, 26.0), -90.0, {"w": 3, "d": 3, "floors": 2, "base": "brick", "door": 1, "chimney": true, "balcony": true, "seed": 13}],
	["house_e1", Vector2(10.0, 15.5), -90.0, {"w": 2, "d": 2, "floors": 3, "base": "brick", "door": 0, "seed": 14}],
	# Площа.
	["townhall", Vector2(0.0, -23.0), 0.0, {"w": 4, "d": 4, "floors": 3, "base": "brick", "door": 1, "balcony": true, "chimney": true, "seed": 15}],
	["house_n1", Vector2(-11.0, -31.0), 0.0, {"w": 2, "d": 2, "floors": 2, "base": "brick", "door": 1, "seed": 16}],
	["house_n2", Vector2(11.5, -23.5), 0.0, {"w": 3, "d": 2, "floors": 2, "base": "plaster", "door": 1, "chimney": true, "seed": 17}],
	["market_house", Vector2(22.0, -14.0), -90.0, {"w": 2, "d": 3, "floors": 2, "base": "brick", "door": 1, "seed": 18}],
	["barracks", Vector2(-24.0, -8.0), 90.0, {"w": 2, "d": 4, "floors": 2, "base": "brick", "door": 2, "windows": "few", "seed": 19}],
	["house_sw", Vector2(-21.0, 8.0), 90.0, {"w": 2, "d": 2, "floors": 2, "base": "plaster", "door": 0, "chimney": true, "seed": 20}],
	["house_se", Vector2(21.0, 9.0), -90.0, {"w": 2, "d": 2, "floors": 2, "base": "brick", "door": 1, "seed": 21}],
	# Кузня й бібліотека.
	["smithy", Vector2(27.0, -2.0), -90.0, {"w": 2, "d": 3, "floors": 1, "base": "brick", "door": 1, "chimney": true, "seed": 22}],
	["library", Vector2(-22.0, -22.0), 45.0, {"w": 2, "d": 2, "floors": 3, "base": "brick", "upper": "brick", "door": 0, "tower": true, "seed": 23}],
	# Друга лінія й закутки — щоб місто було щільним.
	["house_w2", Vector2(-17.0, 27.0), 90.0, {"w": 2, "d": 2, "floors": 2, "base": "brick", "door": 0, "chimney": true, "seed": 31}],
	["house_w3", Vector2(-25.5, 24.0), 90.0, {"w": 2, "d": 3, "floors": 2, "base": "plaster", "door": 1, "seed": 32}],
	["house_e2", Vector2(19.0, 25.0), -90.0, {"w": 2, "d": 2, "floors": 3, "base": "brick", "door": 1, "seed": 33}],
	["house_e3", Vector2(26.5, 18.0), -90.0, {"w": 2, "d": 2, "floors": 2, "base": "plaster", "door": 0, "chimney": true, "seed": 34}],
	["house_n3", Vector2(22.0, -27.0), 0.0, {"w": 2, "d": 2, "floors": 3, "base": "brick", "door": 0, "seed": 35}],
	["house_nw", Vector2(-29.5, -16.0), 90.0, {"w": 2, "d": 2, "floors": 2, "base": "brick", "door": 1, "chimney": true, "seed": 36}],
	["house_sq_sw", Vector2(-12.5, 17.0), 180.0, {"w": 2, "d": 2, "floors": 2, "base": "brick", "door": 1, "seed": 37}],
	["house_sq_se", Vector2(13.0, 18.0), 180.0, {"w": 2, "d": 2, "floors": 2, "base": "plaster", "door": 0, "chimney": true, "seed": 38}],
	# Брама: дві вежі.
	["gate_w", Vector2(-5.0, 40.0), 0.0, {"w": 2, "d": 2, "floors": 3, "base": "brick", "upper": "brick", "door": -1, "windows": "few", "tower": true, "seed": 24}],
	["gate_e", Vector2(5.0, 40.0), 0.0, {"w": 2, "d": 2, "floors": 3, "base": "brick", "upper": "brick", "door": -1, "windows": "few", "tower": true, "seed": 25}],
]

## Висота землі: у місті рівно, за краєм — пагорби.
static func height(x: float, z: float) -> float:
	return ground(x, z)

static func ground(x: float, z: float) -> float:
	var p := Vector2((x - BOWL_CENTER.x) / BOWL_RADIUS.x, (z - BOWL_CENTER.y) / BOWL_RADIUS.y)
	var a := atan2(p.y, p.x)
	var wobble := 1.0 + 0.07 * sin(a * 3.0 + 0.7) + 0.05 * sin(a * 7.0 + 2.1)
	var e := p.length() * wobble
	var bumps := 0.12 * sin(x * 0.21 + z * 0.13) + 0.1 * sin(x * 0.07 - z * 0.19 + 1.3)
	if e <= 0.82:
		return 0.0
	# Луки за містом — легкі горбики; далі — пагорби.
	var meadow := smoothstep(0.82, 1.0, e) * bumps * 4.0
	if e <= 1.0:
		return maxf(meadow, 0.0)
	return maxf(meadow, 0.0) + minf(pow((e - 1.0) * 3.0, 1.4) * 10.0, 26.0)

static func visual_vertex(x: float, z: float) -> Vector3:
	return Vector3(x, ground(x, z), z)

static func in_rect(x: float, z: float, rect: Rect2, margin: float = 0.0) -> bool:
	return x > rect.position.x - margin and x < rect.end.x + margin and z > rect.position.y - margin and z < rect.end.y + margin

## Маска землі для шейдера: r — утоптана земля, g — бруківка, b — тінь.
## У місті під ногами земля з острівцями трави, вулиці й площа — бруківка
## з нерівним краєм; за мурами — луки й ґрунтові дороги.
const COBBLE_RECTS := [SQUARE, MAIN_STREET, SMITH_STREET, NORTH_LANE, Rect2(-3.5, 36.0, 7.0, 8.0)]
static func mask(x: float, z: float, h: float) -> Color:
	var wobble := 0.22 * sin(x * 0.9 + z * 0.4) + 0.16 * sin(z * 1.3 - x * 0.6)
	var cobble := 0.0
	for rect: Rect2 in COBBLE_RECTS:
		var dx := maxf(rect.position.x - x, x - rect.end.x)
		var dz := maxf(rect.position.y - z, z - rect.end.y)
		cobble = maxf(cobble, 1.0 - smoothstep(-0.6, 0.6, maxf(dx, dz) + wobble))
	var town := x > -33.0 and x < 33.0 and z > -50.0 and z < 39.0
	var patches := 0.5 + 0.5 * sin(x * 0.23 + 1.7) * sin(z * 0.19 - 0.6) + 0.25 * sin(x * 0.61 - z * 0.47)
	var dirt := clampf(0.35 + patches * 0.6, 0.0, 1.0) if town else 0.0
	for line: Array in [[Vector2(0, 90), Vector2(0, 58), Vector2(0, 42)], [Vector2(30, 0), Vector2(44, 6), Vector2(58, 18)],
			[Vector2(0, -40), Vector2(-2, -52)]]:
		for i in line.size() - 1:
			var d := Geometry2D.get_closest_point_to_segment(Vector2(x, z), line[i], line[i + 1]).distance_to(Vector2(x, z))
			dirt = maxf(dirt, 1.0 - smoothstep(1.4, 3.0, d))
	return Color(dirt, cobble, 0.0)
