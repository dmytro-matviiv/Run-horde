# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/dungeon/dungeon_builder.gd", [
    ('''	var layout := {"floor": {}, "chests": {}, "landmarks": {}, "rocks": {}, "racks": {}, "supplies": {},
		"banners": {}, "stones": {}, "occupied": {}}''', '''	var layout := {"floor": {}, "chests": {}, "landmarks": {}, "rocks": {}, "racks": {}, "supplies": {},
		"banners": {}, "stones": {}, "occupied": {}, "sentinels": {}}'''),
    ('''	# Брили — попід прямою стіною зали (стіна рівно з одного боку), не''', '''	# Кожна друга статуя — Ожилий вартовий ("sentinels" у темі): на її місці
	# стоїть ворог, що прикидається статуєю (Dungeon._spawn_sentinels).
	if decor.get("sentinels", false):
		var statues: Array = layout.landmarks.keys()
		statues.sort()
		for i in statues.size():
			if i % 2 == 1:
				layout.landmarks.erase(statues[i])
				layout.sentinels[statues[i]] = true

	# Брили — попід прямою стіною зали (стіна рівно з одного боку), не'''),
    ('''static func _layout_for(map_rows: Array) -> Dictionary:''', '''## Де замість статуй стоять Ожилі вартові (див. "sentinels" у темі).
static func sentinel_spots(map_rows: Array) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for cell: Vector2i in _layout_for(map_rows).get("sentinels", {}):
		spots.append(cell_center(cell))
	return spots

static func _layout_for(map_rows: Array) -> Dictionary:'''),
    ('''		"landmark": {"scene": ICE_KNIGHT_STATUE_SCENE, "scale": 1.55, "max": 4, "footprint": Vector2(1.5, 1.4)},''',
     '''		"landmark": {"scene": ICE_KNIGHT_STATUE_SCENE, "scale": 1.55, "max": 4, "footprint": Vector2(1.5, 1.4)},
		"sentinels": true,'''),
])

patch("scenes/dungeon/dungeon.gd", [
    ('''	if markers.boss != Vector3.ZERO:
		if _level.get("boss_gate", false):''', '''	_spawn_sentinels()
	if markers.boss != Vector3.ZERO:
		if _level.get("boss_gate", false):'''),
    ('''func _arena_at(cell: Vector2i) -> int:''', '''## Ожилі вартові на місці частини статуй (DungeonBuilder.sentinel_spots):
## стоять кам'яні, доки герой не підійде.
func _spawn_sentinels() -> void:
	var definition: Dictionary = {}
	for group: Array in _level.enemies.values():
		for candidate: Dictionary in group:
			if candidate.has("dormant"):
				definition = candidate
	if definition.is_empty():
		return
	for spot in DungeonBuilder.sentinel_spots(_map_rows):
		_spawn_enemy(spot, definition, false)

func _arena_at(cell: Vector2i) -> int:'''),
])

patch("scenes/dungeon/enemy_3d.gd", [
    ('''func _make_dormant() -> void:
	_dormant = true''', '''func _make_dormant() -> void:
	# Засідка вже покликала його в бій (alert) — статуєю не прикидається.
	if _aggro or hunting:
		return
	_dormant = true'''),
    ('''func alert() -> void:''', '''func alert() -> void:
	if _dormant:
		_wake()'''),
])
print("patched")
