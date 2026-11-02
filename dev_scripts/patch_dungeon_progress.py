# -*- coding: utf-8 -*-
# Данж: таланти "стартовий рівень", "удача", "приріст золота" працюють.
import os
os.chdir(r'D:\Claude code\idle survivor_like')
path = 'scenes/dungeon/dungeon.gd'
s = open(path, encoding='utf-8').read()


def rep(a, b):
    global s
    assert a in s, a[:90]
    s = s.replace(a, b, 1)


rep('''## Скільки досвіду треба на наступний рівень героя в данжі.
const XP_PER_LEVEL := 12''',
    '''## Скільки досвіду треба на наступний рівень героя в данжі.
const XP_PER_LEVEL := 12

## ЗОЛОТО ЗА ПОХІД (числа тимчасові — баланс підженемо, коли буде більше
## рівнів). Талант "Приріст золота" додає свої відсотки, а талант
## "Удача" покращує вибір здібностей, "Стартовий рівень" дає зайвий
## вибір на вході.
const GOLD_PER_KILL := 4
const GOLD_PER_BOSS := 60
const GOLD_FOR_CLEAR := 120
const TALENT_GOLD_PER_LEVEL := 0.07
const TALENT_LUCK_PER_LEVEL := 0.04''')

rep('''var _stream_left := 0.0''', '''var _stream_left := 0.0
var _run_gold := 0''')

# --- вхід у данж: стільки виборів, скільки дає "Стартовий рівень" ---
rep('''	# Вхідна кімната порожня, і перше, що робить гравець, — обирає
	# здібність. Далі вибір повторюється з кожним новим рівнем.
	await _offer_ability()''',
    '''	# Вхідна кімната порожня, і перше, що робить гравець, — обирає
	# здібність. Талант "Стартовий рівень" дає зайві вибори одразу.
	var start_picks := 1 + GameState.get_meta_level(GameState.selected_hero_id, &"meta_start_level")
	for i in start_picks:
		await _offer_ability()''')

# --- золото за вбитих ---
rep('''func _on_enemy_died(_position: Vector3, xp_reward: int, kind: Enemy3D.Kind) -> void:
	_alive_enemies -= 1
	_add_xp(xp_reward)''',
    '''func _on_enemy_died(_position: Vector3, xp_reward: int, kind: Enemy3D.Kind) -> void:
	_alive_enemies -= 1
	_add_gold(GOLD_PER_BOSS if kind == Enemy3D.Kind.BOSS else GOLD_PER_KILL)
	_add_xp(xp_reward)''')

rep('''## Досвід збирається з ворогів; за кожен рівень — нова здібність.''',
    '''## Золото з походу. Талант "Приріст золота" множить здобич, а
## зараховується вона одразу — щоб прогрес не пропав, якщо гравець
## загине на виході.
func _add_gold(amount: int) -> void:
	var levels := GameState.get_meta_level(GameState.selected_hero_id, &"meta_gold_gain")
	var total := int(round(amount * (1.0 + TALENT_GOLD_PER_LEVEL * levels)))
	_run_gold += total
	GameState.add_gold(total)
	_update_status()

## Досвід збирається з ворогів; за кожен рівень — нова здібність.''')

# --- удача у виборі здібностей ---
rep('''	var choices := UpgradePool.pick_choices({}, 0.0)''',
    '''	var luck := TALENT_LUCK_PER_LEVEL * GameState.get_meta_level(GameState.selected_hero_id, &"meta_luck")
	var choices := UpgradePool.pick_choices({}, luck)''')

# --- нагорода за пройдений рівень ---
rep('''func _on_exit_pressed() -> void:
	# Пройшов данж — наступний рівень стає доступним.
	GameState.unlock_next_dungeon_level()''',
    '''func _on_exit_pressed() -> void:
	# Пройшов данж — наступний рівень стає доступним, плюс нагорода.
	_add_gold(GOLD_FOR_CLEAR * (1 + _level_index))
	GameState.unlock_next_dungeon_level()''')

# --- золото видно в рядку стану ---
rep('''	status_label.text = "%s  •  рівень %d  •  досвід %d  •  ворогів %d  •  %s" % [
		level_title, _hero_level, _xp, _alive_enemies, state,
	]''',
    '''	status_label.text = "%s  •  рівень %d  •  досвід %d  •  золото %d  •  ворогів %d  •  %s" % [
		level_title, _hero_level, _xp, _run_gold, _alive_enemies, state,
	]''')

open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('dungeon ok')

# --- Вороги більше не бачать героя в димовій завісі ---
path = 'scenes/dungeon/enemy_3d.gd'
s = open(path, encoding='utf-8').read()
rep('''## Помітив — переслідує; поки не втік далеко, не забуває.
func _update_aggro(distance: float) -> void:
	if not _aggro and distance <= aggro_range:''',
    '''## Помітив — переслідує; поки не втік далеко, не забуває.
##
## Героя, що сховався (димова завіса асасина), ворог не бачить узагалі:
## губить ціль і кидає замах.
func _update_aggro(distance: float) -> void:
	if _player.has_method("is_targetable") and not _player.is_targetable():
		if _aggro:
			_aggro = false
			_cancel_windup()
		return
	if not _aggro and distance <= aggro_range:''')
open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('enemy ok')
