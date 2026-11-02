import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:70])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


# --- данж ---
edit('scenes/dungeon/dungeon.gd', [
('''const LEVEL_UP_CHOICE_SCENE := preload("res://scenes/ui/level_up_choice.tscn")''',
 '''const LEVEL_UP_CHOICE_SCENE := preload("res://scenes/ui/level_up_choice.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")'''),
('''var _run_upgrades: Dictionary = {}
var _buff_bar: HFlowContainer
''', '''var _run_upgrades: Dictionary = {}
var _buff_bar: HFlowContainer
var _hud_title: Label
var _health_bar: ProgressBar
var _xp_bar: ProgressBar
var _pause_menu: Control
var _run_over := false
'''),
('''func _setup_hud(title: String) -> void:
	var joystick: Control = JOYSTICK_SCENE.instantiate()''', '''func _setup_hud(title: String) -> void:
	_style_hud()
	var joystick: Control = JOYSTICK_SCENE.instantiate()'''),
('''	combat_buttons.setup(player)
	if not OS.has_feature("mobile"):
		_add_keyboard_hint()

	hud.move_child(exit_button, hud.get_child_count() - 1)

	exit_button.visible = false
	exit_button.pressed.connect(_on_exit_pressed)
	_update_status(title)
''', '''	combat_buttons.setup(player)
	if not OS.has_feature("mobile"):
		_add_keyboard_hint()
	_add_pause_button()

	hud.move_child(exit_button, hud.get_child_count() - 1)

	UiTheme.make_primary(exit_button)
	exit_button.visible = false
	exit_button.pressed.connect(_on_exit_pressed)
	_update_status(title)
	_on_player_health_changed(player.current_hp, player.max_hp)

## Лівий верхній кут — панель у рамці теми (UiTheme): назва рівня й
## рівень героя, смуги здоров'я й досвіду, під ними золото, вороги й стан
## виходу. Узяті в поході здібності — плашками одразу під панеллю.
func _style_hud() -> void:
	var corner := VBoxContainer.new()
	corner.position = Vector2(12, 12)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_theme_constant_override("separation", 6)
	hud.add_child(corner)
	hud.move_child(corner, 0)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.hud_box())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)

	_hud_title = Label.new()
	UiTheme.hud_text(_hud_title, 18, UiTheme.HEADING)
	column.add_child(_hud_title)

	_health_bar = UiTheme.make_bar(Color(0.74, 0.18, 0.2), Vector2(300, 24))
	column.add_child(_health_bar)
	health_label.reparent(_health_bar, false)
	health_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.hud_text(health_label, 15)

	_xp_bar = UiTheme.make_bar(UiTheme.HEADING, Vector2(300, 7))
	column.add_child(_xp_bar)

	status_label.reparent(column, false)
	UiTheme.hud_text(status_label, 15, UiTheme.TEXT_DIM.lightened(0.25))

	_buff_bar = HFlowContainer.new()
	_buff_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_bar.add_theme_constant_override("h_separation", 6)
	_buff_bar.add_theme_constant_override("v_separation", 4)
	corner.add_child(_buff_bar)

## Пауза — угорі праворуч, іконка з набору. На ПК те саме робить Esc, на
## телефоні — ще й системна кнопка "назад".
func _add_pause_button() -> void:
	var button := UiTheme.make_icon_button("pause", 56.0, "Пауза")
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -68.0
	button.offset_right = -12.0
	button.offset_top = 12.0
	button.offset_bottom = 68.0
	button.pressed.connect(_open_pause)
	hud.add_child(button)

func _open_pause() -> void:
	if _run_over or get_tree().paused or _pause_menu != null or _exit_choice != null:
		return
	get_tree().paused = true
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(_pause_menu)
	# У данжі золото зараховується одразу — вихід забирає лише здібності
	# цього походу, тож і попередження інше, ніж у старому рані.
	_pause_menu.configure("Бій зупинено. Золото з цього походу вже твоє.",
		"Покинути данж",
		"Здібності цього походу зникнуть, золото лишиться. Вийти в місто?",
		"Так, у місто")
	_pause_menu.resumed.connect(_close_pause)
	_pause_menu.quit_confirmed.connect(func() -> void:
		_close_pause()
		_run_over = true
		SceneLoader.change_scene(BASE_SCENE_PATH, "Місто"))

func _close_pause() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	get_tree().paused = false
'''),
('''func _update_buffs() -> void:
	if _buff_bar == null:
		_buff_bar = HFlowContainer.new()
		_buff_bar.position = Vector2(16, 80)
		_buff_bar.size = Vector2(560, 0)
		_buff_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_buff_bar.add_theme_constant_override("h_separation", 6)
		_buff_bar.add_theme_constant_override("v_separation", 4)
		hud.add_child(_buff_bar)
		hud.move_child(_buff_bar, 0)
	for child in _buff_bar.get_children():''', '''func _update_buffs() -> void:
	for child in _buff_bar.get_children():'''),
('''		var box := UiTheme.make_box(Color(0.05, 0.06, 0.09, 0.72), 8, 1,
			player.hero_def.color if personal else Color(1, 1, 1, 0.35))''', '''		var box := UiTheme.make_box(Color(UiTheme.PANEL, 0.82), 3, 1,
			player.hero_def.color if personal else Color(UiTheme.LINE, 0.45))'''),
('''		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
		chip.add_child(label)''', '''		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", UiTheme.TEXT)
		chip.add_child(label)'''),
('''	hint.text = "   •   ".join(parts)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))''', '''	parts.append("Esc — пауза")
	hint.text = "   •   ".join(parts)
	UiTheme.hud_text(hint, 15, Color(UiTheme.TEXT, 0.7))'''),
('''	var state := "Бос попереду" if not _boss_defeated else "Вихід відчинено"
	status_label.text = "%s  •  рівень %d  •  досвід %d  •  золото %d  •  ворогів %d  •  %s" % [
		level_title, _hero_level, _xp, _run_gold, _alive_enemies, state,
	]''', '''	var state := "бос попереду" if not _boss_defeated else "вихід відчинено"
	_hud_title.text = "%s  •  рівень героя %d" % [level_title, _hero_level]
	status_label.text = "Золото %d   •   ворогів %d   •   %s" % [_run_gold, _alive_enemies, state]
	# Смужка досвіду — скільки лишилось до наступного вибору здібності.
	_xp_bar.max_value = XP_PER_LEVEL * _hero_level
	_xp_bar.value = _xp'''),
('''func _on_player_died() -> void:
	status_label.text = "Ви загинули. Повертаємось на базу…"''', '''func _on_player_died() -> void:
	_run_over = true
	status_label.text = "Ви загинули. Повертаємось на базу…"'''),
('''	health_label.text = "HP %d / %d" % [int(current), int(maximum)]''', '''	health_label.text = "%d / %d" % [ceili(current), int(maximum)]
	_health_bar.max_value = maximum
	_health_bar.value = current'''),
('''	var title := Label.new()
	title.text = "%s — пройдено!\\nЗолота за похід: %d" % [_level.title, _run_gold]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)''', '''	box.add_child(UiTheme.make_title("%s — пройдено!" % _level.title, 24))
	var reward := Label.new()
	reward.text = "Золота за похід: %d" % _run_gold
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_font_size_override("font_size", 20)
	reward.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(reward)'''),
('''## Удар, перекат і вихір з клавіатури герой ловить сам (див. player_3d).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneLoader.change_scene(BASE_SCENE_PATH, "База")''', '''## Удар, перекат і вихір з клавіатури герой ловить сам (див. player_3d).
## Esc — пауза (закриває її саме меню паузи: на паузі сюди нічого не
## доходить).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_pause()

## Системна кнопка "назад" на Android — теж пауза, а не миттєвий вихід.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_open_pause()'''),
])

# --- меню паузи ---
edit('scenes/ui/pause_menu.gd', [
('''func _ready() -> void:
	confirm_row.visible = false
''', '''func _ready() -> void:
	confirm_row.visible = false
	# Фентезійне оформлення (UiTheme): заголовок між розділювачами,
	# "Продовжити" — світла головна кнопка.
	var title := $Panel/VBoxContainer/TitleLabel as Label
	title.add_theme_color_override("font_color", UiTheme.HEADING)
	UiTheme.add_dividers(title)
	($Panel/VBoxContainer/HintLabel as Label).add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	($Panel/VBoxContainer/ConfirmRow/WarnLabel as Label).add_theme_color_override("font_color", UiTheme.DANGER)
	UiTheme.make_primary($Panel/VBoxContainer/ResumeButton as Button)

## Тексти під інший режим. У данжі золото зараховується одразу, тож
## вихід забирає лише здібності походу — і попередження інше.
func configure(hint: String, quit_text: String, warning: String, confirm_text: String) -> void:
	($Panel/VBoxContainer/HintLabel as Label).text = hint
	quit_button.text = quit_text
	($Panel/VBoxContainer/ConfirmRow/WarnLabel as Label).text = warning
	($Panel/VBoxContainer/ConfirmRow/ConfirmQuitButton as Button).text = confirm_text

## Esc або "назад" на телефоні — те саме, що "Продовжити".
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resumed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		resumed.emit()
'''),
])

# --- місто ---
edit('scenes/world/base_island.gd', [
('''	$HUD/MenuButton.pressed.connect(_on_menu_pressed)
	action_button.pressed.connect(_on_action_pressed)
	action_button.visible = false
''', '''	$HUD/MenuButton.pressed.connect(_on_menu_pressed)
	action_button.pressed.connect(_on_action_pressed)
	action_button.visible = false
	_style_hud()
'''),
('''## Прості коробки замість точної форми кожної моделі: для телефона це''', '''## Оформлення (UiTheme): золото й підказка — на напівпрозорій панелі в
## рамці, "Меню" — з іконкою набору, кнопка входу в будівлю — світла,
## головна дія екрана.
func _style_hud() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.hud_box())
	panel.position = Vector2(12, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	$HUD.add_child(panel)
	$HUD.move_child(panel, 0)
	gold_label.reparent(column, false)
	gold_label.add_theme_color_override("font_color", UiTheme.GOLD)
	var hint := $HUD/HintLabel as Label
	hint.reparent(column, false)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(400, 0)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)

	var menu := $HUD/MenuButton as Button
	menu.icon = UiTheme.control_icon("menu")
	menu.add_theme_constant_override("icon_max_width", 22)
	menu.add_theme_constant_override("h_separation", 8)
	UiTheme.make_primary(action_button)

## Прості коробки замість точної форми кожної моделі: для телефона це'''),
])

# --- головне меню: прибрати порожні рядки після видалених кнопок ---
edit('scenes/ui/main_menu.gd', [
('''	SceneLoader.change_scene("res://scenes/world/base_island.tscn", "База")




func _on_shop_pressed() -> void:''', '''	SceneLoader.change_scene("res://scenes/world/base_island.tscn", "База")

func _on_shop_pressed() -> void:'''),
])
print('ok')
