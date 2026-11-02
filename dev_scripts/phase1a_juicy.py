import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:70])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


# --- зупинка кадру: свій ступінь уповільнення ---
edit('scenes/combat/combat_vfx.gd', [
('''static func hitstop(tree: SceneTree, duration: float) -> void:
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	if Engine.time_scale < 1.0 and until <= _hitstop_until:
		return
	_hitstop_until = until
	_hitstop_token += 1
	var token := _hitstop_token
	# Не повна зупинка, а різке пригальмування: удар відчувається, але
	# картинка не "застигає", що на телефоні сприймалось би як лаг.
	Engine.time_scale = 0.25''', '''##
## time_scale — наскільки пригальмувати: 0.25 для удару, трохи більше
## для довгого сповільнення (вбивство боса), щоб воно не тягнулось.
static func hitstop(tree: SceneTree, duration: float, time_scale: float = 0.25) -> void:
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	if Engine.time_scale < 1.0 and until <= _hitstop_until:
		return
	_hitstop_until = until
	_hitstop_token += 1
	var token := _hitstop_token
	# Не повна зупинка, а різке пригальмування: удар відчувається, але
	# картинка не "застигає", що на телефоні сприймалось би як лаг.
	Engine.time_scale = time_scale'''),
])

# --- ворог: іскри й хвиля при смерті, тіло провалюється в підлогу ---
edit('scenes/dungeon/enemy_3d.gd', [
('''const HIT_COLOR := Color(1.0, 0.95, 0.8)
const HEAVY_HIT_COLOR := Color(1.0, 0.65, 0.25)
''', '''const HIT_COLOR := Color(1.0, 0.95, 0.8)
const HEAVY_HIT_COLOR := Color(1.0, 0.65, 0.25)
## Смерть: іскри й хвиля по підлозі; тіло лежить, поки дограє анімація,
## а тоді провалюється під підлогу.
const DEATH_COLOR := Color(1.0, 0.6, 0.35)
const DEATH_LINGER := 1.2
const SINK_TIME := 0.6
'''),
('''	# Мертвий ворог більше не заступає дорогу.
	collision_layer = 0
	died.emit(global_position, xp_reward)
	_play_once(["Death"])
	# Даємо дограти смерть, а тоді прибираємо. Таймер стоїть на паузі
	# разом із грою, і прив'язаний до самого ворога: якщо той зникне
	# раніше (гравець вийшов з данжу), виклик просто не відбудеться.
	get_tree().create_timer(1.6, false).timeout.connect(queue_free)''', '''	# Мертвий ворог більше не заступає дорогу.
	collision_layer = 0
	var parent := get_parent()
	CombatVfx.impact(parent, global_position + Vector3.UP * target_height * 0.5, DEATH_COLOR, true)
	CombatVfx.shockwave(parent, global_position, 4.0 if kind == Kind.BOSS else 1.6, DEATH_COLOR, 0.35)
	died.emit(global_position, xp_reward)
	_play_once(["Death"])
	# Даємо дограти смерть, а тоді тіло провалюється під підлогу. Таймер
	# стоїть на паузі разом із грою; якщо ворог зникне раніше (гравець
	# вийшов з данжу), виклик просто не відбудеться.
	get_tree().create_timer(DEATH_LINGER, false).timeout.connect(_sink)

func _sink() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 1.6, SINK_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)'''),
])

# --- данж: здобич летить до героя, вбивство пригальмовує гру ---
edit('scenes/dungeon/dungeon.gd', [
('''## Скільки досвіду треба на наступний рівень героя в данжі.
const XP_PER_LEVEL := 12
''', '''## Скільки досвіду треба на наступний рівень героя в данжі.
const XP_PER_LEVEL := 12

## ВІДЧУТТЯ ВБИВСТВА. Кожне вбивство на мить пригальмовує гру, а бос —
## майже на секунду: перемога має відчуватись.
const KILL_HITSTOP := 0.05
const BOSS_SLOWMO_SECONDS := 0.9
const BOSS_SLOWMO_SCALE := 0.3
'''),
('''var _hud_title: Label
var _health_bar: ProgressBar''', '''var _loot: LootSwarm
var _hud_title: Label
var _health_bar: ProgressBar'''),
('''	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
''', '''	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	# Здобич з убитих ворогів летить до героя й зараховується, коли долетить.
	_loot = LootSwarm.new()
	add_child(_loot)
	_loot.setup(player)
	_loot.collected.connect(_on_loot_collected)
'''),
('''func _on_enemy_died(_position: Vector3, xp_reward: int, kind: Enemy3D.Kind) -> void:
	_alive_enemies -= 1
	_add_gold(int(round((GOLD_PER_BOSS if kind == Enemy3D.Kind.BOSS else GOLD_PER_KILL) * _gold_scale)))
	_add_xp(xp_reward)
''', '''func _on_enemy_died(position: Vector3, xp_reward: int, kind: Enemy3D.Kind) -> void:
	_alive_enemies -= 1
	var is_boss := kind == Enemy3D.Kind.BOSS
	# Золото й досвід вилітають фонтаном і зараховуються, коли долетять до
	# героя (_on_loot_collected).
	var gold := int(round((GOLD_PER_BOSS if is_boss else GOLD_PER_KILL) * _gold_scale))
	_loot.burst(position, LootSwarm.Kind.GOLD, gold, 12 if is_boss else clampi(gold / 3, 1, 4))
	_loot.burst(position, LootSwarm.Kind.XP, xp_reward, 6 if is_boss else clampi(xp_reward, 1, 3))
	if is_boss:
		_celebrate_boss(position)
	else:
		CombatVfx.hitstop(get_tree(), KILL_HITSTOP)
	_update_status()
'''),
('''## Золото з походу. Талант "Приріст золота" множить здобич, а''', '''func _on_loot_collected(kind: int, amount: int) -> void:
	if kind == LootSwarm.Kind.GOLD:
		AudioManager.play(&"gold")
		_add_gold(amount)
	else:
		AudioManager.play(&"pickup")
		_add_xp(amount)

## Бос упав: сповільнення, велика хвиля й трус камери.
func _celebrate_boss(position: Vector3) -> void:
	CombatVfx.hitstop(get_tree(), BOSS_SLOWMO_SECONDS, BOSS_SLOWMO_SCALE)
	CombatVfx.shockwave(self, position, 7.0, Color(1.0, 0.78, 0.4), 0.8)
	CombatVfx.impact(self, position + Vector3.UP * 1.6, Color(1.0, 0.85, 0.45), true)
	player.shake_camera(0.35)

## Золото з походу. Талант "Приріст золота" множить здобич, а'''),
('''	CombatVfx.shockwave(holder, center, 1.5, Color(0.35, 0.95, 1.0), 0.5)''', '''	CombatVfx.shockwave(holder, center, 1.5, Color(0.35, 0.95, 1.0), 0.5)
	_loot.warm_up(center)'''),
])
print('ok')
