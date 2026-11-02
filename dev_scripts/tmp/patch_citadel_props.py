# -*- coding: utf-8 -*-
"""Правка розкладки цитаделі: стійки зі зброєю, припаси (ящики з бочкою),
настінні прапори — моделі гравця."""
p = r"D:\Claude code\idle survivor_like\scenes\dungeon\dungeon_builder.gd"
s = open(p, encoding="utf-8").read()

HELPERS = '''
## Стійка зі зброєю: задником до стіни, лицем (зброєю) в залу.
static func _rack_placement(cell: Vector2i, wall_side: Vector2i, decor: Dictionary) -> Dictionary:
	var rack: Dictionary = decor.rack
	var size: float = rack.get("scale", 1.0)
	var depth: float = rack.get("depth", 0.4) * size
	var yaw: float = _wall_directions()[wall_side] + (_hash01(cell.x, cell.y, 56) - 0.5) * deg_to_rad(8.0)
	var push: float = CELL * 0.5 - float(decor.get("wall_inset", 0.0)) - depth - 0.05
	var position := Vector3(cell.x * CELL, 0.0, cell.y * CELL) + Vector3(wall_side.x, 0.0, wall_side.y) * push
	return {"position": position, "yaw": yaw, "scale": size}

## Припаси (ящики з бочкою) у куті зали: спиною до північної чи південної
## стіни кута, зсунуті в кут.
static func _supplies_placement(cell: Vector2i, corner: Vector2i, decor: Dictionary) -> Dictionary:
	var supplies: Dictionary = decor.supplies
	var size: float = supplies.get("scale", 1.0)
	var yaw := 0.0 if corner.y < 0 else PI
	var position := Vector3(cell.x * CELL, 0.0, cell.y * CELL) + Vector3(corner.x * 0.15, 0.0, corner.y * 0.28)
	return {"position": position, "yaw": yaw, "scale": size}
'''

reps = [
    ('''const RUNE_ROCK_SCENE := preload("res://assets/models/citadel/rune_rock.glb")''',
     '''const RUNE_ROCK_SCENE := preload("res://assets/models/citadel/rune_rock.glb")
## Крижані стійка зі зброєю, прапор і припаси (ящики з бочкою) — моделі
## гравця, спрощені під телефон (стійка 8.7 -> 2.2 тис. трикутників, прапор
## 9.5 -> 2.4, припаси 94 -> 2.9 тис. і 183 частини -> одна сітка).
const ICE_WEAPON_RACK_SCENE := preload("res://assets/models/citadel/ice_weapon_rack.glb")
const ICE_BANNER_SCENE := preload("res://assets/models/citadel/ice_banner.glb")
const ICE_SUPPLIES_SCENE := preload("res://assets/models/citadel/ice_supplies.glb")'''),
    ('''		"rock": {"scene": RUNE_ROCK_SCENE, "scale": Vector2(0.36, 0.46), "chance": 0.08},''',
     '''		## Попід прямими стінами: брила або (share) стійка зі зброєю.
		"rock": {"scene": RUNE_ROCK_SCENE, "scale": Vector2(0.36, 0.46), "chance": 0.11},
		"rack": {"scene": ICE_WEAPON_RACK_SCENE, "scale": 0.9, "share": 0.4, "depth": 0.41, "footprint": Vector2(1.9, 0.8)},
		## У кутах зал без скринь — ящики з бочкою.
		"supplies": {"scene": ICE_SUPPLIES_SCENE, "scale": 0.7, "chance": 0.55, "footprint": Vector2(2.2, 1.3)},
		## Прапори — на північних стінах зал (їх видно з камери), через кожні
		## every клітинок; низ — так, щоб верх був на висоті top.
		"banner": {"scene": ICE_BANNER_SCENE, "scale": 0.75, "every": 4, "depth": 0.174, "height": 1.775, "top": 1.95},'''),
    ('''	var layout := {"floor": {}, "chests": {}, "landmarks": {}, "rocks": {}, "stones": {}, "occupied": {}}''',
     '''	var layout := {"floor": {}, "chests": {}, "landmarks": {}, "rocks": {}, "racks": {}, "supplies": {},
		"banners": {}, "stones": {}, "occupied": {}}'''),
    ('''		if int(n) + int(s) + int(w) + int(e) == 2 and n != s and w != e \\
				and _hash01(cell.x, cell.y, 41) < chest_chance:
			layout.chests[cell] = Vector2i(-1 if w else 1, -1 if n else 1)''',
     '''		if int(n) + int(s) + int(w) + int(e) != 2 or n == s or w == e:
			continue
		var corner := Vector2i(-1 if w else 1, -1 if n else 1)
		if _hash01(cell.x, cell.y, 41) < chest_chance:
			layout.chests[cell] = corner
		elif decor.has("supplies") and _hash01(cell.x, cell.y, 43) < float(decor.supplies.get("chance", 0.5)):
			layout.supplies[cell] = corner'''),
    ('''			elif walls != 1:
				continue
			layout.rocks[cell] = wall_side
			rocks.append(cell)''',
     '''			elif walls != 1:
				continue
			if walls == 1 and decor.has("rack") and _hash01(cell.x, cell.y, 55) < float(decor.rack.get("share", 0.3)):
				layout.racks[cell] = wall_side
			else:
				layout.rocks[cell] = wall_side
			rocks.append(cell)'''),
    ('''	for cell: Vector2i in layout.chests:
		layout.occupied[cell] = true
	for cell: Vector2i in layout.rocks:
		layout.occupied[cell] = true
''', '''	for group: String in ["chests", "rocks", "racks", "supplies"]:
		for cell: Vector2i in layout[group]:
			layout.occupied[cell] = true

	# Прапори — на глухій північній стіні зали, через кожні every клітинок,
	# не над факелом, не за статуєю й не над предметом під стіною.
	var banner: Dictionary = decor.get("banner", {})
	if not banner.is_empty():
		var every := int(banner.get("every", 4))
		for cell in cells:
			if cell.x % every != 1 or not _wall_above_room(map_rows, corridor, cell):
				continue
			if (cell.x + cell.y) % TORCH_EVERY == 0 or _near_any(cell, chosen, 1) or layout.occupied.has(cell):
				continue
			layout.banners[cell] = true
'''),
    ('''	for cell: Vector2i in layout.rocks:
		var placement := _rock_placement(cell, layout.rocks[cell], decor)''',
     '''	for cell: Vector2i in layout.racks:
		var placement := _rack_placement(cell, layout.racks[cell], decor)
		var footprint: Vector2 = decor.rack.get("footprint", Vector2(1.9, 0.8)) * float(placement.scale)
		var side: Vector2i = layout.racks[cell]
		var box := Vector3(footprint.y, 1.6, footprint.x) if side.x != 0 else Vector3(footprint.x, 1.6, footprint.y)
		_add_box_shape(obstacles, placement.position + Vector3(0, 0.8, 0), box)
	for cell: Vector2i in layout.supplies:
		var placement := _supplies_placement(cell, layout.supplies[cell], decor)
		var footprint: Vector2 = decor.supplies.get("footprint", Vector2(2.2, 1.3)) * float(placement.scale)
		_add_box_shape(obstacles, placement.position + Vector3(0, 0.75, 0), Vector3(footprint.x, 1.5, footprint.y))
	for cell: Vector2i in layout.rocks:
		var placement := _rock_placement(cell, layout.rocks[cell], decor)'''),
    ('''static func _add_layout_items(batcher: MeshBatcher, layout: Dictionary, cell: Vector2i, position: Vector3, decor: Dictionary) -> bool:
	if layout.landmarks.has(cell):''',
     '''static func _add_layout_items(batcher: MeshBatcher, layout: Dictionary, cell: Vector2i, position: Vector3, decor: Dictionary) -> bool:
	if layout.banners.has(cell):
		# Прапор на північній стіні: кріпленням до лиця стіни, верхом під гребінь.
		var banner: Dictionary = decor.banner
		var size: float = banner.get("scale", 1.0)
		var back: float = CELL * 0.5 - float(decor.get("wall_inset", 0.0)) - float(banner.get("depth", 0.0)) * size
		var bottom: float = float(banner.get("top", 1.9)) - float(banner.get("height", 1.8)) * size
		var spot := position + Vector3(0.0, bottom, -back)
		batcher.add(banner.scene, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), spot), Color.WHITE, true)
	if layout.racks.has(cell):
		var placement := _rack_placement(cell, layout.racks[cell], decor)
		var basis := Basis(Vector3.UP, placement.yaw).scaled(Vector3.ONE * float(placement.scale))
		batcher.add(decor.rack.scene, Transform3D(basis, placement.position), Color.WHITE, true)
		return true
	if layout.supplies.has(cell):
		var placement := _supplies_placement(cell, layout.supplies[cell], decor)
		var basis := Basis(Vector3.UP, placement.yaw).scaled(Vector3.ONE * float(placement.scale))
		batcher.add(decor.supplies.scene, Transform3D(basis, placement.position), Color.WHITE, true)
		return true
	if layout.landmarks.has(cell):'''),
    ('''## Статуя, брила, скриня чи камінці на клітинці з розкладки.''',
     HELPERS.strip('\n') + '''

## Статуя, брила, стійка, припаси, скриня, прапор чи камінці на клітинці з розкладки.'''),
]
for a, b in reps:
    assert s.count(a) == 1, a[:90]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
