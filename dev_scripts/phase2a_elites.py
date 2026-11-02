import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:80])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


edit('scenes/dungeon/elite_affixes.gd', [
('''const SHIELD_HALF_ARC := deg_to_rad(70.0)''', '''const SHIELD_HALF_ARC := 1.2217   # 70 градусів'''),
])

edit('scenes/dungeon/enemy_3d.gd', [
('''## Смерть: блідо-блакитні іскри й хвиля''', '''## ЕЛІТА (EliteAffixes): у скільки разів більше здоров'я, шкоди, зросту
## й досвіду; смужка здоров'я золота.
const ELITE_HP := 2.2
const ELITE_DAMAGE := 1.25
const ELITE_SIZE := 1.25
const ELITE_XP := 4
const ELITE_BAR_COLOR := Color(1.0, 0.78, 0.3)

## Смерть: блідо-блакитні іскри й хвиля'''),
('''var display_name := ""
''', '''var display_name := ""
## Риси еліти; null — звичайний ворог.
var elite: EliteAffixes
'''),
('''## Бос: окремі числа й свій набір прийомів.''', '''## Зробити ворога елітним (до setup: зріст і здоров'я вже інші).
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

## Бос: окремі числа й свій набір прийомів.'''),
('''	_add_health_bar()
	_add_screen_notifier()

func is_alive() -> bool:''', '''	_add_health_bar()
	_add_screen_notifier()
	if elite != null:
		add_child(elite)
		elite.attach(self, _player)

func is_alive() -> bool:'''),
('''	_health_bar.setup(ENEMY_BAR_COLOR, target_height + hover + 0.45, is_boss, 1.0 if not is_boss else 1.8)''',
 '''	var color := ELITE_BAR_COLOR if elite != null else ENEMY_BAR_COLOR
	_health_bar.setup(color, target_height + hover + 0.45, is_boss or elite != null, 1.0 if not is_boss else 1.8)'''),
('''## Помітити героя одразу, хоч би де він був (засідка).''', '''## Куди дивиться ворог (кут повороту моделі й напрямок на підлозі).
func facing_angle() -> float:
	return _model.rotation.y

func facing_vector() -> Vector3:
	return _model_forward()

func is_sleeping() -> bool:
	return _sleeping

## Відновити здоров'я (цілитель-еліта лікує сусідів).
func heal(amount: float) -> void:
	if _dying:
		return
	current_hp = minf(current_hp + amount, max_hp)
	if _health_bar != null:
		_health_bar.set_ratio(current_hp / max_hp)

## Помітити героя одразу, хоч би де він був (засідка).'''),
('''	if _dying:
		return
	current_hp -= amount
	if not _aggro:''', '''	if _dying:
		return
	# Щит еліти спереду пропускає лише частину шкоди.
	if elite != null:
		amount *= elite.damage_factor(heavy)
	current_hp -= amount
	if not _aggro:'''),
('''func _die() -> void:
	# Убитий до вибуху — не вибухає; таран, убитий на бігу, падає.''', '''func _die() -> void:
	if elite != null:
		elite.on_death()
	# Убитий до вибуху — не вибухає; таран, убитий на бігу, падає.'''),
])

edit('scenes/dungeon/dungeon.gd', [
('''const CHAMPION_HP := 2.6
const CHAMPION_DAMAGE := 1.3
const CHAMPION_SIZE := 1.3
''', '''## Ватажок ще й еліта з двома рисами — тож власні множники скромні.
const CHAMPION_HP := 1.4
const CHAMPION_DAMAGE := 1.1
const CHAMPION_SIZE := 1.1

## ЕЛІТА: шанс, що звичайний ворог рівня виявиться елітним (EliteAffixes),
## і скільки золота дає елітний ворог порівняно зі звичайним.
const ELITE_CHANCE := [0.07, 0.1, 0.13]
const ELITE_GOLD := 3
'''),
('''	minion.xp = 1
	minion.erase("group")
	return minion''', '''	minion.xp = 1
	minion.minion = true
	minion.erase("group")
	return minion'''),
('''	champion.xp = int(best.get("xp", 3)) * 5
	champion.erase("group")
	return champion''', '''	champion.xp = int(best.get("xp", 3)) * 3
	champion.elite = 2
	champion.erase("group")
	return champion'''),
('''	if is_boss:
		enemy.configure_boss(definition, _hp_scale, _damage_scale)
	else:
		enemy.configure(definition, _hp_scale, _damage_scale)
''', '''	if is_boss:
		enemy.configure_boss(definition, _hp_scale, _damage_scale)
	else:
		enemy.configure(definition, _hp_scale, _damage_scale)
		var affix_count := int(definition.get("elite", 0))
		if affix_count == 0 and not definition.get("minion", false) \\
				and randf() < ELITE_CHANCE[mini(_level_index, ELITE_CHANCE.size() - 1)]:
			affix_count = 1
		if affix_count > 0:
			var pool: Array = EliteAffixes.INFO.keys()
			pool.shuffle()
			enemy.make_elite(pool.slice(0, affix_count))
'''),
('''	enemy.died.connect(_on_enemy_died.bind(enemy.kind))''', '''	enemy.died.connect(_on_enemy_died.bind(enemy.kind, enemy.elite != null))'''),
('''func _on_enemy_died(position: Vector3, xp_reward: int, kind: Enemy3D.Kind) -> void:
	_alive_enemies -= 1
	var is_boss := kind == Enemy3D.Kind.BOSS
	# Золото й досвід вилітають фонтаном і зараховуються, коли долетять до
	# героя (_on_loot_collected).
	var gold := int(round((GOLD_PER_BOSS if is_boss else GOLD_PER_KILL) * _gold_scale))
	_loot.burst(position, LootSwarm.Kind.GOLD, gold, 12 if is_boss else clampi(gold / 3, 1, 4))
	_loot.burst(position, LootSwarm.Kind.XP, xp_reward, 6 if is_boss else clampi(xp_reward, 1, 3))
	if is_boss:
		_boss_defeated = true
		_celebrate_boss(position)
		_open_exit()
	else:
		CombatVfx.hitstop(get_tree(), KILL_HITSTOP)''', '''func _on_enemy_died(position: Vector3, xp_reward: int, kind: Enemy3D.Kind, is_elite: bool) -> void:
	_alive_enemies -= 1
	var is_boss := kind == Enemy3D.Kind.BOSS
	# Золото й досвід вилітають фонтаном і зараховуються, коли долетять до
	# героя (_on_loot_collected). Еліта сипле втричі щедріше.
	var gold := int(round((GOLD_PER_BOSS if is_boss else GOLD_PER_KILL) * _gold_scale * (ELITE_GOLD if is_elite else 1)))
	var pieces := 12 if is_boss else (8 if is_elite else clampi(gold / 3, 1, 4))
	_loot.burst(position, LootSwarm.Kind.GOLD, gold, pieces)
	_loot.burst(position, LootSwarm.Kind.XP, xp_reward, 6 if is_boss or is_elite else clampi(xp_reward, 1, 3))
	if is_boss:
		_boss_defeated = true
		_celebrate_boss(position)
		_open_exit()
	elif is_elite:
		# Упала еліта — довша зупинка кадру й золота хвиля.
		CombatVfx.hitstop(get_tree(), KILL_HITSTOP * 2.0)
		CombatVfx.shockwave(self, position, 3.0, EliteAffixes.INFO[0].color.lerp(Color(1.0, 0.8, 0.3), 0.7), 0.45)
		player.shake_camera(0.12)
	else:
		CombatVfx.hitstop(get_tree(), KILL_HITSTOP)'''),
])
print('ok')
