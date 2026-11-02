# -*- coding: utf-8 -*-
"""Цитадель: без снігових плит; плити з кристалом — хаотично (не рядами
на входах), лишаються під скринями й перед статуями."""
p = r"D:\Claude code\idle survivor_like\scenes\dungeon\dungeon_builder.gd"
s = open(p, encoding="utf-8").read()

start = s.index("## Поворот снігової плити (у чвертях оберту).")
end = s.index("## Перешкоди статуй і брил")
s = s[:start] + s[end:]

reps = [
    ('''const ICE_FLOOR_SNOW := preload("res://assets/models/citadel/kit/floor_snow.glb")\n''', ''),
    ('''		"floor_rules": {"main": ICE_FLOOR_RUNES, "edge": ICE_FLOOR_SNOW, "accent": ICE_FLOOR_GLOW},''',
     '''		"floor_rules": {"main": ICE_FLOOR_RUNES, "accent": ICE_FLOOR_GLOW},'''),
    ('''## Тема з "floor_rules" розкладає рівень не навмання, а за будовою карти:
##   сніг ("edge")      — контур: кожна клітинка біля стіни, сніжним кутом
##                        до стіни (уздовж стіни — смугою);
##   кристал ("accent") — під скринями, на входах у коридори, під статуєю й
##                        перед нею, зрідка посеред зали;
##   руни ("main")      — решта, середина зал.''',
     '''## Тема з "floor_rules" розкладає рівень за будовою карти:
##   кристал ("accent") — під скринями, під статуєю й перед нею, а решта —
##                        хаотично по всьому рівню (рядами на входах у
##                        коридори виглядало однорідно), але не впритул одна
##                        до одної;
##   руни ("main")      — усе інше.'''),
    ('''const ACCENT_CHANCE := 0.025''', '''const ACCENT_CHANCE := 0.08'''),
    ('''	# Плити підлоги: [вид, поворот у чвертях оберту].
	for cell in cells:
		var kind := "main"
		var turn := floori(_hash01(cell.x, cell.y, 32) * 4.0)
		var edge := false
		for side in sides:
			if not _is_walkable(map_rows, cell.x + side.x, cell.y + side.y):
				edge = true
		if layout.chests.has(cell) or entrances.has(cell) or layout.landmarks.has(cell) \\
				or layout.landmarks.has(cell - Vector2i(0, 1)):
			kind = "accent"
		elif edge:
			kind = "edge"
			turn = _snow_turn(map_rows, cell)
		elif _hash01(cell.x, cell.y, 33) < ACCENT_CHANCE:
			kind = "accent"
		layout.floor[cell] = [kind, turn]''',
     '''	# Плити підлоги: [вид, поворот у чвертях оберту]. Кристал навмання —
	# лише якщо ні зліва, ні згори вже немає кристала (клітинки йдуть рядами
	# зліва направо й згори вниз), щоб не злипались у плями.
	for cell in cells:
		var kind := "main"
		var turn := floori(_hash01(cell.x, cell.y, 32) * 4.0)
		if layout.chests.has(cell) or layout.landmarks.has(cell) or layout.landmarks.has(cell - Vector2i(0, 1)):
			kind = "accent"
		elif _hash01(cell.x, cell.y, 33) < ACCENT_CHANCE \\
				and layout.floor.get(cell - Vector2i(1, 0), ["main"])[0] != "accent" \\
				and layout.floor.get(cell - Vector2i(0, 1), ["main"])[0] != "accent":
			kind = "accent"
		layout.floor[cell] = [kind, turn]'''),
    ('''	## Крижана цитадель — уся на арті гравця. Підлога розкладена за змістом''',
     '''	## Крижана цитадель — уся на арті гравця. Підлога — рунні плити, а плити з
	## кристалом — під скринями, перед статуями й хаотично по рівню (floor_rules,'''),
]
for a, b in reps:
    assert s.count(a) == 1, a[:90]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
