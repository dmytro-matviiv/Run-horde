import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:80])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


edit('scenes/dungeon/enemy_3d.gd', [
('''## Риси еліти; null — звичайний ворог.
var elite: EliteAffixes
''', '''## Риси еліти; null — звичайний ворог.
var elite: EliteAffixes
## Фази боса (лише в боса).
var phases: BossPhases
'''),
('''	if elite != null:
		add_child(elite)
		elite.attach(self, _player)

func is_alive() -> bool:''', '''	if elite != null:
		add_child(elite)
		elite.attach(self, _player)
	if kind == Kind.BOSS:
		phases = BossPhases.new()
		add_child(phases)
		phases.attach(self, _player)

func is_alive() -> bool:'''),
('''func is_sleeping() -> bool:
	return _sleeping
''', '''func is_sleeping() -> bool:
	return _sleeping

## Чи помітив ворог героя (бос — чи почався бій).
func is_aggro() -> bool:
	return _aggro and not _dying
'''),
])

edit('scenes/dungeon/dungeon.gd', [
('''## ВІДЧУТТЯ ВБИВСТВА.''', '''## СФЕРИ ЗДОРОВ'Я (HealthOrb): шанс, що випаде зі звичайного ворога й з еліти.
const HEALTH_ORB_CHANCE := 0.1
const HEALTH_ORB_ELITE_CHANCE := 0.7

## ВІДЧУТТЯ ВБИВСТВА.'''),
('''var _combo: ComboMeter
var _last_hp := 0.0
''', '''var _combo: ComboMeter
var _last_hp := 0.0
## Бос рівня і його велика смуга здоров'я внизу екрана.
var _boss: Enemy3D
var _boss_panel: Control
var _boss_bar: ProgressBar
'''),
('''	enemy.died.connect(_on_enemy_died.bind(enemy.kind, enemy.elite != null))
	if is_boss:
		enemy.summon_requested.connect(_on_summon_requested)''', '''	enemy.died.connect(_on_enemy_died.bind(enemy.kind, enemy.elite != null))
	if is_boss:
		enemy.summon_requested.connect(_on_summon_requested)
		enemy.phases.phase_changed.connect(_on_boss_phase)
		_boss = enemy'''),
('''	if is_boss:
		_boss_defeated = true
		_celebrate_boss(position)
		_open_exit()''', '''	if not is_boss and randf() < (HEALTH_ORB_ELITE_CHANCE if is_elite else HEALTH_ORB_CHANCE):
		var orb := HealthOrb.new()
		orb.setup(player)
		add_child(orb)
		orb.global_position = position + Vector3(0, DungeonBuilder.FLOOR_TOP, 0)
	if is_boss:
		_boss_defeated = true
		_celebrate_boss(position)
		_open_exit()'''),
('''func _on_combo_tier(tier: int, title: String) -> void:''', '''## Бос перейшов у нову фазу — великий напис.
func _on_boss_phase(phase: int, title: String) -> void:
	_show_banner(title, "швидший і небезпечніший" if phase == 2 else "останній ривок!")

## Смуга здоров'я боса внизу посередині: видно, щойно бій почався.
func _build_boss_bar() -> void:
	_boss_panel = VBoxContainer.new()
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_panel.offset_left = -230.0
	_boss_panel.offset_right = 230.0
	_boss_panel.offset_top = -78.0
	_boss_panel.offset_bottom = -30.0
	_boss_panel.add_theme_constant_override("separation", 2)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.hud_text(name_label, 18, UiTheme.HEADING)
	_boss_panel.add_child(name_label)
	_boss_bar = UiTheme.make_bar(Color(0.8, 0.16, 0.2), Vector2(460, 16))
	_boss_panel.add_child(_boss_bar)
	# Позначки фаз: на половині й чверті здоров'я бос змінюється.
	for threshold: float in BossPhases.THRESHOLDS:
		var tick := ColorRect.new()
		tick.color = Color(UiTheme.LINE, 0.8)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.size = Vector2(2, 16)
		tick.position = Vector2(460.0 * threshold - 1.0, 0)
		_boss_bar.add_child(tick)
	_boss_panel.visible = false
	hud.add_child(_boss_panel)

func _update_boss_bar() -> void:
	if _boss_panel == null:
		return
	var shown := _boss != null and is_instance_valid(_boss) and _boss.is_aggro()
	_boss_panel.visible = shown
	if shown:
		(_boss_panel.get_node("Name") as Label).text = _boss.display_name
		_boss_bar.max_value = _boss.max_hp
		_boss_bar.value = _boss.current_hp

func _on_combo_tier(tier: int, title: String) -> void:'''),
('''	# Серія ударів — праворуч над бойовими кнопками.''', '''	_build_boss_bar()
	# Серія ударів — праворуч над бойовими кнопками.'''),
('''func _process(delta: float) -> void:
	_update_shrine_label()''', '''func _process(delta: float) -> void:
	_update_shrine_label()
	_update_boss_bar()'''),
])
print('ok')
