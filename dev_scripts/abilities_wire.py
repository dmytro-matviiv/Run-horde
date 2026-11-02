import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:80])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


# ------------------------------------------------------------ Enemy3D
edit('scenes/dungeon/enemy_3d.gd', [
('''## Бос-закликач просить данж привести йому підмогу.
signal summon_requested(position: Vector3, count: int)
''', '''## Бос-закликач просить данж привести йому підмогу.
signal summon_requested(position: Vector3, count: int)
## Здібність просить данж створити істоту (мерці некроманта, половинки
## слизу, пілони боса). source — хто кличе (рахує своїх живих), або null.
signal spawn_requested(position: Vector3, definition: Dictionary, source: Enemy3D)
## Бос утратив захист пілонів — данж покаже напис.
signal ward_broken
'''),
('''## Фази боса (лише в боса).
var phases: BossPhases
''', '''## Фази боса (лише в боса).
var phases: BossPhases
## Опис ворога з рівня (здібності беруть із нього налаштування).
var definition: Dictionary = {}
## Здібності (EnemyAbility): мерехтіння, кидки, павутина, тотем...
var abilities: Array[EnemyAbility] = []
## Тотем: стоїть на місці й сам не б'є.
var stationary := false
## Скільки живих істот, яких покликав цей ворог.
var summons_alive := 0
var _hidden := false
var _ward_factor := 1.0
var _ward_until := 0
## Пофарбовані матеріали моделей (тон і світіння з опису ворога).
static var _painted: Dictionary = {}
'''),
('''func configure(definition: Dictionary, hp_scale: float, damage_scale: float) -> void:
	display_name = definition.get("name", "")
	match String(definition.get("kind", "melee")):''', '''func configure(source: Dictionary, hp_scale: float, damage_scale: float) -> void:
	definition = source
	display_name = definition.get("name", "")
	abilities = EnemyAbilities.create_all(self, definition.get("abilities", []))
	match String(definition.get("kind", "melee")):'''),
('''		"boss":
			kind = Kind.BOSS
		_:
			kind = Kind.MELEE
	max_hp = float(definition.get("hp", max_hp)) * hp_scale''', '''		"boss":
			kind = Kind.BOSS
		"totem":
			kind = Kind.MELEE
			stationary = true
			attack_range = 0.0
			aggro_range = 30.0
		_:
			kind = Kind.MELEE
	max_hp = float(definition.get("hp", max_hp)) * hp_scale'''),
('''func configure_boss(definition: Dictionary, hp_scale: float, damage_scale: float) -> void:
	configure(definition, hp_scale, damage_scale)''', '''func configure_boss(source: Dictionary, hp_scale: float, damage_scale: float) -> void:
	configure(source, hp_scale, damage_scale)'''),
('''	_model = model_scene.instantiate()
	add_child(_model)
	_normalize_size()''', '''	_model = model_scene.instantiate()
	add_child(_model)
	paint_model(_model, definition.get("tint", Color.WHITE), definition.get("glow", Color.BLACK))
	_normalize_size()'''),
('''func is_alive() -> bool:
	return not _dying
''', '''func is_alive() -> bool:
	return not _dying

## Перефарбувати модель: tint множить колір, glow — світіння. Так із
## однієї моделі виходять різні істоти (вогняний біс, золотий вартовий).
## Матеріали кешуються: однаково пофарбовані вороги ділять їх.
static func paint_model(model: Node, tint: Color, glow: Color) -> void:
	if tint == Color.WHITE and glow == Color.BLACK:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in mesh.get_surface_override_material_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var key := "%d|%s|%s" % [source.get_rid().get_id(), tint.to_html(), glow.to_html()]
			if not _painted.has(key):
				var painted := source.duplicate() as StandardMaterial3D
				painted.albedo_color = source.albedo_color * tint
				if glow != Color.BLACK:
					painted.emission_enabled = true
					painted.emission = glow
					painted.emission_energy_multiplier = 1.0
				_painted[key] = painted
			mesh.set_surface_override_material(surface, _painted[key])

# --- для здібностей (EnemyAbility) ---

func get_player() -> Node3D:
	return _player

func begin_special(special: String, windup: float, color: Color, radius: float) -> void:
	_begin_special(special, windup, color, radius)

func face_player(speed: float) -> void:
	_face_player(speed)

func play_once(candidates: Array) -> void:
	_play_once(candidates)

func hold_still(seconds: float) -> void:
	_hold_still(seconds)

func sees_player() -> bool:
	return _sees_player()

func teleport_to(point: Vector3) -> void:
	global_position = point + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	_repath_left = 0.0

## Одразу замахнутись (після мерехтіння за спину героя).
func strike_now(windup: float) -> void:
	_attack_left = 0.0
	_face_player(100.0)
	_begin_windup()
	if _windup_left > 0.0:
		_windup_total = windup
		_windup_left = windup

## Сховатись (під землю, у дим): не видно, не вдарити, приціл не бачить.
func set_hidden(hidden: bool) -> void:
	_hidden = hidden
	_model.visible = not hidden
	collision_layer = 0 if hidden else 4
	if _health_bar != null:
		_health_bar.visible = not hidden and (elite != null or kind == Kind.BOSS or current_hp < max_hp)
	if hidden:
		_cancel_windup()

func is_hidden() -> bool:
	return _hidden

## Захист тотема: поки нитка тримається, проходить лише частка шкоди.
func apply_ward(factor: float, seconds: float) -> void:
	_ward_factor = factor
	_ward_until = Time.get_ticks_msec() + int(seconds * 1000.0)

func is_warded() -> bool:
	return Time.get_ticks_msec() < _ward_until

## Снаряд здібності (павутина, коло снарядів боса). on_hit — що ще
## зробити з героєм, коли влучив (сповільнити).
func spawn_shot(origin: Vector3, direction: Vector3, color: Color, speed: float, shot_damage: float,
		on_hit: Callable = Callable()) -> EnemyProjectile:
	var shot := EnemyProjectile.create(shot_damage, color, speed)
	shot.on_hit = on_hit
	get_parent().add_child(shot)
	shot.global_position = origin
	shot.set_charge(1.0)
	shot.launch(direction, _player, get_parent())
	return shot
'''),
('''## Чи наводиться сюди приціл: автоприціл героя й самонавідні чари.
## Вибухова бочка — "ворог" лише для ударів, переслідувати її не треба.
func is_aim_target() -> bool:
	return not _dying''', '''## Чи наводиться сюди приціл: автоприціл героя й самонавідні чари.
## Вибухова бочка — "ворог" лише для ударів, переслідувати її не треба;
## ворога під землею не видно.
func is_aim_target() -> bool:
	return not _dying and not _hidden'''),
('''func _physics_process(delta: float) -> void:
	if _dying or _player == null:
		return
''', '''func _physics_process(delta: float) -> void:
	if _dying or _player == null:
		return
	# Здібності рахують перезарядку щокроку, а зайнята (під землею, у
	# стрибку, у тумані) сама веде ворога.
	for ability in abilities:
		ability.tick(delta)
	for ability in abilities:
		if ability.is_busy():
			return
	if stationary:
		_process_stationary(delta)
		return
'''),
('''	elif _aggro:
		match kind:''', '''	elif _aggro and _use_abilities(distance):
		pass
	elif _aggro:
		match kind:'''),
('''## Рух ворога.
##
## move_and_slide() — найдорожча річ''', '''## Здібність бере хід, коли ворог вільний, не на перезарядці удару й
## бачить героя (що саме потрібно — вирішує сама здібність).
func _use_abilities(distance: float) -> bool:
	if abilities.is_empty() or _attack_left > 0.0:
		return false
	for ability in abilities:
		if ability.ready_to_use() and ability.try_use(distance):
			return true
	return false

## Тотем стоїть на місці: лише падає на підлогу, якщо з'явився трохи вище.
func _process_stationary(delta: float) -> void:
	if not _grounded:
		velocity.y -= GRAVITY * delta
		_move(delta)
	_play("Idle")

## Рух ворога.
##
## move_and_slide() — найдорожча річ'''),
('''	_windup_left = 0.0
	_attack_left = attack_cooldown
	_hide_telegraph()
	if kind == Kind.RANGED:
		_release_shot()
		return''', '''	_windup_left = 0.0
	_attack_left = attack_cooldown
	_hide_telegraph()
	for ability in abilities:
		if ability.id == _special:
			_special = ""
			ability.resolve()
			return
	if kind == Kind.RANGED:
		_release_shot()
		return'''),
('''	if _dying:
		return
	# Щит еліти спереду пропускає лише частину шкоди.
	if elite != null:
		amount *= elite.damage_factor(heavy)''', '''	if _dying or _hidden:
		return
	# Щит еліти спереду пропускає лише частину шкоди, тотем — ще менше.
	if elite != null:
		amount *= elite.damage_factor(heavy)
	if is_warded():
		amount *= _ward_factor
		if stationary or knockback != Vector3.ZERO:
			knockback = Vector3.ZERO
	if stationary:
		knockback = Vector3.ZERO'''),
('''func _die() -> void:
	if elite != null:
		elite.on_death()''', '''func _die() -> void:
	if elite != null:
		elite.on_death()
	for ability in abilities:
		ability.on_death()'''),
])

# ------------------------------------------------------------ снаряд
edit('scenes/combat/enemy_projectile.gd', [
('''var _target: Node3D
var _core: MeshInstance3D
''', '''var _target: Node3D
var _core: MeshInstance3D
## Що ще зробити з героєм, коли влучив (павутина сповільнює).
var on_hit: Callable
'''),
('''		if chest.distance_to(global_position) < HIT_RADIUS and _target.take_damage(damage):
			_burst(global_position)
			return''', '''		if chest.distance_to(global_position) < HIT_RADIUS and _target.take_damage(damage):
			if on_hit.is_valid():
				on_hit.call(_target)
			_burst(global_position)
			return'''),
])

# ------------------------------------------------------------ герой: сповільнення й куди дивиться
edit('scenes/world/player_3d.gd', [
('''## Тимчасовий множник шкоди (серія ударів у данжі).
var _bonus_damage := 1.0
var _bonus_damage_left := 0.0
''', '''## Тимчасовий множник шкоди (серія ударів у данжі).
var _bonus_damage := 1.0
var _bonus_damage_left := 0.0
## Сповільнення (павутина): частка швидкості й скільки ще діє.
var _slow_factor := 1.0
var _slow_left := 0.0
var _slow_marker: MeshInstance3D
'''),
('''## Тимчасово сильніші удари (серія ударів у данжі).''', '''## Куди дивиться герой (на підлозі) — ворог, що мерехтить, стає за спину.
func get_facing() -> Vector3:
	return _facing_vector()

## Павутина: герой повільніший кілька секунд, під ним біле коло.
## Перекат не сповільнюється — ним і вириваються.
func apply_slow(factor: float, seconds: float) -> void:
	_slow_factor = minf(_slow_factor, factor) if _slow_left > 0.0 else factor
	_slow_left = maxf(_slow_left, seconds)
	CombatVfx.flash_model(model, Color(0.9, 0.95, 1.0), 0.15)
	if _slow_marker == null:
		_slow_marker = CombatVfx.make_ground_marker(Color(0.92, 0.92, 1.0, 0.7), 0.8)
		_slow_marker.set_instance_shader_parameter(&"progress", 1.0)
		_slow_marker.position.y = 0.05
		add_child(_slow_marker)
	_slow_marker.visible = true

func is_slowed() -> bool:
	return _slow_left > 0.0

## Тимчасово сильніші удари (серія ударів у данжі).'''),
('''	_bonus_damage_left = maxf(_bonus_damage_left - delta, 0.0)
''', '''	_bonus_damage_left = maxf(_bonus_damage_left - delta, 0.0)
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_factor = 1.0
			if _slow_marker != null:
				_slow_marker.visible = false
'''),
('''	var factor := 1.0 + _speed_bonus + (_concealed_speed if _concealed_left > 0.0 else 0.0) \\
		+ (SHRINE_HASTE_SPEED if _has_shrine(&"haste") else 0.0)''', '''	var factor := 1.0 + _speed_bonus + (_concealed_speed if _concealed_left > 0.0 else 0.0) \\
		+ (SHRINE_HASTE_SPEED if _has_shrine(&"haste") else 0.0)
	if _slow_left > 0.0:
		factor *= _slow_factor'''),
])
print('ok')
