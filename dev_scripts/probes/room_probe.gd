extends SceneTree
func _init() -> void:
	for i in DungeonLevels.get_level_count():
		var level: Dictionary = DungeonLevels.get_level(i)
		var room := DungeonBuilder.boss_room(level.map)
		var inside := 0
		for z in level.map.size():
			var row: String = level.map[z]
			for x in row.length():
				if row[x] in ["m", "r", "w", "x", "c", "t"] and room.has(Vector2i(x, z)):
					inside += 1
		var total := 0
		for zz in level.map.size():
			for xx in String(level.map[zz]).length():
				if DungeonBuilder.is_walkable(level.map, xx, zz): total += 1
		print("LEVEL %d: зала %d з %d, міток %d" % [i, room.size(), total, inside])
	quit()
