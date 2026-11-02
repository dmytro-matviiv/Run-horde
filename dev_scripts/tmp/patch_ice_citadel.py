# -*- coding: utf-8 -*-
"""Разова правка scenes/dungeon/dungeon_builder.gd: Крижана цитадель на
наборі IceCitadel — підлога, стіни, крижаний факел (разом зі статуєю)."""
p = r"D:\Claude code\idle survivor_like\scenes\dungeon\dungeon_builder.gd"
s = open(p, encoding="utf-8").read()

reps = [
    ('''const ICE_KNIGHT_STATUE_SCENE := preload("res://assets/models/citadel/ice_knight_statue.glb")''',
     '''const ICE_KNIGHT_STATUE_SCENE := preload("res://assets/models/citadel/ice_knight_statue.glb")
## Набір IceCitadel (гравця) для Крижаної цитаделі — уже під клітинку 2 м
## (process_dungeon_kit.py ice): плити з рунами, засніжені й з крижаним
## сяйвом; стіни з рунним поясом і бурульками, з інеєм, з рунною колоною.
const ICE_FLOORS := [
	[preload("res://assets/models/citadel/kit/floor_runes.glb"), 0.6],
	[preload("res://assets/models/citadel/kit/floor_snow.glb"), 0.3],
	[preload("res://assets/models/citadel/kit/floor_glow.glb"), 0.1],
]
## Стіна з рунною колоною — рідше: вона розриває рунний пояс сусідніх.
const ICE_WALLS := [
	preload("res://assets/models/citadel/kit/wall_runes.glb"), preload("res://assets/models/citadel/kit/wall_frost.glb"),
	preload("res://assets/models/citadel/kit/wall_runes.glb"), preload("res://assets/models/citadel/kit/wall_frost.glb"),
	preload("res://assets/models/citadel/kit/wall_pillar.glb"),
]
## Настінний крижаний факел (набір гравця, спрощено 7578 -> 1894
## трикутники, optimize_model.py): рунна плита спереду (+Z), кріплення
## ззаду на глибині 0.269 м.
const ICE_TORCH_SCENE := preload("res://assets/models/citadel/ice_torch.glb")'''),
    ('''		"column_pattern": "checker",
''', '''		"column_pattern": "checker",
		"floor_tiles": ICE_FLOORS,
		"wall_tiles": ICE_WALLS,
		"wall_inset": 0.25,
		## Факел замість звичайного: модель, масштаб, глибина кріплення
		## (м, до масштабу) і висота низу над підлогою.
		"torch": {"scene": ICE_TORCH_SCENE, "scale": 1.2, "depth": 0.269, "height": 0.85},
'''),
    ('''		if (x + z) % TORCH_EVERY == 0 and offset.y != 0:
			var torch_position := wall_position - Vector3(offset.x, 0.0, offset.y) * maxf(0.35, inset + 0.1) + Vector3(0, 0.6, 0)
			batcher.add(TORCH_SCENE, Transform3D(Basis(Vector3.UP, directions[offset]), torch_position))''',
     '''		if (x + z) % TORCH_EVERY == 0 and offset.y != 0:
			if decor.has("torch"):
				# Свій факел теми: задником упритул до лиця стіни, у власних
				# кольорах. Поворот — той самий, що в стіни.
				var torch: Dictionary = decor.torch
				var size: float = torch.get("scale", 1.0)
				var toward_wall := Vector3(offset.x, 0.0, offset.y)
				var spot := position + toward_wall * (CELL * 0.5 - inset - torch.get("depth", 0.0) * size) \\
					+ Vector3(0, torch.get("height", 1.0), 0)
				var basis := Basis(Vector3.UP, directions[offset]).scaled(Vector3.ONE * size)
				batcher.add(torch.scene, Transform3D(basis, spot), Color.WHITE, true)
			else:
				var torch_position := wall_position - Vector3(offset.x, 0.0, offset.y) * maxf(0.35, inset + 0.1) + Vector3(0, 0.6, 0)
				batcher.add(TORCH_SCENE, Transform3D(Basis(Vector3.UP, directions[offset]), torch_position))'''),
]
for a, b in reps:
    assert s.count(a) == 1, a[:90]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
