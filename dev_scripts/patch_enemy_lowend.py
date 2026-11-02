# -*- coding: utf-8 -*-
import os
os.chdir(r'D:\Claude code\idle survivor_like')
path = 'scenes/dungeon/enemy_3d.gd'
s = open(path, encoding='utf-8').read()


def rep(a, b):
    global s
    assert a in s, a[:80]
    s = s.replace(a, b, 1)


rep('''## Агро теж чесне: поки герой далеко, ворог стоїть на місці; помітив —
## починає переслідувати, і вже не губить, поки той не втече далеко.''',
'''## Агро теж чесне: поки герой далеко, ворог стоїть на місці; помітив —
## починає переслідувати, і вже не губить, поки той не втече далеко.
##
## ЕКОНОМІЯ НА СЛАБКИХ ТЕЛЕФОНАХ (гравцеві непомітна):
##  - маршрут перераховується кілька разів на секунду, а не щокадру:
##    за третину секунди герой зміщується на метр, маршрут той самий;
##  - "чи бачу героя" для стрільця теж перевіряється кілька разів на
##    секунду. Перед самим пострілом — завжди свіжо, тож крізь стіни він
##    однаково не стріляє;
##  - у кожного ворога свій зсув таймерів, щоб усі не рахували в один
##    і той самий кадр;
##  - анімація ворога, якого не видно в кадрі, стоїть на паузі, а
##    далекого — оновлюється через кадр;
##  - ворог, що стоїть без діла, не рахує фізику руху.''')

rep('''const GRAVITY := 20.0
const ATTACK_ANIMATION_TIME := 0.5''',
'''const GRAVITY := 20.0
const ATTACK_ANIMATION_TIME := 0.5

const REPATH_INTERVAL := 0.3
const SIGHT_INTERVAL := 0.2''')

rep('''var _health_bar: HealthBar3D
var _sleeping := false''',
'''var _health_bar: HealthBar3D
var _sleeping := false

var _repath_left := 0.0
var _sight_left := 0.0
var _can_see := false
var _on_screen := true
var _animation_step := 1
var _animation_frame := 0
var _animation_time := 0.0''')

rep('''	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation = players[0]
		_loop(["Idle", "Walk", "Run", "Flying_Idle", "Fast_Flying"])
	_add_health_bar()''',
'''	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation = players[0]
		_loop(["Idle", "Walk", "Run", "Flying_Idle", "Fast_Flying"])
		# Анімацію крутимо самі (див. _process): так її можна оновлювати
		# рідше або ставити на паузу, коли ворога не видно.
		_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_add_health_bar()
	_add_screen_notifier()''')

rep('''func _ready() -> void:
	current_hp = max_hp
	_agent = NavigationAgent3D.new()
	# Ворог зупиняється трохи раніше цілі, інакше штовхає героя спиною.
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = attack_range * 0.8
	_agent.avoidance_enabled = true
	_agent.radius = 0.5
	add_child(_agent)''',
'''## Відеокарта й так знає, що потрапляє в кадр; цей вузол просто
## повідомляє нам про це — безкоштовно.
func _add_screen_notifier() -> void:
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-0.8, 0.0, -0.8), Vector3(1.6, target_height + 0.6, 1.6))
	notifier.screen_entered.connect(func() -> void: _on_screen = true)
	notifier.screen_exited.connect(func() -> void: _on_screen = false)
	add_child(notifier)

func _ready() -> void:
	current_hp = max_hp
	_agent = NavigationAgent3D.new()
	# Ворог зупиняється трохи раніше цілі, інакше штовхає героя спиною.
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = attack_range * 0.8
	# Взаємне розштовхування агентів (avoidance) вимкнене: воно рахується
	# щокадру для кожного ворога, а його результат ми й так не
	# використовували.
	_agent.avoidance_enabled = false
	_agent.radius = 0.5
	add_child(_agent)
	# Різний зсув у кожного: вороги не рахують маршрут усі в один кадр.
	_repath_left = randf() * REPATH_INTERVAL
	_sight_left = randf() * SIGHT_INTERVAL''')

rep('''func set_sleeping(sleeping: bool) -> void:
	if _sleeping == sleeping:
		return
	_sleeping = sleeping
	set_physics_process(not sleeping)
	if _animation != null:
		_animation.active = not sleeping
	if _model != null:
		_model.visible = not sleeping

func _physics_process(delta: float) -> void:
	if _dying or _player == null:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var distance := global_position.distance_to(_player.global_position)
	_update_aggro(distance)
	_attack_left -= delta

	if _aggro:
		if kind == Kind.RANGED:
			_process_ranged(distance, delta)
		else:
			_process_melee(distance, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play("Idle")

	move_and_slide()''',
'''func set_sleeping(sleeping: bool) -> void:
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
	_animation_time += delta
	# Невидимий ворог анімацію не рахує взагалі: час накопичується й
	# "доганяється" одним кроком, щойно він з'явиться в кадрі.
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

	var distance := global_position.distance_to(_player.global_position)
	_update_aggro(distance)
	_attack_left -= delta
	_repath_left -= delta
	_sight_left -= delta

	# Стоїть без діла на підлозі — рухати нічого, фізику не рахуємо.
	if not _aggro and is_on_floor() and velocity.is_zero_approx():
		_play("Idle")
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if _aggro:
		if kind == Kind.RANGED:
			_process_ranged(distance, delta)
		else:
			_process_melee(distance, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play("Idle")

	move_and_slide()''')

rep('''## Стрілець тримає дистанцію і б'є лише тоді, коли СПРАВДІ бачить ціль.
func _process_ranged(distance: float, delta: float) -> void:
	var can_see := _has_line_of_sight()
	if not can_see:''',
'''## Стрілець тримає дистанцію і б'є лише тоді, коли СПРАВДІ бачить ціль.
func _process_ranged(distance: float, delta: float) -> void:
	if _sight_left <= 0.0:
		_sight_left = SIGHT_INTERVAL
		_can_see = _has_line_of_sight()
	if not _can_see:''')

rep('''func _move_along_path(delta: float) -> void:
	_agent.target_position = _player.global_position
	if _agent.is_navigation_finished():''',
'''func _move_along_path(delta: float) -> void:
	if _repath_left <= 0.0:
		_repath_left = REPATH_INTERVAL
		_agent.target_position = _player.global_position
	if _agent.is_navigation_finished():''')

open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('enemy ok')

# --- Смужки здоров'я: спільні матеріали й без щокадрової роботи ---
path = 'scenes/dungeon/health_bar_3d.gd'
s = open(path, encoding='utf-8').read()
rep('''var _background: MeshInstance3D''',
'''## Матеріали спільні для всіх смужок одного кольору: двадцять ворогів —
## два матеріали, а не сорок. Відеокарта малює однакове разом.
static var _materials: Dictionary = {}

var _background: MeshInstance3D''')
rep('''	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = 1

	var instance := MeshInstance3D.new()
	instance.mesh = quad
	instance.material_override = material''',
'''	var instance := MeshInstance3D.new()
	instance.mesh = quad
	instance.material_override = _get_material(color)''')
rep('''func set_ratio(ratio: float) -> void:''',
'''static func _get_material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = 1
	_materials[color] = material
	return material

func set_ratio(ratio: float) -> void:''')
rep('''	visible = _always_visible
	set_ratio(1.0)''',
'''	visible = _always_visible
	# Таймер зникнення потрібен лише після удару.
	set_process(false)
	set_ratio(1.0)''')
rep('''func flash() -> void:
	visible = true
	_hide_left = SHOW_TIME''',
'''func flash() -> void:
	visible = true
	_hide_left = SHOW_TIME
	set_process(not _always_visible)''')
rep('''	_hide_left -= delta
	if _hide_left <= 0.0:
		visible = false''',
'''	_hide_left -= delta
	if _hide_left <= 0.0:
		visible = false
		set_process(false)''')
open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('bar ok')

# --- Герой: назви точок змішування (прибирає попередження рушія) ---
path = 'scenes/world/player_3d.gd'
s = open(path, encoding='utf-8').read()
rep('''	move.add_blend_point(_animation_node("CharacterArmature|Idle"), 0.0)
	move.add_blend_point(_animation_node("CharacterArmature|Walk"), 1.0)
	move.add_blend_point(_animation_node("CharacterArmature|Run"), 2.0)''',
'''	move.add_blend_point(_animation_node("CharacterArmature|Idle"), 0.0, -1, &"idle")
	move.add_blend_point(_animation_node("CharacterArmature|Walk"), 1.0, -1, &"walk")
	move.add_blend_point(_animation_node("CharacterArmature|Run"), 2.0, -1, &"run")''')
open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('player ok')
