extends RefCounted
class_name WeaponAnims

## СПРАВЖНІ АНІМАЦІЇ ПІД ЗБРОЮ. Кожна пара "герой + стиль зброї" може мати
## свій набір кліпів (Mixamo, перенесених на модель героя інструментом
## retarget — test_env/tools/retarget.gd; сирі FBX лежать у
## D:\RuneHorde_work\mixamo\<герой>\<зброя>). Кліп підміняє коротку назву
## анімації, яку просить гра ("Idle", "Run", "Dash_Strike"...), або дає
## свою (W_attack_N, W_whirl) для серії й здібностей.
##
## Чого тут немає — гра бере з моделі як і раніше.

const SETS := {
	&"blade_warden": {
		# Однорукий меч, ліва рука вільна. Серія з 4 ударів без обертів:
		# назовні, назад, згори вниз, широкий мах (фініш). Ривок — стрибок
		# з ударом, Вихор — справжній оберт на 360°.
		"sword": {
			"dir": "res://assets/animations/warden/sword/",
			"clips": {
				"Idle": "idle", "Walk": "run", "Run": "run",
				"W_attack_1": "attack_1", "W_attack_2": "attack_2", "W_attack_3": "attack_3", "W_attack_4": "attack_4",
				"Dash_Strike": "dash", "W_whirl": "whirl",
			},
			"loop": ["idle", "run"],
			# Коли в кліпі ривку клинок б'є (с від початку кліпу).
			"dash_strike_at": 0.78,
		},
	},
}

## Набір для героя й стилю зброї (порожній словник — свого набору немає).
static func get_set(hero_id: StringName, style: String) -> Dictionary:
	var by_style: Dictionary = SETS.get(hero_id, {})
	return by_style.get(style, {})

## Додає кліпи набору в бібліотеку моделі. Повертає підміну назв:
## коротка назва -> повна назва анімації в AnimationPlayer.
static func install(player: AnimationPlayer, hero_id: StringName, style: String) -> Dictionary:
	var set := get_set(hero_id, style)
	var overrides := {}
	if set.is_empty() or not player.has_animation_library(&""):
		return overrides
	var library := player.get_animation_library(&"")
	var loops: Array = set.get("loop", [])
	var clips: Dictionary = set.clips
	for short_name: String in clips:
		var file: String = clips[short_name]
		var path := String(set.dir) + file + ".res"
		if not ResourceLoader.exists(path):
			push_warning("WeaponAnims: немає %s" % path)
			continue
		var full_name := "Weapon|%s_%s" % [style, file]
		if not library.has_animation(full_name):
			var anim: Animation = load(path)
			if loops.has(file):
				anim.loop_mode = Animation.LOOP_LINEAR
			library.add_animation(full_name, anim)
		overrides[short_name] = full_name
	return overrides
