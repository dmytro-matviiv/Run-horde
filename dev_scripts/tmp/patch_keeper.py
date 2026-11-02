# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/dungeon/abilities/enemy_ability.gd", [
    ('''var from_phase := 1
''', '''var from_phase := 1
## До якої фази боса включно діє ("until" в описі).
var until_phase := 99
'''),
    ('''	from_phase = int(settings.get("phase", 1))''', '''	from_phase = int(settings.get("phase", 1))
	until_phase = int(settings.get("until", 99))'''),
    ('''	return _left <= 0.0 and (enemy.phases == null or enemy.phases.phase >= from_phase)''',
     '''	return _left <= 0.0 and (enemy.phases == null
		or (enemy.phases.phase >= from_phase and enemy.phases.phase <= until_phase))'''),
])

patch("scenes/dungeon/abilities/enemy_abilities.gd", [
    ('''	"grasp": preload("res://scenes/dungeon/abilities/grasp_ability.gd"),
''', '''	"grasp": preload("res://scenes/dungeon/abilities/grasp_ability.gd"),
	"crack_lines": preload("res://scenes/dungeon/abilities/crack_lines_ability.gd"),
	"chain_spin": preload("res://scenes/dungeon/abilities/chain_spin_ability.gd"),
	"sarcophagi": preload("res://scenes/dungeon/abilities/sarcophagi_ability.gd"),
'''),
])

patch("scenes/dungeon/boss_phases.gd", [
    ('''	"shadow": {"color": Color(0.35, 0.1, 0.5), "rage": "розколюється", "frenzy": "губиться у тінях"},''',
     '''	"shadow": {"color": Color(0.35, 0.1, 0.5), "rage": "розколюється", "frenzy": "губиться у тінях"},
	"keeper": {"color": Color(1.0, 0.7, 0.3), "rage": "відмикає саркофаги", "frenzy": "гасить факели"},'''),
    ('''	var ratio := _boss.current_hp / maxf(_boss.max_hp, 1.0)
	while phase - 1 < THRESHOLDS.size() and ratio <= THRESHOLDS[phase - 1]:
		_enter_phase(phase + 1)
	if phase >= 2 and _boss.is_aggro():''', '''	var ratio := _boss.current_hp / maxf(_boss.max_hp, 1.0)
	# Свої пороги фаз ("phase_thresholds"), інакше — половина й чверть.
	var thresholds: Array = _boss.definition.get("phase_thresholds", THRESHOLDS)
	while phase - 1 < thresholds.size() and ratio <= thresholds[phase - 1]:
		_enter_phase(phase + 1)
	# "no_hazard_rain": у боса свої механіки фаз замість дощу кіл.
	if phase >= 2 and _boss.is_aggro() and not _boss.definition.get("no_hazard_rain", false):'''),
    ('''	_boss.move_speed *= SPEED_UP
	_boss.attack_cooldown *= COOLDOWN_DOWN''', '''	_boss.move_speed *= SPEED_UP
	_boss.attack_cooldown *= COOLDOWN_DOWN
	# Остання фаза — б'є ще частіше ("frenzy_cooldown").
	if next == 3 and _boss.definition.has("frenzy_cooldown"):
		_boss.attack_cooldown *= float(_boss.definition.frenzy_cooldown)'''),
])

patch("scenes/dungeon/enemy_3d.gd", [
    ('''func play_once(candidates: Array) -> void:
	_play_once(candidates)''', '''func play_once(candidates: Array) -> void:
	_play_once(candidates)

## Зациклена анімація (хода, обертання) — для прийомів, що самі ведуть ворога.
func play_loop(wanted: String) -> void:
	_play(wanted)

## Свічки на плечі боса (Хранитель Склепів у темряві): тепле світло й
## іскри — у темній залі боса видно лише за цим вогником.
func light_candles() -> void:
	if _model == null or _model.has_node("Candles"):
		return
	var holder := Node3D.new()
	holder.name = "Candles"
	_model.add_child(holder)
	var spot: Vector3 = definition.get("candle_spot", Vector3(0.45, 1.65, 0.0))
	holder.position = spot
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 2.2
	light.omni_range = 5.0
	light.shadow_enabled = false
	holder.add_child(light)
	var flames := CombatVfx.make_trail(Color(1.0, 0.65, 0.25), 0.45)
	flames.local_coords = true
	flames.amount = 12
	flames.direction = Vector3.UP
	flames.gravity = Vector3(0, 1.2, 0)
	flames.emission_sphere_radius = 0.12
	holder.add_child(flames)
	var flicker := light.create_tween().set_loops()
	flicker.tween_property(light, "light_energy", 1.7, 0.18)
	flicker.tween_property(light, "light_energy", 2.4, 0.22)

## Кидок свічки (Хранитель у темряві): на місці падіння — вогняна пляма.
func _throw_candle() -> void:
	var candle: Dictionary = definition.candle_throw
	var lob := LobShell.launch(get_parent(), global_position + Vector3.UP * target_height * 0.85,
		_player.global_position, _player, float(candle.get("radius", 1.0)), damage * float(candle.get("damage", 0.4)),
		Color(1.0, 0.55, 0.15), float(candle.get("pool", 3.0)), load("res://assets/models/graveyard/candle_melted.glb"), self)
	lob.arc_height = 1.6'''),
    ('''	for ability in abilities:
		if ability.id == _special:
			_special = ""
			ability.resolve()
			return
	if kind == Kind.RANGED:''', '''	for ability in abilities:
		if ability.id == _special:
			_special = ""
			ability.resolve()
			return
	if definition.has("candle_throw") and phases != null and phases.phase >= 3 and _player != null:
		_throw_candle()
	if kind == Kind.RANGED:'''),
])

patch("scenes/dungeon/dungeon.gd", [
    ('''var _boss: Enemy3D
''', '''var _boss: Enemy3D
## Темрява в залі боса ("darkness" в описі, остання фаза): факели згасли.
var _darkness := false
var _ambient_energy := 1.0
const DARK_AMBIENT := 0.12
'''),
    ('''func _on_boss_phase(phase: int, title: String) -> void:
	_show_banner(title, "швидший і небезпечніший" if phase == 2 else "останній ривок!")''', '''func _on_boss_phase(phase: int, title: String) -> void:
	_show_banner(title, "швидший і небезпечніший" if phase == 2 else "останній ривок!")
	if phase == 3 and _boss != null and is_instance_valid(_boss) and _boss.definition.get("darkness", false):
		_set_darkness()

## Рев гасить факели: загальне світло й факели згасають, світиться лише
## ліхтар героя та свічки на плечі боса.
func _set_darkness() -> void:
	_darkness = true
	var environment: Environment = $WorldEnvironment.environment
	_ambient_energy = environment.ambient_light_energy
	var tween := create_tween().set_parallel(true)
	tween.tween_property(environment, "ambient_light_energy", DARK_AMBIENT, 0.8)
	for light: OmniLight3D in _lights:
		if not light.has_meta("energy"):
			light.set_meta("energy", light.light_energy)
		tween.tween_property(light, "light_energy", 0.0, 0.5 + randf() * 0.4)
	player.set_torch_enabled(true)
	_boss.light_candles()

## Бос упав у темряві — факели спалахують знову, один за одним.
func _relight(center: Vector3) -> void:
	_darkness = false
	var environment: Environment = $WorldEnvironment.environment
	var tween := create_tween().set_parallel(true)
	tween.tween_property(environment, "ambient_light_energy", _ambient_energy, 1.6).set_delay(0.3)
	for light: OmniLight3D in _lights:
		var delay := 0.3 + light.global_position.distance_to(center) * 0.04
		var energy: float = light.get_meta("energy", 1.0)
		tween.tween_property(light, "light_energy", energy * 1.8, 0.25).set_delay(delay)
		tween.chain().tween_property(light, "light_energy", energy, 0.6)
	CombatVfx.shockwave(self, center, 12.0, Color(1.0, 0.75, 0.35), 1.2)'''),
    ('''	if is_boss:
		_boss_defeated = true''', '''	if is_boss:
		_boss_defeated = true
		if _darkness:
			_relight(position)'''),
])

patch("scenes/dungeon/dungeon_levels.gd", [
    ('''		"boss": {"name": "Демон Склепів", "model": "res://assets/models/monsters/Demon-LnfIziKv4o.glb", "style": "demon",
			"hp": 220.0, "damage": 16.0, "speed": 3.2, "height": 3.4, "xp": 25},''', '''		# Хранитель Склепів (модель гравця, скелет і анімації —
		# D:/RuneHorde_work/scripts/blender/rig_keeper.py). Три фази:
		#   1 (100-60%): удар надгробком — три смуги тріщин віялом (перекотись
		#     крізь смугу); обертання ланцюгом — не підходь близько;
		#   2 (60-30%): відходить до стіни й відмикає саркофаги — 2 слизи й
		#     рубака; поки відмикає, не б'є;
		#   3 (<30%): ревом гасить факели (темно, видно лише ліхтар героя й
		#     свічки на плечі боса), б'є частіше й щоразу кидає свічку —
		#     вогняна пляма. Убив у темряві — факели спалахують знову.
		"boss": {"name": "Хранитель Склепів", "model": "res://assets/models/monsters/crypt_keeper.glb", "style": "keeper",
			"hp": 600.0, "damage": 16.0, "speed": 2.7, "height": 3.0, "xp": 30,
			"no_hazard_rain": true, "phase_thresholds": [0.6, 0.3], "darkness": true, "frenzy_cooldown": 0.65,
			"attack_anims": ["Weapon"], "candle_throw": {"radius": 1.0, "pool": 3.0, "damage": 0.4},
			"special_anims": {"crack_lines": ["Slam"], "chain_spin": ["Spin"]},
			"abilities": [
				{"id": "crack_lines", "cooldown": 7.0, "first": 3.0, "count": 3, "spread": 32.0, "length": 10.0, "width": 1.3, "windup": 1.1, "damage": 1.3},
				{"id": "chain_spin", "cooldown": 9.0, "first": 5.0, "trigger": 3.5, "radius": 3.2, "spin": 2.2, "damage": 0.5},
				{"id": "sarcophagi", "phase": 2, "until": 2, "cooldown": 18.0, "first": 0.6, "unlock": 3.0,
					"spawn": ["Склепний слиз", "Склепний слиз", "Орк-рубака"]},
			]},'''),
])
print("patched")
