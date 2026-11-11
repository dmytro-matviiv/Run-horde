extends RefCounted
class_name WeaponAnims

## СПРАВЖНІ АНІМАЦІЇ ПІД ЗБРОЮ. Кожна пара "герой + стиль зброї" може мати
## свій набір кліпів (Mixamo, перенесених на модель героя інструментом
## retarget — test_env/tools/retarget.gd; сирі FBX лежать у
## D:\RuneHorde_work\mixamo\<герой>\<зброя>). Кліп підміняє коротку назву
## анімації, яку просить гра ("Idle", "Run", "Run_Left", "Dash_Strike"...),
## або дає свою (W_attack_N, W_whirl) для серії й здібностей.
##
## Шлях кліпу — відносно ROOT героя ("axe/attack_1" -> .../axe/attack_1.res).
## Чого тут немає — гра бере з моделі як і раніше.

const ROOT := {
	&"blade_warden": "res://assets/animations/warden/",
}

## Біг убік і назад з однорукою зброєю — спільний для меча, сокири, тесака,
## клинків і кинджалів (інакше змішування з бігом моделі крутило кисть).
const ONE_HAND_MOVES := {
	"Run_Back": "onehand/run_back", "Run_Left": "onehand/run_left", "Run_Right": "onehand/run_right",
}

const SETS := {
	&"blade_warden": {
		# Однорукий меч, ліва рука вільна. Серія з 4 ударів без обертів:
		# назовні, назад, згори вниз, широкий мах (фініш). Ривок — стрибок
		# з ударом, Вихор — справжній оберт на 360°.
		"sword": {
			"clips": {
				"Idle": "sword/idle", "Walk": "sword/run", "Run": "sword/run",
				"W_attack_1": "sword/attack_1", "W_attack_2": "sword/attack_2",
				"W_attack_3": "sword/attack_3", "W_attack_4": "sword/attack_4",
				"Dash_Strike": "sword/dash", "W_whirl": "sword/whirl",
			},
			"one_hand_moves": true,
			"dash_strike_at": 0.78,
		},
		# Сокира: горизонтальний мах, оберт на 360° (сокирі можна), удар
		# згори обома руками об землю. Ривок — стрибок з ударом сокирою.
		"axe": {
			"clips": {
				"Idle": "sword/idle", "Walk": "onehand/run_axe", "Run": "onehand/run_axe",
				"W_attack_1": "axe/attack_1", "W_attack_2": "axe/attack_2", "W_attack_3": "axe/attack_3",
				"Dash_Strike": "shared/dash_jump", "W_whirl": "shared/whirl_low",
			},
			"one_hand_moves": true,
			"dash_strike_at": 0.9,
		},
		# Тесак: три важкі рублячі удари без обертів, останній — згори.
		"cleaver": {
			"clips": {
				"Idle": "sword/idle", "Walk": "onehand/run_axe", "Run": "onehand/run_axe",
				"W_attack_1": "cleaver/attack_1", "W_attack_2": "cleaver/attack_2", "W_attack_3": "cleaver/attack_3",
				"Dash_Strike": "shared/dash_jump", "W_whirl": "shared/whirl_low",
			},
			"one_hand_moves": true,
			"dash_strike_at": 0.9,
		},
		# Глефа — дворучна: укол, оберт із замахом, удар згори. Стійка й
		# біг дворучні, ривок — випад уперед, Вихор — високий оберт.
		"glaive": {
			"clips": {
				"Idle": "glaive/idle", "Walk": "glaive/run", "Run": "glaive/run",
				"Run_Back": "glaive/run_back", "Run_Left": "glaive/run_left", "Run_Right": "glaive/run_right",
				"W_attack_1": "glaive/attack_1", "W_attack_2": "glaive/attack_2", "W_attack_3": "glaive/attack_3",
				"Dash_Strike": "shared/dash_lunge", "W_whirl": "glaive/whirl",
			},
			"dash_strike_at": 0.65,
		},
		# Парні клинки: ліва, права, обидві, оберт, хрест обома (5 ударів).
		"twin_blades": {
			"clips": {
				"Idle": "sword/idle", "Walk": "onehand/run_axe", "Run": "onehand/run_axe",
				"W_attack_1": "twin/attack_1", "W_attack_2": "twin/attack_2", "W_attack_3": "twin/attack_3",
				"W_attack_4": "twin/attack_4", "W_attack_5": "twin/attack_5",
				"Dash_Strike": "shared/dash_jump", "W_whirl": "shared/whirl_low",
			},
			"one_hand_moves": true,
			"dash_strike_at": 0.9,
		},
		# Кинджали: короткі уколи то лівою, то правою, зворотний хват і
		# подвійний укол-фініш. Без обертів. Стійка — ніж у зворотному хваті.
		"daggers": {
			"clips": {
				"Idle": "daggers/idle", "Walk": "onehand/run_axe", "Run": "onehand/run_axe",
				"W_attack_1": "daggers/attack_1", "W_attack_2": "daggers/attack_2", "W_attack_3": "daggers/attack_3",
				"W_attack_4": "daggers/attack_4", "W_attack_5": "daggers/attack_5",
				"Dash_Strike": "sword/dash", "W_whirl": "shared/whirl_low",
			},
			"one_hand_moves": true,
			"dash_strike_at": 0.78,
		},
	},
}

## Кліпи, що мають крутитись по колу.
const LOOPED := ["Idle", "Walk", "Run", "Run_Back", "Run_Left", "Run_Right"]

## Набір для героя й стилю зброї (порожній словник — свого набору немає).
static func get_set(hero_id: StringName, style: String) -> Dictionary:
	var by_style: Dictionary = SETS.get(hero_id, {})
	return by_style.get(style, {})

## Коротка назва -> шлях кліпу (відносно ROOT) для набору.
static func clips_of(set: Dictionary) -> Dictionary:
	var clips: Dictionary = (set.get("clips", {}) as Dictionary).duplicate()
	if set.get("one_hand_moves", false):
		for short_name: String in ONE_HAND_MOVES:
			if not clips.has(short_name):
				clips[short_name] = ONE_HAND_MOVES[short_name]
	return clips

## Додає кліпи набору в бібліотеку моделі. Повертає підміну назв:
## коротка назва -> повна назва анімації в AnimationPlayer.
static func install(player: AnimationPlayer, hero_id: StringName, style: String) -> Dictionary:
	var set := get_set(hero_id, style)
	var overrides := {}
	if set.is_empty() or not player.has_animation_library(&""):
		return overrides
	var library := player.get_animation_library(&"")
	var clips := clips_of(set)
	for short_name: String in clips:
		var file: String = clips[short_name]
		var path := String(ROOT.get(hero_id, "")) + file + ".res"
		if not ResourceLoader.exists(path):
			push_warning("WeaponAnims: немає %s" % path)
			continue
		var full_name := "Weapon|" + file.replace("/", "_")
		if not library.has_animation(full_name):
			var anim: Animation = load(path)
			if short_name in LOOPED:
				anim.loop_mode = Animation.LOOP_LINEAR
			library.add_animation(full_name, anim)
		overrides[short_name] = full_name
	return overrides
