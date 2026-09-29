extends CharacterBody3D
class_name Enemy3D

## Ворог у данжі.
##
## 1. НЕ ПРОХОДИТЬ КРІЗЬ СТІНИ — справжнє фізичне тіло, рух через
##    move_and_slide(), а не телепортацією до героя.
## 2. НЕ ТУПИЙ І НЕ ЗАСТРЯГАЄ — шлях рахує NavigationAgent3D по карті
##    прохідності. Зайшов за ріг — ворог обходить кут, а не стоїть носом
##    у стіну.
## 3. НЕ Б'Є Й НЕ СТРІЛЯЄ КРІЗЬ СТІНИ — перед ударом перевіряє, чи
##    бачить героя.
##
## БІЙ, ЯКИЙ МОЖНА ЧИТАТИ Й ОБІГРАВАТИ:
##  - Перед ударом ворог ЗАМАХУЄТЬСЯ: на підлозі з'являється червона
##    зона, яка заповнюється до моменту удару. Вийшов із неї чи зробив
##    перекат — удар пройшов повз.
##  - Бос кожен третій удар б'є об землю: велике коло навколо себе.
##  - Стрілець пускає видимий снаряд, від якого можна ухилитись; підійшов
##    упритул — він відступає, щоб тримати дистанцію.
##  - Удар героя відкидає ворога, а сильний (удар ногою, вихор) ще й
##    збиває замах — агресивна гра винагороджується.
##
## ЕКОНОМІЯ НА СЛАБКИХ ТЕЛЕФОНАХ (гравцеві непомітна): маршрут і
## видимість рахуються кілька разів на секунду з розсинхроном між
## ворогами; анімація поза кадром на паузі, удалині — через кадр; ворог
## без діла не рахує фізику руху.

signal died(position: Vector3, xp_reward: int)
## Бос-закликач просить данж привести йому підмогу.
signal summon_requested(position: Vector3, count: int)
## Здібність просить данж створити істоту (мерці некроманта, половинки
## слизу, пілони боса). source — хто кличе (рахує своїх живих), або null.
signal spawn_requested(position: Vector3, definition: Dictionary, source: Enemy3D)
## Бос утратив захист пілонів — данж покаже напис.
signal ward_broken

## MELEE — б'є впритул, RANGED — стріляє, BOSS — бос, EXPLODER — біжить
## до героя й вибухає, CHARGER — розганяється по прямій.
## Голем — це MELEE з tank = true.
enum Kind {MELEE, RANGED, BOSS, EXPLODER, CHARGER}

const HEALTH_BAR_SCRIPT := preload("res://scenes/dungeon/health_bar_3d.gd")

## Колір смужки ворога. Бос отримує ту саму, але помітнішу.
const ENEMY_BAR_COLOR := Color(0.95, 0.25, 0.25)
const TELEGRAPH_COLOR := Color(1.0, 0.22, 0.15, 0.85)
const SLAM_COLOR := Color(1.0, 0.45, 0.1, 0.9)
const HIT_COLOR := Color(1.0, 0.95, 0.8)
const HEAVY_HIT_COLOR := Color(1.0, 0.65, 0.25)
## ЕЛІТА (EliteAffixes): у скільки разів більше здоров'я, шкоди, зросту
## й досвіду; смужка здоров'я золота.
const ELITE_HP := 2.2
const ELITE_DAMAGE := 1.25
const ELITE_SIZE := 1.25
const ELITE_XP := 4
const ELITE_BAR_COLOR := Color(1.0, 0.78, 0.3)

## Смерть: блідо-блакитні іскри й хвиля ("душа розвіюється") — не
## помаранчеві, щоб не плутати з червоними зонами замаху. Тіло лежить,
## поки дограє анімація, а тоді провалюється під підлогу.
const DEATH_COLOR := Color(0.78, 0.88, 1.0)
const DEATH_LINGER := 1.2
const SINK_TIME := 0.6

const GRAVITY := 20.0

const REPATH_INTERVAL := 0.3
const SIGHT_INTERVAL := 0.2

## Як швидко гасне відкидання (м/с за секунду).
const KNOCKBACK_DECAY := 28.0

## Замах: скільки секунд від початку до удару. Саме стільки гравець має,
## щоб вийти з червоної зони.
const MELEE_WINDUP := 0.55
const RANGED_WINDUP := 0.5
const BOSS_WINDUP := 0.75
const SLAM_WINDUP := 1.0
const SLAM_RADIUS := 3.6
const SLAM_EVERY := 3
## Ідеальний перекат: герой почав перекат у червоній зоні не раніше, ніж
## за стільки секунд до удару, — і вискочив.
const LATE_DODGE_WINDOW := 0.3

## Під час замаху ворог повільно довертається за героєм — достатньо, щоб
## влучити в того, хто стоїть, але не в того, хто відскочив убік.
const WINDUP_TURN_SPEED := 2.5

## Стрілець тримається не ближче за це.
const RANGED_MIN_DISTANCE := 3.5

## ВИБУХОВИЙ: підбіг — запалює ґніт (коло на підлозі), за мить вибухає.
## Убив раніше — вибуху не буде: це й є спосіб грати проти нього.
const FUSE_DISTANCE := 2.2
const FUSE_TIME := 0.95
const EXPLODE_RADIUS := 3.0
const EXPLODE_COLOR := Color(1.0, 0.55, 0.15, 0.9)

## ТАРАН: показує смугу, куди розженеться, і мчить по ній. Ухилитись —
## крок убік. Врізався в стіну — довше оговтується.
const CHARGE_WINDUP := 0.85
const CHARGE_SPEED := 13.0
const CHARGE_TIME := 0.7
const CHARGE_RECOVER := 1.0
const CHARGE_WALL_STUN := 1.6
const CHARGE_MIN_DISTANCE := 3.5
const CHARGE_MAX_DISTANCE := 13.0
const CHARGE_COLOR := Color(1.0, 0.3, 0.2, 0.85)

## Боси.
const SUMMON_COOLDOWN := 9.0
const SUMMON_COUNT := 3
const SUMMON_COLOR := Color(0.5, 1.0, 0.4, 0.9)
const VOLLEY_COOLDOWN := 5.0
const DRAGON_CHARGE_COOLDOWN := 7.5

## Чари героя: іней під сповільненим ворогом і крижана брила навколо
## замороженого.
const FROST_COLOR := Color(0.55, 0.85, 1.0, 0.9)
const ICE_COLOR := Color(0.72, 0.92, 1.0, 0.42)

static var _ice_material: StandardMaterial3D

@export var kind: Kind = Kind.MELEE
@export var max_hp := 30.0
@export var damage := 8.0
@export var move_speed := 2.8
@export var xp_reward := 3

## Радіус, у якому ворог помічає героя, і більший радіус, у якому вже
## не втрачає його з поля зору.
@export var aggro_range := 11.0
@export var leash_range := 24.0

@export var attack_range := 2.2
@export var attack_cooldown := 1.4

## Звідки "дивиться" стрілець, коли перевіряє видимість цілі.
@export var eye_height := 1.2

## Зріст ворога на екрані в метрах. Моделі з різних наборів приходять
## у зовсім різному масштабі, тож приводимо кожну до потрібного розміру.
@export var target_height := 1.7

## Налаштування з опису рівня (DungeonLevels), див. configure().
var display_name := ""
## Риси еліти; null — звичайний ворог.
var elite: EliteAffixes
## Фази боса (лише в боса).
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
## Ворог за ґратами засідки: поки вона триває, героя він не помічає — не
## біжить до ґраток і не збирається там юрбою, а після бою не вривається
## в залу всією кімнатою. Вмикає й вимикає данж.
var shut_out := false
var tank := false
var slam_every := 0
var boss_style := "demon"
## Скільки метрів ворог ширяє над землею (летючі істоти).
var hover := 0.0
var projectile_color := Color(0.75, 0.35, 1.0)
var projectile_speed := 10.0
var volley := 1

var _fuse_left := -1.0
var _flash_left := 0.0
## 0 — нічого, 1 — прицілюється, 2 — мчить, 3 — оговтується.
var _charge_state := 0
var _charge_left := 0.0
var _charge_dir := Vector3.ZERO
var _charge_hit := false
var _summon_left := 4.0
var _volley_left := 3.0
var _dragon_charge_left := 5.0
var _special := ""

var current_hp := 0.0
var _player: Node3D
var _agent: NavigationAgent3D
var _model: Node3D
var _animation: AnimationPlayer
var _attack_left := 0.0
var _aggro := false
var _dying := false
var _health_bar: HealthBar3D
var _sleeping := false

var _repath_left := 0.0
var _sight_left := 0.0
var _can_see := false
var _on_screen := true
var _animation_step := 1
var _animation_frame := 0
var _animation_time := 0.0
var _animation_cache: Dictionary = {}

var _knockback := Vector3.ZERO
var _stagger_left := 0.0
var _slow_factor := 1.0
var _slow_left := 0.0
var _frozen_left := 0.0
var _frost_marker: MeshInstance3D
var _ice_block: MeshInstance3D
var _windup_left := 0.0
var _windup_total := 0.0
var _windup_slam := false
var _attack_counter := 0
var _telegraph: MeshInstance3D
var _charging_shot: EnemyProjectile

## Стоїть на підлозі (після першого приземлення). Поки так, ворог, що
## йде маршрутом, рухається без фізики — див. _move().
var _grounded := false
var _path_step := false

## Налаштовує ворога за описом із DungeonLevels. Викликати ДО того, як
## ворога додано в сцену: від цих чисел залежать смужка здоров'я й
## дальність, на якій він зупиняється.
func configure(source: Dictionary, hp_scale: float, damage_scale: float) -> void:
	definition = source
	display_name = definition.get("name", "")
	abilities = EnemyAbilities.create_all(self, definition.get("abilities", []))
	match String(definition.get("kind", "melee")):
		"ranged":
			kind = Kind.RANGED
			attack_range = 9.0
			aggro_range = 16.0
		"exploder":
			kind = Kind.EXPLODER
			aggro_range = 13.0
			attack_range = FUSE_DISTANCE
		"charger":
			kind = Kind.CHARGER
			aggro_range = 15.0
		"tank":
			kind = Kind.MELEE
			tank = true
			slam_every = 3
			attack_range = 2.6
		"boss":
			kind = Kind.BOSS
		"totem":
			kind = Kind.MELEE
			stationary = true
			attack_range = 0.0
			aggro_range = 30.0
		_:
			kind = Kind.MELEE
	max_hp = float(definition.get("hp", max_hp)) * hp_scale
	damage = float(definition.get("damage", damage)) * damage_scale
	move_speed = float(definition.get("speed", move_speed))
	target_height = float(definition.get("height", target_height))
	hover = float(definition.get("hover", 0.0))
	xp_reward = int(definition.get("xp", xp_reward))
	attack_cooldown = float(definition.get("cooldown", attack_cooldown))
	attack_range = float(definition.get("attack_range", attack_range))
	if definition.has("projectile"):
		var shot: Dictionary = definition.projectile
		projectile_color = shot.get("color", projectile_color)
		projectile_speed = float(shot.get("speed", projectile_speed))
		volley = int(shot.get("volley", 1))

## Зробити ворога елітним (до setup: зріст і здоров'я вже інші).
func make_elite(affix_list: Array) -> void:
	elite = EliteAffixes.new()
	for affix in affix_list:
		elite.affixes.append(int(affix))
	max_hp *= ELITE_HP
	damage *= ELITE_DAMAGE
	target_height *= ELITE_SIZE
	xp_reward *= ELITE_XP
	if elite.has(EliteAffixes.Affix.SWIFT):
		move_speed *= 1.5
		attack_cooldown *= 0.65

## Бос: окремі числа й свій набір прийомів.
func configure_boss(source: Dictionary, hp_scale: float, damage_scale: float) -> void:
	configure(source, hp_scale, damage_scale)
	kind = Kind.BOSS
	boss_style = String(definition.get("style", "demon"))
	# Перші прийоми — невдовзі після того, як бос помітив героя.
	_volley_left = 2.0
	_dragon_charge_left = 3.5
	_summon_left = 3.0
	aggro_range = 18.0
	attack_range = 3.0
	slam_every = 3

func setup(player: Node3D, model_scene: PackedScene) -> void:
	_player = player
	_model = model_scene.instantiate()
	add_child(_model)
	paint_model(_model, definition.get("tint", Color.WHITE), definition.get("glow", Color.BLACK))
	_normalize_size()
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation = players[0]
		_loop(["Idle", "Walk", "Run", "Flying_Idle", "Fast_Flying"])
		# Анімацію крутимо самі (див. _process): так її можна оновлювати
		# рідше або ставити на паузу, коли ворога не видно.
		_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_add_health_bar()
	_add_screen_notifier()
	if elite != null:
		add_child(elite)
		elite.attach(self, _player)
	if kind == Kind.BOSS:
		phases = BossPhases.new()
		add_child(phases)
		phases.attach(self, _player)

func is_alive() -> bool:
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

## Куди дивиться ворог (кут повороту моделі й напрямок на підлозі).
func facing_angle() -> float:
	return _model.rotation.y

func facing_vector() -> Vector3:
	return _model_forward()

func is_sleeping() -> bool:
	return _sleeping

## Чи помітив ворог героя (бос — чи почався бій).
func is_aggro() -> bool:
	return _aggro and not _dying

## Відновити здоров'я (цілитель-еліта лікує сусідів).
func heal(amount: float) -> void:
	if _dying:
		return
	current_hp = minf(current_hp + amount, max_hp)
	if _health_bar != null:
		_health_bar.set_ratio(current_hp / max_hp)

## Помітити героя одразу, хоч би де він був (засідка).
func alert() -> void:
	_aggro = true
	_repath_left = 0.0

## Вилізти з-під підлоги (засідка): модель підіймається з порталу, а
## ворог тим часом стоїть і не б'є. Потім одразу йде на героя.
func emerge(seconds: float) -> void:
	var rest := _model.position.y
	_model.position.y = rest - target_height - 0.3
	var tween := create_tween()
	tween.tween_property(_model, "position:y", rest, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hold_still(seconds)
	alert()

## Чи наводиться сюди приціл: автоприціл героя й самонавідні чари.
## Вибухова бочка — "ворог" лише для ударів, переслідувати її не треба;
## ворога під землею не видно.
func is_aim_target() -> bool:
	return not _dying and not _hidden

## Смужка висить трохи вище за голову й ширшає разом із розміром ворога.
func _add_health_bar() -> void:
	_health_bar = HEALTH_BAR_SCRIPT.new()
	add_child(_health_bar)
	var is_boss := kind == Kind.BOSS
	var color := ELITE_BAR_COLOR if elite != null else ENEMY_BAR_COLOR
	_health_bar.setup(color, target_height + hover + 0.45, is_boss or elite != null, 1.0 if not is_boss else 1.8)

## Масштабує модель так, щоб її висота дорівнювала target_height.
##
## Габарити рахуємо у СВІТОВИХ координатах і переводимо в систему
## моделі: у моделей зі скелетом меш лежить у системі кістки, його
## власний розмір крихітний — і масштаб виходив у сотню разів більшим.
func _normalize_size() -> void:
	var bounds := _get_model_bounds()
	if bounds.size.y <= 0.01:
		return
	var factor := target_height / bounds.size.y
	if factor < 0.01 or factor > 100.0:
		push_warning("Дивний масштаб моделі ворога: %f" % factor)
		return
	_model.scale = Vector3.ONE * factor
	# Модель має стояти на підлозі, а не тонути в ній. Летючі ширяють.
	_model.position.y = -bounds.position.y * factor + hover

func _get_model_bounds() -> AABB:
	var to_local := _model.global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for child in _model.find_children("*", "VisualInstance3D", true, false):
		var instance := child as VisualInstance3D
		var child_bounds: AABB = to_local * (instance.global_transform * instance.get_aabb())
		if first:
			bounds = child_bounds
			first = false
		else:
			bounds = bounds.merge(child_bounds)
	return bounds

## Відеокарта й так знає, що потрапляє в кадр; цей вузол просто
## повідомляє нам про це — безкоштовно.
func _add_screen_notifier() -> void:
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-0.8, 0.0, -0.8), Vector3(1.6, target_height + 0.6, 1.6))
	notifier.screen_entered.connect(func() -> void: _on_screen = true)
	notifier.screen_exited.connect(func() -> void: _on_screen = false)
	add_child(notifier)

func _ready() -> void:
	add_to_group(&"enemies")
	current_hp = max_hp
	_agent = NavigationAgent3D.new()
	# Ворог зупиняється трохи раніше цілі, інакше штовхає героя спиною.
	# До наступної точки маршруту переходить лише дійшовши до поточної
	# впритул: інакше він "зрізав" би кути й заходив у стіну.
	_agent.path_desired_distance = 0.25
	# Карта прохідності лежить на пів метра вище за підлогу (так її печуть
	# клітинки висотою 0.25 м), а ноги ворога — на самій підлозі. Без цієї
	# поправки ворог "не дотягувався" до точок маршруту по висоті й стояв.
	_agent.path_height_offset = 0.5
	_agent.target_desired_distance = attack_range * 0.8
	# Взаємне розштовхування агентів (avoidance) вимкнене: воно рахується
	# щокадру для кожного ворога, а результат нам не потрібен.
	_agent.avoidance_enabled = false
	_agent.radius = 0.5
	add_child(_agent)
	# Різний зсув у кожного: вороги не рахують маршрут усі в один кадр.
	_repath_left = randf() * REPATH_INTERVAL
	_sight_left = randf() * SIGHT_INTERVAL

## Сон: далекий ворог не рахує маршрут і не ворушить скелетом.
func set_sleeping(sleeping: bool) -> void:
	if _sleeping == sleeping:
		return
	_sleeping = sleeping
	set_physics_process(not sleeping)
	set_process(not sleeping)
	if _model != null:
		_model.visible = not sleeping

## 1 — анімація щокадру, 2 — через кадр і т.д. Задає данж за відстанню.
func set_animation_step(step: int) -> void:
	_animation_step = maxi(step, 1)

func _process(delta: float) -> void:
	if _animation == null:
		return
	# Сповільнений ворог і рухається повільно, заморожений — застигає.
	_animation_time += delta * _pace()
	# Невидимий ворог анімацію не рахує: час накопичується й "доганяється"
	# одним кроком, щойно він з'явиться в кадрі.
	if not _on_screen:
		return
	_animation_frame += 1
	if _animation_frame % _animation_step != 0:
		return
	_animation.advance(_animation_time)
	_animation_time = 0.0

func _physics_process(delta: float) -> void:
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

	var distance := global_position.distance_to(_player.global_position)
	_update_aggro(distance)
	_attack_left -= delta * _pace()
	_repath_left -= delta
	_sight_left -= delta
	_stagger_left = maxf(_stagger_left - delta, 0.0)
	_tick_status(delta)

	# Стоїть без діла на підлозі — рухати нічого, фізику не рахуємо.
	if not _aggro and _grounded and velocity.is_zero_approx() and _knockback.is_zero_approx():
		_play("Idle")
		return

	if not _grounded:
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if _fuse_left >= 0.0:
		_process_fuse(delta)
	elif _charge_state != 0:
		_process_charge(delta)
	elif _windup_left > 0.0:
		_process_windup(delta * _pace())
	elif _stagger_left > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
	elif _aggro and _use_abilities(distance):
		pass
	elif _aggro:
		match kind:
			Kind.RANGED:
				_process_ranged(distance, delta)
			Kind.EXPLODER:
				_process_exploder(distance, delta)
			Kind.CHARGER:
				_process_charger(distance, delta)
			Kind.BOSS:
				if not _boss_special(distance, delta):
					_process_melee(distance, delta)
			_:
				_process_melee(distance, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play("Idle")

	_move(delta)

## Здібність бере хід, коли ворог вільний, не на перезарядці удару й
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
## move_and_slide() — найдорожча річ, яку ворог робить щокадру: кілька
## перевірок зіткнень фігурою. Але коли ворог іде МАРШРУТОМ, вона не
## потрібна: маршрут по карті прохідності вже обходить стіни з запасом.
## Тож такий ворог просто зсувається вздовж маршруту. Повна фізика
## лишається там, де без неї не можна: падіння на старті, відкидання від
## удару, відхід стрільця (він іде не маршрутом, а геть від героя).
##
## Відкидання накладається лише на цей крок, а власна швидкість потім
## повертається точно такою, якою була, — інакше залишок накопичувався б.
func _move(delta: float) -> void:
	var has_knockback := not _knockback.is_zero_approx()
	var moving := not Vector2(velocity.x, velocity.z).is_zero_approx()
	# Сповільнення діє на власний крок ворога, відкидання — ні.
	var pace := _pace()
	if _grounded and not has_knockback and _path_step:
		global_position.x += velocity.x * pace * delta
		global_position.z += velocity.z * pace * delta
	elif has_knockback or moving or not _grounded:
		var own_velocity := velocity
		velocity.x = velocity.x * pace + _knockback.x
		velocity.z = velocity.z * pace + _knockback.z
		move_and_slide()
		_grounded = is_on_floor()
		velocity.x = own_velocity.x
		velocity.z = own_velocity.z
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	_path_step = false

## Помітив — переслідує; поки не втік далеко, не забуває.
##
## Героя, що сховався (димова завіса асасина), ворог не бачить узагалі:
## губить ціль і кидає замах.
func _update_aggro(distance: float) -> void:
	if shut_out or (_player.has_method("is_targetable") and not _player.is_targetable()):
		if _aggro:
			_aggro = false
			_cancel_windup()
		return
	if not _aggro and distance <= aggro_range:
		_aggro = true
		_repath_left = 0.0   # помітив — одразу прокладає маршрут
	elif _aggro and distance > leash_range:
		_aggro = false

func _process_melee(distance: float, delta: float) -> void:
	# Далеко — або близько, але між нами стіна: іде маршрутом в обхід.
	if distance > attack_range or not _sees_player():
		_move_along_path(delta)
		return
	velocity.x = 0.0
	velocity.z = 0.0
	_face_player(10.0)
	_try_begin_windup()

## Стрілець тримає дистанцію: не бачить — підходить, задалеко —
## підходить, упритул — відступає. Стріляє лише тоді, коли бачить.
func _process_ranged(distance: float, delta: float) -> void:
	if not _sees_player() or distance > attack_range:
		_move_along_path(delta)
		return
	if distance < RANGED_MIN_DISTANCE:
		var away := global_position - _player.global_position
		away.y = 0.0
		away = away.normalized()
		velocity.x = move_toward(velocity.x, away.x * move_speed, 12.0 * delta)
		velocity.z = move_toward(velocity.z, away.z * move_speed, 12.0 * delta)
		_play("Walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_face_player(10.0)
	_try_begin_windup()

## Іде до героя МАРШРУТОМ по карті прохідності.
func _move_along_path(delta: float) -> void:
	if _repath_left <= 0.0:
		_repath_left = REPATH_INTERVAL
		_agent.target_position = _player.global_position
	if _agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var next_point := _agent.get_next_path_position()
	var direction := (next_point - global_position)
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	direction = direction.normalized()
	# Напрямок — точно на наступну точку маршруту, плавно набирається лише
	# швидкість. Так ворог іде рівно по лінії маршруту, яка вже обходить
	# стіни з запасом, і не зрізає кутів (поворот моделі й так плавний).
	var speed := move_toward(Vector2(velocity.x, velocity.z).length(), move_speed, 12.0 * delta)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_path_step = true
	_face(direction, 10.0)
	_play("Walk")

## Видимість героя з кешем: промінь кілька разів на секунду.
func _sees_player() -> bool:
	if _sight_left <= 0.0:
		_sight_left = SIGHT_INTERVAL
		_can_see = _has_line_of_sight()
	return _can_see

## Промінь від очей ворога до грудей героя. Якщо першим трапляється
## стіна — бачити не можна.
func _has_line_of_sight() -> bool:
	var from := global_position + Vector3.UP * eye_height
	var to := _player.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	# Маска 1 — світ (стіни, колони).
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

# --- замах і удар ---

## Замахується лише тоді, коли вже повернувся до героя: спершу
## розвернутись, потім бити — а не махати в інший бік.
func _try_begin_windup() -> void:
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() > 0.3 and _model_forward().angle_to(offset.normalized()) > deg_to_rad(35.0):
		return
	_begin_windup()

func _begin_windup() -> void:
	if _attack_left > 0.0 or _windup_left > 0.0:
		return
	if not _has_line_of_sight():
		return
	_attack_counter += 1
	_special = ""
	_windup_slam = slam_every > 0 and _attack_counter % slam_every == 0
	match kind:
		Kind.RANGED:
			_windup_total = RANGED_WINDUP
		Kind.BOSS:
			_windup_total = SLAM_WINDUP if _windup_slam else BOSS_WINDUP
		_:
			_windup_total = MELEE_WINDUP
	_windup_left = _windup_total
	velocity.x = 0.0
	velocity.z = 0.0
	_play_once(["Punch", "Bite_Front", "Headbutt", "Weapon"])

	if kind == Kind.RANGED:
		# Снаряд "набухає" в руці — це і є попередження для гравця.
		_charging_shot = EnemyProjectile.create(damage, projectile_color, projectile_speed)
		add_child(_charging_shot)
		_charging_shot.position = Vector3(0, target_height * 0.7, 0) + _model_forward() * 0.6
		return

	if _windup_slam:
		_show_telegraph(SLAM_RADIUS, PI, SLAM_COLOR)
	else:
		_show_telegraph(_melee_reach(), deg_to_rad(55.0), TELEGRAPH_COLOR)

func _process_windup(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_windup_left -= delta
	if not _windup_slam:
		_face_player(WINDUP_TURN_SPEED)
	var progress := 1.0 - _windup_left / _windup_total
	if _telegraph != null:
		_telegraph.rotation.y = _model.rotation.y
		_telegraph.set_instance_shader_parameter(&"progress", progress)
	if _charging_shot != null and is_instance_valid(_charging_shot):
		_charging_shot.set_charge(progress)
		_charging_shot.position = Vector3(0, target_height * 0.7, 0) + _model_forward() * 0.6
	if _windup_left <= 0.0:
		_resolve_attack()

func _resolve_attack() -> void:
	_windup_left = 0.0
	_attack_left = attack_cooldown
	_hide_telegraph()
	for ability in abilities:
		if ability.id == _special:
			_special = ""
			ability.resolve()
			return
	if kind == Kind.RANGED:
		_release_shot()
		return
	if _special == "summon":
		_special = ""
		CombatVfx.shockwave(get_parent(), global_position, 3.5, SUMMON_COLOR, 0.5)
		summon_requested.emit(global_position, SUMMON_COUNT)
		return
	if _special == "volley":
		_special = ""
		_fire_volley()
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if _windup_slam:
		CombatVfx.shockwave(get_parent(), global_position, SLAM_RADIUS, SLAM_COLOR, 0.35)
		var rig := get_tree().get_first_node_in_group(&"camera_rig")
		if rig != null:
			rig.shake(0.12)
		if _zone_covers(_player.global_position, true):
			_player.take_damage(damage * 1.5)
		else:
			_check_late_dodge(true)
		return
	# Звичайний удар влучає, лише якщо герой досі в червоній зоні.
	if _zone_covers(_player.global_position, false) and _has_line_of_sight():
		_player.take_damage(damage)
	else:
		_check_late_dodge(false)

## Чи накриває червона зона удару точку на підлозі.
func _zone_covers(point: Vector3, slam: bool) -> bool:
	var offset := point - global_position
	offset.y = 0.0
	if slam:
		return offset.length() <= SLAM_RADIUS + 0.3
	var in_reach := offset.length() <= _melee_reach() + 0.35
	var in_front := offset.length() < 0.5 or _model_forward().angle_to(offset.normalized()) <= deg_to_rad(65.0)
	return in_reach and in_front

## Герой вискочив перекатом із зони в останню мить — ідеальний перекат.
func _check_late_dodge(slam: bool) -> void:
	if not _player.has_method("late_dodge_origin"):
		return
	var origin: Vector3 = _player.late_dodge_origin(LATE_DODGE_WINDOW)
	if origin != Vector3.INF and _zone_covers(origin, slam):
		_player.register_perfect_dodge()

func _release_shot() -> void:
	if _charging_shot == null or not is_instance_valid(_charging_shot):
		return
	var shot := _charging_shot
	_charging_shot = null
	var target := _player.global_position + Vector3.UP * 1.0
	var direction := target - shot.global_position
	var origin := shot.global_position
	shot.launch(direction, _player, get_parent())
	# Залп: ще кілька снарядів віялом навколо основного.
	for i in range(1, volley):
		var side := 1.0 if i % 2 == 1 else -1.0
		var angle := side * deg_to_rad(11.0) * ceilf(i / 2.0)
		_spawn_shot(origin, direction.rotated(Vector3.UP, angle))

func _spawn_shot(origin: Vector3, direction: Vector3) -> void:
	var extra := EnemyProjectile.create(damage, projectile_color, projectile_speed)
	get_parent().add_child(extra)
	extra.global_position = origin
	extra.set_charge(1.0)
	extra.launch(direction, _player, get_parent())

## Залп Дракона: віяло снарядів із пащі.
func _fire_volley() -> void:
	var origin := global_position + Vector3.UP * (target_height * 0.6 + hover) + _model_forward() * 1.2
	var direction := _player.global_position + Vector3.UP - origin
	var count := maxi(volley, 3)
	for i in count:
		var angle := lerpf(-0.5, 0.5, float(i) / float(count - 1))
		_spawn_shot(origin, direction.rotated(Vector3.UP, angle))
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.08)

# --- вибуховий ---

func _process_exploder(distance: float, delta: float) -> void:
	if distance <= FUSE_DISTANCE and _sees_player():
		_light_fuse()
		return
	_move_along_path(delta)

func _light_fuse() -> void:
	_fuse_left = FUSE_TIME
	velocity.x = 0.0
	velocity.z = 0.0
	_show_telegraph(EXPLODE_RADIUS, PI, EXPLODE_COLOR)
	_play_once(["Jump", "Headbutt", "Punch", "Bite_Front"])

func _process_fuse(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_fuse_left -= delta
	if _telegraph != null:
		_telegraph.set_instance_shader_parameter(&"progress", 1.0 - _fuse_left / FUSE_TIME)
	# Блимає дедалі частіше — видно, що зараз рвоне.
	_flash_left -= delta
	if _flash_left <= 0.0:
		_flash_left = lerpf(0.25, 0.08, 1.0 - _fuse_left / FUSE_TIME)
		CombatVfx.flash_model(_model, Color(1.0, 0.6, 0.2), 0.05)
	if _fuse_left <= 0.0:
		_explode()

func _explode() -> void:
	_fuse_left = -1.0
	_hide_telegraph()
	var parent := get_parent()
	CombatVfx.shockwave(parent, global_position, EXPLODE_RADIUS, EXPLODE_COLOR, 0.35)
	CombatVfx.impact(parent, global_position + Vector3.UP * 0.8, EXPLODE_COLOR, true)
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.18)
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() <= EXPLODE_RADIUS + 0.3:
		_player.take_damage(damage)
	# Вибухнув сам — досвіду не дає: винагорода лише за те, щоб убити раніше.
	xp_reward = 0
	current_hp = 0.0
	_die()

# --- таран ---

func _process_charger(distance: float, delta: float) -> void:
	if distance <= attack_range and _sees_player():
		velocity.x = 0.0
		velocity.z = 0.0
		_face_player(10.0)
		_try_begin_windup()
		return
	if _attack_left <= 0.0 and distance >= CHARGE_MIN_DISTANCE and distance <= CHARGE_MAX_DISTANCE \
			and _sees_player():
		_begin_charge()
		return
	_move_along_path(delta)

func _begin_charge() -> void:
	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction.length() < 0.1:
		return
	_charge_dir = direction.normalized()
	_charge_state = 1
	_charge_left = CHARGE_WINDUP
	_charge_hit = false
	velocity.x = 0.0
	velocity.z = 0.0
	_model.rotation.y = atan2(_charge_dir.x, _charge_dir.z)
	_hide_telegraph()
	var length := CHARGE_SPEED * CHARGE_TIME
	_telegraph = CombatVfx.make_line_marker(CHARGE_COLOR, length, 1.8)
	add_child(_telegraph)
	_telegraph.position = Vector3(0, 0.05, 0) + _charge_dir * length * 0.5
	_telegraph.rotation.y = atan2(_charge_dir.x, _charge_dir.z)
	_play_once(["Jump", "No", "Headbutt", "Punch"])

func _process_charge(delta: float) -> void:
	_charge_left -= delta
	match _charge_state:
		1:
			velocity.x = 0.0
			velocity.z = 0.0
			if _telegraph != null:
				_telegraph.set_instance_shader_parameter(&"progress", 1.0 - _charge_left / CHARGE_WINDUP)
			if _charge_left <= 0.0:
				_hide_telegraph()
				_charge_state = 2
				_charge_left = CHARGE_TIME
		2:
			velocity.x = _charge_dir.x * CHARGE_SPEED
			velocity.z = _charge_dir.z * CHARGE_SPEED
			_play("Walk")
			var offset := _player.global_position - global_position
			offset.y = 0.0
			if not _charge_hit and offset.length() < 1.4:
				_charge_hit = true
				if _player.take_damage(damage * 1.3):
					var rig := get_tree().get_first_node_in_group(&"camera_rig")
					if rig != null:
						rig.shake(0.15)
			if is_on_wall():
				# Врізався в стіну — оглушений довше: вікно для контратаки.
				_charge_state = 3
				_charge_left = CHARGE_WALL_STUN
				velocity.x = 0.0
				velocity.z = 0.0
				CombatVfx.impact(get_parent(), global_position + Vector3.UP + _charge_dir * 0.8, HIT_COLOR, true)
			elif _charge_left <= 0.0:
				_charge_state = 3
				_charge_left = CHARGE_RECOVER
		3:
			velocity.x = 0.0
			velocity.z = 0.0
			_play("Idle")
			if _charge_left <= 0.0:
				_charge_state = 0
				_attack_left = attack_cooldown

# --- боси ---

## Прийоми, які бос робить сам, поза звичайними ударами. true — прийом
## почався, і цього кадру звичайна поведінка не потрібна.
func _boss_special(distance: float, delta: float) -> bool:
	_summon_left -= delta
	_volley_left -= delta
	_dragon_charge_left -= delta
	if _attack_left > 0.0 or not _sees_player():
		return false
	match boss_style:
		"summoner":
			if _summon_left <= 0.0:
				_summon_left = SUMMON_COOLDOWN
				_begin_special("summon", 1.0, SUMMON_COLOR, 3.5)
				return true
		"dragon":
			# Дракон не лише кусає впритул: чергує подих-залп (з будь-якої
			# відстані) і таран, щойно герой на кілька кроків відійде.
			if distance > 3.2 and _dragon_charge_left <= 0.0 and distance <= CHARGE_MAX_DISTANCE + 2.0:
				_dragon_charge_left = DRAGON_CHARGE_COOLDOWN
				_begin_charge()
				return true
			if _volley_left <= 0.0:
				_volley_left = VOLLEY_COOLDOWN
				_begin_special("volley", 0.8, Color(0.55, 0.9, 1.0, 0.85), 2.0)
				return true
	return false

func _begin_special(special: String, windup: float, color: Color, radius: float) -> void:
	_special = special
	_windup_slam = true   # не довертається за героєм під час прийому
	_windup_total = windup
	_windup_left = windup
	velocity.x = 0.0
	velocity.z = 0.0
	_face_player(20.0)
	_play_once(["Weapon", "Punch", "Headbutt", "Wave"])
	_show_telegraph(radius, PI, color)

## Замах збито: сильний удар героя перериває ворога.
func _cancel_windup() -> void:
	_windup_left = 0.0
	_hide_telegraph()
	if _charging_shot != null and is_instance_valid(_charging_shot):
		_charging_shot.queue_free()
	_charging_shot = null
	_attack_left = maxf(_attack_left, attack_cooldown * 0.5)

func _melee_reach() -> float:
	return attack_range * 1.15 + 0.3

func _show_telegraph(radius: float, half_arc: float, color: Color) -> void:
	_hide_telegraph()
	_telegraph = CombatVfx.make_ground_marker(color, radius, half_arc)
	add_child(_telegraph)
	_telegraph.position = Vector3(0, 0.05, 0)
	_telegraph.rotation.y = _model.rotation.y

func _hide_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null

# --- чари героя: сповільнення, заморозка, оглушення ---

## Сповільнений ворог ходить, замахується й рухається повільніше, під
## ним синіє іней. factor — частка звичайної швидкості (0.6 = на 40%
## повільніше). Бос і голем піддаються вдвічі слабше — інакше їх можна
## було б тримати без кінця.
func apply_slow(factor: float, seconds: float) -> void:
	if _dying:
		return
	if kind == Kind.BOSS or tank:
		factor = lerpf(factor, 1.0, 0.5)
	_slow_factor = factor if _slow_left <= 0.0 else minf(_slow_factor, factor)
	_slow_left = maxf(_slow_left, seconds)
	_show_frost(true)

func is_slowed() -> bool:
	return _slow_left > 0.0

## Заморозка: ворог застигає в крижаній брилі — не ходить і не б'є,
## замах зривається. Боса й голема — ненадовго.
func freeze(seconds: float) -> void:
	if _dying:
		return
	if kind == Kind.BOSS or tank:
		seconds *= 0.35
	_frozen_left = maxf(_frozen_left, seconds)
	_hold_still(seconds)
	_show_ice(true)

## Оглушення важким ударом: стоїть і не б'є.
func stun(seconds: float) -> void:
	if _dying:
		return
	if kind == Kind.BOSS or tank:
		seconds *= 0.4
	_hold_still(seconds)

func _hold_still(seconds: float) -> void:
	_stagger_left = maxf(_stagger_left, seconds)
	_cancel_windup()
	# Таран, що цілиться чи мчить, теж зупиняється.
	if _charge_state != 0:
		_charge_state = 0
		_hide_telegraph()

## Наскільки швидко зараз "живе" ворог: 1 — звичайно, менше — сповільнений,
## 0 — заморожений (стоїть, і анімація застигла).
func _pace() -> float:
	if _frozen_left > 0.0:
		return 0.0
	return _slow_factor if _slow_left > 0.0 else 1.0

func _tick_status(delta: float) -> void:
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_factor = 1.0
			_show_frost(false)
	if _frozen_left > 0.0:
		_frozen_left -= delta
		if _frozen_left <= 0.0:
			_show_ice(false)

## Іней на підлозі під ворогом — видно, кого сповільнено.
func _show_frost(shown: bool) -> void:
	if shown and _frost_marker == null:
		_frost_marker = CombatVfx.make_ground_marker(FROST_COLOR, 0.7 + target_height * 0.12)
		_frost_marker.set_instance_shader_parameter(&"progress", 1.0)
		add_child(_frost_marker)
		_frost_marker.position = Vector3(0, 0.06, 0)
	if _frost_marker != null:
		_frost_marker.visible = shown

## Крижана брила — шестигранна прозора призма навколо ворога.
func _show_ice(shown: bool) -> void:
	if shown and _ice_block == null:
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 6
		mesh.rings = 1
		mesh.top_radius = 0.4 + target_height * 0.08
		mesh.bottom_radius = mesh.top_radius * 1.15
		mesh.height = target_height * 1.08
		_ice_block = MeshInstance3D.new()
		_ice_block.mesh = mesh
		_ice_block.material_override = _get_ice_material()
		_ice_block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ice_block)
		_ice_block.position = Vector3(0, mesh.height * 0.5 + hover, 0)
	if _ice_block != null:
		_ice_block.visible = shown

static func _get_ice_material() -> StandardMaterial3D:
	if _ice_material == null:
		_ice_material = StandardMaterial3D.new()
		_ice_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ice_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ice_material.albedo_color = ICE_COLOR
	return _ice_material

# --- отримання шкоди ---

## Удар героя. knockback — напрямок і сила відкидання, heavy — сильний
## удар, що збиває замах.
func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO, crit: bool = false, heavy: bool = false) -> void:
	if _dying or _hidden:
		return
	# Щит еліти спереду пропускає лише частину шкоди, тотем — ще менше.
	if elite != null:
		amount *= elite.damage_factor(heavy)
	# Під захистом тотема й сам тотем не відкидаються.
	if is_warded():
		amount *= _ward_factor
		knockback = Vector3.ZERO
	if stationary:
		knockback = Vector3.ZERO
	current_hp -= amount
	if not _aggro:
		_repath_left = 0.0
	_aggro = true   # вдарили — помітив, навіть якщо був далеко
	if _health_bar != null:
		_health_bar.set_ratio(current_hp / max_hp)
		_health_bar.flash()

	var parent := get_parent()
	var chest := global_position + Vector3.UP * target_height * 0.55
	CombatVfx.impact(parent, chest, HEAVY_HIT_COLOR if heavy or crit else HIT_COLOR, heavy or crit)
	CombatVfx.damage_number(parent, global_position + Vector3.UP * (target_height + 0.35), amount, crit)
	CombatVfx.flash_model(_model, Color.WHITE, 0.09)

	# Бос і голем важкі: їх майже не зрушити й лише сильним ударом збити
	# замах. Таран, що мчить, не зупинити нічим.
	var is_boss := kind == Kind.BOSS or tank
	_knockback = knockback * (0.25 if is_boss else 1.0)
	if _charge_state == 2 or _fuse_left >= 0.0:
		_knockback = Vector3.ZERO
	if heavy or not is_boss:
		if heavy:
			_cancel_windup()
		_stagger_left = maxf(_stagger_left, (0.45 if heavy else 0.15) * (0.5 if is_boss else 1.0))

	if _windup_left <= 0.0:
		_play_once(["HitReact", "HitRecieve"])
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	if elite != null:
		elite.on_death()
	for ability in abilities:
		ability.on_death()
	# Убитий до вибуху — не вибухає; таран, убитий на бігу, падає.
	_fuse_left = -1.0
	_charge_state = 0
	_dying = true
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	_frozen_left = 0.0
	_slow_left = 0.0
	_show_frost(false)
	_show_ice(false)
	_cancel_windup()
	remove_from_group(&"enemies")
	if _health_bar != null:
		_health_bar.visible = false
	# Мертвий ворог більше не заступає дорогу.
	collision_layer = 0
	var parent := get_parent()
	CombatVfx.impact(parent, global_position + Vector3.UP * target_height * 0.5, DEATH_COLOR, true)
	CombatVfx.shockwave(parent, global_position, 4.0 if kind == Kind.BOSS else 1.1, DEATH_COLOR, 0.3)
	died.emit(global_position, xp_reward)
	_play_once(["Death"])
	# Даємо дограти смерть, а тоді тіло провалюється під підлогу. Таймер
	# стоїть на паузі разом із грою; якщо ворог зникне раніше (гравець
	# вийшов з данжу), виклик просто не відбудеться.
	get_tree().create_timer(DEATH_LINGER, false).timeout.connect(_sink)

func _sink() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 1.6, SINK_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

# --- поворот і анімації ---

func _model_forward() -> Vector3:
	var angle := _model.rotation.y
	return Vector3(sin(angle), 0.0, cos(angle))

func _face_player(speed: float) -> void:
	var direction := _player.global_position - global_position
	direction.y = 0.0
	if direction.length() > 0.01:
		_face(direction.normalized(), speed)

func _face(direction: Vector3, speed: float) -> void:
	if _model == null:
		return
	var wanted := atan2(direction.x, direction.z)
	_model.rotation.y = rotate_toward(_model.rotation.y, wanted, speed * get_physics_process_delta_time())

## Анімації в різних моделей звуться по-різному, тож шукаємо за
## кількома можливими назвами.
func _play(wanted: String) -> void:
	if _animation == null:
		return
	# Летючі не ходять, а ширяють: шукаємо і їхні назви анімацій.
	var candidates: Array = [wanted]
	if wanted == "Walk":
		candidates.append_array(["Fast_Flying", "Run"])
	candidates.append_array(["Idle", "Flying_Idle"])
	var name := _find_animation(candidates)
	if name != "" and _animation.current_animation != name:
		_animation.play(name)

func _play_once(candidates: Array) -> void:
	if _animation == null:
		return
	var name := _find_animation(candidates)
	if name != "":
		_animation.play(name)

## Назви шукаються один раз і запам'ятовуються: _play викликається
## щокадру, і перебирати рядки кожного разу — марна робота.
func _find_animation(candidates: Array) -> String:
	var key := ",".join(candidates)
	if _animation_cache.has(key):
		return _animation_cache[key]
	var found := _search_animation(candidates)
	_animation_cache[key] = found
	return found

func _search_animation(candidates: Array) -> String:
	for wanted: String in candidates:
		for name: String in _animation.get_animation_list():
			if name.get_slice("|", name.get_slice_count("|") - 1) == wanted:
				return name
	return ""

func _loop(names: Array) -> void:
	for wanted: String in names:
		var name := _find_animation([wanted])
		if name != "":
			_animation.get_animation(name).loop_mode = Animation.LOOP_LINEAR
