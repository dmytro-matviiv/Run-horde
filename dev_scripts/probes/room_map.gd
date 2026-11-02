extends SceneTree
func _init() -> void:
	for i in [1, 7]:
		var level: Dictionary = DungeonLevels.get_level(i)
		var room := DungeonBuilder.boss_room(level.map)
		print("LEVEL ", i)
		for z in level.map.size():
			var row: String = level.map[z]
			var out := ""
			for x in row.length():
				out += ("@" if row[x] != "." and row[x] != " " else "*") if room.has(Vector2i(x, z)) else row[x]
			print(out)
	quit()
