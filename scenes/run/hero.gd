extends CharacterBody2D

## Герой. Керування — аналоговий джойстик від точки дотику: гравець
## притискає палець (або мишу — для тестів на ПК) і тягне в потрібну
## сторону, герой рухається в цьому напрямку з силою, пропорційною
## відстані відтягування. Зброя стріляє сама по найближчому ворогу.
##
## apply_upgrade() застосовує ефект апгрейду рівня: конкретні числа
## приросту за рівень (наприклад "+15% шкоди") живуть тут, а не в
## balance.gd, бо це не базові числа гри, а приріст апгрейду поверх
## них — сам факт "які апгрейди існують" описаний в data/upgrades/*.

signal died
signal leveled_up(levels_gained: int)
signal gold_collected(amount: int)

const JOYSTICK_MAX_RADIUS := 80.0   # відстань відтягування для 100% швидкості
const JOYSTICK_DEAD_ZONE := 4.0     # менші рухи ігноруються як тремтіння пальця

const ORBITAL_BLADE_SCENE := preload("res://scenes/run/orbital_blade.tscn")
const ORBITAL_RADIUS := 55.0
const ORBITAL_ANGULAR_SPEED := 2.5
const ORBITAL_DAMAGE := 8.0

const AURA_TICK_INTERVAL := 0.5
const AURA_BASE_RADIUS := 50.0
const AURA_RADIUS_PER_LEVEL := 15.0
const AURA_BASE_DAMAGE := 6.0
const AURA_DAMAGE_PER_LEVEL := 3.0

@onready var sprite: Polygon2D = $Sprite
@onready var hurt_box: Area2D = $HurtBox
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/PickupShape
@onready var magnet_area: Area2D = $MagnetArea
@onready var magnet_shape: CollisionShape2D = $MagnetArea/MagnetShape
@onready var damage_aura: Area2D = $DamageAura
@onready var damage_aura_shape: CollisionShape2D = $DamageAura/DamageAuraShape

var current_hp: float = Balance.HERO_MAX_HP
var max_hp: float = Balance.HERO_MAX_HP
var level := 1
var xp := 0
var upgrade_levels: Dictionary = {}   # StringName -> int, рівень кожного взятого апгрейду

var _move_direction := Vector2.ZERO
var _touch_active := false
var _touch_start := Vector2.ZERO
var _invulnerable := false
var _weapon_cooldown_left := 0.0
var _projectile_pool: ObjectPool

# Похідні від апгрейдів значення — перераховуються заново в apply_upgrade()
var _damage_multiplier := 1.0
var _cooldown_multiplier := 1.0
var _pierce_bonus := 0
var _extra_projectiles := 0
var _ricochet_count := 0
var _regen_per_second := 0.0
var _armor_flat_reduction := 0.0
var _iframe_bonus := 0.0
var _move_speed_multiplier := 1.0
var _pickup_radius_bonus := 0.0
var _magnet_radius_bonus := 0.0
var _gold_multiplier := 1.0
var _xp_multiplier := 1.0

# Мета-бонуси з GameState — виставляються один раз apply_meta_upgrades()
# на старті рану і додаються до відповідних множників у
# _recompute_derived_stats(), а не перезаписують їх.
var _meta_damage_percent := 0.0
var _meta_move_speed_percent := 0.0
var _meta_gold_percent := 0.0
var _meta_luck_percent := 0.0
var _meta_pickup_radius_bonus := 0.0

# Бонус конкретного героя (HeroDef.move_speed_percent) — окремо від
# мета-бонусу, теж додається в _recompute_derived_stats().
var _hero_move_speed_percent := 0.0

# Унікальні таланти (свій прогрес на кожного героя, GameState.hero_meta_levels).
var _meta_talent_bolt_pierce := 0
var _meta_talent_extra_blades := 0
var _meta_talent_aura_power := 0

var _orbital_blades: Array[Node] = []
var _aura_level := 0
var _aura_tick_left := 0.0

func _ready() -> void:
	pickup_area.area_entered.connect(_on_pickup_area_entered)

func setup(projectile_pool: ObjectPool) -> void:
	_projectile_pool = projectile_pool

## Викликається один раз на старті рану, до apply_meta_upgrades().
## Базовий магічний болт є в усіх героїв однаково — різницю робить
## стартовий бонус (HeroDef.bonus_weapon) і стати. Записуємо рівень
## бонус-зброї в upgrade_levels, щоб UpgradePool бачив її вже взятою
## (level 1) і міг далі пропонувати прокачати, а не "взяти вперше".
func apply_hero_def(def: HeroDef) -> void:
	sprite.color = def.color
	max_hp += def.bonus_max_hp
	current_hp = max_hp
	_hero_move_speed_percent = def.move_speed_percent
	match def.bonus_weapon:
		&"orbital_blades":
			upgrade_levels[&"orbital_blades"] = 1
			_rebuild_orbital_blades()
		&"damage_aura":
			upgrade_levels[&"damage_aura"] = 1
			_rebuild_aura()

## Викликається один раз на старті рану (run.gd), до того як гравець
## взяв хоч один апгрейд у рані. Мета-рівні йдуть з GameState.
func apply_meta_upgrades(meta_levels: Dictionary) -> void:
	var hp_level: int = meta_levels.get(&"meta_max_hp", 0)
	var start_level: int = meta_levels.get(&"meta_start_level", 0)

	max_hp += 10.0 * hp_level
	current_hp = max_hp
	level = 1 + start_level

	_meta_damage_percent = 0.05 * meta_levels.get(&"meta_damage", 0)
	_meta_move_speed_percent = 0.03 * meta_levels.get(&"meta_move_speed", 0)
	_meta_gold_percent = 0.07 * meta_levels.get(&"meta_gold_gain", 0)
	_meta_luck_percent = 0.04 * meta_levels.get(&"meta_luck", 0)
	_meta_pickup_radius_bonus = 8.0 * meta_levels.get(&"meta_pickup_radius", 0)

	_meta_talent_bolt_pierce = meta_levels.get(&"talent_bolt_pierce", 0)
	_meta_talent_extra_blades = meta_levels.get(&"talent_extra_blades", 0)
	_meta_talent_aura_power = meta_levels.get(&"talent_aura_power", 0)

	_recompute_derived_stats()
	_update_pickup_shapes()
	_rebuild_orbital_blades()
	_rebuild_aura()

	# "Стартовий рівень" — це не просто вище число, а реальні "безкоштовні"
	# рівні: гравець одразу вибирає апгрейд за кожен з них, так само як
	# при звичайному левел-апі, і аж потім починає збирати XP далі.
	if start_level > 0:
		leveled_up.emit(start_level)

## "Удача" з мета-прогресії — підмішує шанс, що на левел-апі
## запропонують уже взяту нову зброю (UpgradePool).
func get_luck_bonus() -> float:
	return _meta_luck_percent

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		_touch_active = event.pressed
		if event.pressed:
			_touch_start = event.position
		else:
			_move_direction = Vector2.ZERO
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _touch_active:
		var offset: Vector2 = event.position - _touch_start
		var distance := offset.length()
		if distance > JOYSTICK_DEAD_ZONE:
			_move_direction = offset.normalized() * clampf(distance / JOYSTICK_MAX_RADIUS, 0.0, 1.0)
		else:
			_move_direction = Vector2.ZERO

func _physics_process(delta: float) -> void:
	velocity = _get_move_direction() * Balance.HERO_MOVE_SPEED * _move_speed_multiplier
	move_and_slide()
	_process_weapon(delta)
	_process_contact_damage()
	_process_regen(delta)
	_process_magnet(delta)
	_process_aura(delta)

## Стрілки — для зручного тестування на ПК, паралельно з джойстиком
## від дотику/миші (ui_left/right/up/down — вбудовані дії Godot,
## змінювати InputMap не треба). Якщо стрілки не натиснуті — керує
## звичайний джойстик.
func _get_move_direction() -> Vector2:
	var keyboard_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if keyboard_direction != Vector2.ZERO:
		return keyboard_direction
	return _move_direction

func _process_weapon(delta: float) -> void:
	_weapon_cooldown_left -= delta
	if _weapon_cooldown_left > 0.0:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	_fire_at(target)
	_weapon_cooldown_left = Balance.WEAPON_COOLDOWN * _cooldown_multiplier

func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.visible:
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest

func _fire_at(target: Node2D) -> void:
	if _projectile_pool == null:
		return
	var base_direction := global_position.direction_to(target.global_position)
	var shots := 1 + _extra_projectiles
	var spread := deg_to_rad(12.0)
	var damage := Balance.WEAPON_DAMAGE * _damage_multiplier
	var pierce := Balance.WEAPON_PIERCE + _pierce_bonus
	for i in shots:
		var angle_offset := 0.0
		if shots > 1:
			angle_offset = spread * (i - float(shots - 1) / 2.0)
		var direction := base_direction.rotated(angle_offset)
		var projectile: Node = _projectile_pool.acquire()
		projectile.spawn(global_position, direction, damage, pierce, _ricochet_count)

## Поки герой торкається ворога і не в i-фреймах — щоразу після
## закінчення невразливості contact-урон застосовується знову.
func _process_contact_damage() -> void:
	if _invulnerable:
		return
	for body in hurt_box.get_overlapping_bodies():
		if body.has_method("get_contact_damage"):
			take_damage(body.get_contact_damage())
			break

func _process_regen(delta: float) -> void:
	if _regen_per_second <= 0.0 or current_hp <= 0.0:
		return
	current_hp = minf(current_hp + _regen_per_second * delta, max_hp)

## Кристали в радіусі магніту самі летять до героя, а не чекають,
## поки герой підійде впритул до радіуса підбору.
func _process_magnet(delta: float) -> void:
	for area in magnet_area.get_overlapping_areas():
		if area.has_method("pull_toward"):
			area.pull_toward(global_position, delta)

func _process_aura(delta: float) -> void:
	if _aura_level <= 0:
		return
	_aura_tick_left -= delta
	if _aura_tick_left > 0.0:
		return
	_aura_tick_left = AURA_TICK_INTERVAL
	var damage := AURA_BASE_DAMAGE + AURA_DAMAGE_PER_LEVEL * (_aura_level - 1)
	for body in damage_aura.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage)

## Потрібен снарядам ворога-лучника й вибуху павука-підривника, щоб
## теж поважати i-фрейми, а не бити героя в обхід невразливості.
func is_invulnerable() -> bool:
	return _invulnerable

func take_damage(amount: float) -> void:
	# Вже мертвий — ігноруємо: кілька ударів в один кадр інакше
	# еміттили б died кілька разів (і відкривали кілька вікон воскресіння).
	if current_hp <= 0.0:
		return
	var actual_damage := maxf(1.0, amount - _armor_flat_reduction)
	current_hp -= actual_damage
	if current_hp <= 0.0:
		current_hp = 0.0
		set_physics_process(false)
		died.emit()
	else:
		_start_iframes(Balance.HERO_IFRAMES + _iframe_bonus)

## Воскресіння за rewarded-рекламу: частина HP і довша невразливість,
## щоб рій довкола не вбив героя в перший же кадр.
func revive() -> void:
	current_hp = max_hp * Balance.REVIVE_HP_FRACTION
	set_physics_process(true)
	_start_iframes(Balance.REVIVE_IFRAMES)

func _start_iframes(duration: float) -> void:
	_invulnerable = true
	modulate.a = 0.5
	await get_tree().create_timer(duration).timeout
	_invulnerable = false
	modulate.a = 1.0

func _on_pickup_area_entered(area: Area2D) -> void:
	if not area.has_method("collect"):
		return
	var result: Dictionary = area.collect()
	add_xp(result.xp)
	gold_collected.emit(int(round(result.gold * _gold_multiplier)))

func add_xp(amount: int) -> void:
	xp += int(round(amount * _xp_multiplier))
	var levels_gained := 0
	while xp >= Balance.xp_to_next(level):
		xp -= Balance.xp_to_next(level)
		level += 1
		levels_gained += 1
	if levels_gained > 0:
		leveled_up.emit(levels_gained)

func get_upgrade_level(id: StringName) -> int:
	return upgrade_levels.get(id, 0)

## Застосовує наступний рівень апгрейду id. Викликається один раз на
## кожен вибір гравця на екрані левел-апу (run.gd, після кліку картки).
func apply_upgrade(id: StringName) -> void:
	var new_level: int = get_upgrade_level(id) + 1
	upgrade_levels[id] = new_level
	match id:
		&"weapon_cooldown":
			_cooldown_multiplier = clampf(1.0 - 0.1 * new_level, 0.4, 1.0)
		&"weapon_multishot":
			_extra_projectiles = new_level
		&"weapon_ricochet":
			_ricochet_count = new_level
		&"max_hp":
			var added := 20.0
			max_hp += added
			current_hp += added
		&"regen":
			_regen_per_second = 0.5 * new_level
		&"armor":
			_armor_flat_reduction = 1.0 * new_level
		&"iframe_duration":
			_iframe_bonus = 0.1 * new_level
		&"pickup_radius":
			_pickup_radius_bonus = 20.0 * new_level
			_update_pickup_shapes()
		&"xp_gain":
			_xp_multiplier = 1.0 + 0.15 * new_level
		&"crystal_magnet":
			_magnet_radius_bonus = 40.0 * new_level
			_update_pickup_shapes()
		&"orbital_blades":
			_rebuild_orbital_blades()
		&"damage_aura":
			_rebuild_aura()
		&"weapon_damage", &"weapon_pierce", &"move_speed", &"gold_gain":
			pass   # рахуються нижче в _recompute_derived_stats()
	_recompute_derived_stats()

## Шкода/швидкість/золото залежать одразу з двох джерел — мета-бонусу
## (раз на весь ран, з apply_meta_upgrades) і апгрейду цього рану —
## тож рахуємо їх тут заново з обох, а не в окремих гілках match вище,
## щоб один не перезаписував інший.
func _recompute_derived_stats() -> void:
	_damage_multiplier = 1.0 + 0.15 * get_upgrade_level(&"weapon_damage") + _meta_damage_percent
	_move_speed_multiplier = 1.0 + 0.08 * get_upgrade_level(&"move_speed") + _meta_move_speed_percent + _hero_move_speed_percent
	_gold_multiplier = 1.0 + 0.15 * get_upgrade_level(&"gold_gain") + _meta_gold_percent
	_pierce_bonus = get_upgrade_level(&"weapon_pierce") + _meta_talent_bolt_pierce

func _update_pickup_shapes() -> void:
	var radius := Balance.HERO_PICKUP_RADIUS + _pickup_radius_bonus + _meta_pickup_radius_bonus
	(pickup_shape.shape as CircleShape2D).radius = radius
	(magnet_shape.shape as CircleShape2D).radius = radius + _magnet_radius_bonus

## Кількість клинків = рівень апгрейду цього рану + талант героя
## (Клинкова Вартова: "Вихор Клинків"). Перебудовує всі клинки заново,
## щоб рівномірно розподілити кут між ними — простіше, ніж
## дораховувати кут лише для нового клинка.
func _rebuild_orbital_blades() -> void:
	var total_level := get_upgrade_level(&"orbital_blades") + _meta_talent_extra_blades
	for blade in _orbital_blades:
		blade.queue_free()
	_orbital_blades.clear()
	if total_level <= 0:
		return
	for i in total_level:
		var blade: Node = ORBITAL_BLADE_SCENE.instantiate()
		add_child(blade)
		var angle_offset := TAU / float(total_level) * i
		blade.setup(self, ORBITAL_RADIUS, angle_offset, ORBITAL_ANGULAR_SPEED, ORBITAL_DAMAGE)
		_orbital_blades.append(blade)

## Рівень аури = рівень апгрейду цього рану + талант героя
## (Ember Priestess: "Багаття Люті").
func _rebuild_aura() -> void:
	var total_level := get_upgrade_level(&"damage_aura") + _meta_talent_aura_power
	_aura_level = total_level
	if total_level <= 0:
		damage_aura_shape.disabled = true
		return
	damage_aura_shape.disabled = false
	(damage_aura_shape.shape as CircleShape2D).radius = AURA_BASE_RADIUS + AURA_RADIUS_PER_LEVEL * (total_level - 1)
