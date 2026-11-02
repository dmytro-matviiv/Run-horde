# -*- coding: utf-8 -*-
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/dungeon/dungeon.gd", [
    ('''const BASE_SCENE_PATH := "res://scenes/world/base_island.tscn"
''', '''const BASE_SCENE_PATH := "res://scenes/world/base_island.tscn"
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
## Воскресіння за відео: частка здоров'я й щит (с). Раз за похід.
const REVIVE_HP := 0.8
const REVIVE_SHIELD := 3.0
'''),
    ('''var _boss_spot := Vector3.ZERO
''', '''var _boss_spot := Vector3.ZERO
## Скільки секунд триває похід (для підсумків) і чи вже воскресали.
var _run_time := 0.0
var _revive_used := false
var _results: RunResults
'''),
    ('''func _process(delta: float) -> void:
''', '''func _process(delta: float) -> void:
	if not _run_over:
		_run_time += delta
'''),
    ('''func _on_player_died() -> void:
	_run_over = true
	_hud_gold.visible = false
	status_label.text = "Ви загинули. Повертаємось на базу…"
	await get_tree().create_timer(2.0).timeout
	SceneLoader.change_scene(BASE_SCENE_PATH, "База")''', '''## Герой упав. Раз за похід можна повернутись у бій за відео (80%
## здоров'я й щит на 3 с); відмовився — підсумки поразки.
func _on_player_died() -> void:
	# Мить на анімацію падіння, а вже тоді вікно.
	await get_tree().create_timer(1.1).timeout
	if _revive_used:
		_show_results(false)
		return
	_offer_revive()

func _offer_revive() -> void:
	get_tree().paused = true
	var dialog := OrnateDialog.new("Ти впав!", ArtSlots.shop_icon("remove_ads") if false else null,
		Color(1.0, 0.4, 0.35), 560.0, "Останній шанс")
	dialog.closable = false
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.add_text("Переглянь коротке відео — і повернешся в бій з 80% здоров'я та золотим щитом на 3 секунди.")
	dialog.add_text("Перезарядка здібностей лишиться, як була, а перекат буде готовий одразу.", 15,
		Color(1, 1, 1, 0.75))
	dialog.add_button("Відео: воскреснути", true, func() -> void:
		dialog.close()
		AdsManager.show_rewarded_ad(_on_revive_watched, _on_revive_skipped), 300.0)
	dialog.add_button("Здатися", false, func() -> void:
		dialog.close()
		_show_results(false), 200.0)
	hud.add_child(dialog)

func _on_revive_watched() -> void:
	_revive_used = true
	get_tree().paused = false
	player.revive(REVIVE_HP, REVIVE_SHIELD)
	_show_banner("Знову в бою!", "щит на %d с" % int(REVIVE_SHIELD))

## Відео закрили раніше — пропозиція лишається (можна передумати й здатись).
func _on_revive_skipped() -> void:
	_offer_revive()

## ПІДСУМКИ ПОХОДУ (RunResults): табличка перемоги чи поразки — шкода
## героя, золото, час, дві здібності й зброя.
func _show_results(victory: bool) -> void:
	if _results != null:
		return
	_run_over = true
	get_tree().paused = true
	_results = RunResults.new()
	_results.process_mode = Node.PROCESS_MODE_ALWAYS
	_results.setup(_results_data(victory))
	_results.home_pressed.connect(_leave_to.bind(MAIN_MENU_PATH, "Меню"))
	_results.town_pressed.connect(_leave_to.bind(BASE_SCENE_PATH, "Місто"))
	_results.double_pressed.connect(_on_double_gold_pressed)
	hud.add_child(_results)

func _results_data(victory: bool) -> Dictionary:
	var meter: Dictionary = player.damage_by_source
	var total := 0.0
	for value: float in meter.values():
		total += value
	var rows: Array = []
	var skills: Array = player.get_skills()
	for i in mini(skills.size(), 2):
		var skill: HeroSkill3D = skills[i]
		var icon := ArtSlots.skill_icon(skill.id)
		if icon == null:
			icon = ArtSlots.combat_icon(skill.icon_kind)
		rows.append({"title": skill.title, "icon": ArtSlots.icon_or_placeholder(icon, skill.color),
			"damage": float(meter.get(skill.id, 0.0)), "color": skill.color})
	var weapon: WeaponDef = player.weapon_def
	if weapon != null:
		rows.append({"title": weapon.title,
			"icon": ArtSlots.icon_or_placeholder(ArtSlots.weapon_icon(weapon.id, weapon.icon), weapon.color),
			"damage": float(meter.get(&"weapon", 0.0)), "color": weapon.color})
	return {
		"victory": victory,
		"level_title": _level.title,
		"seconds": int(_run_time),
		"gold": _run_gold,
		"total_damage": total,
		"hero_id": player.hero_def.id if player.hero_def != null else &"",
		"rows": rows,
		"can_double": _run_gold > 0,
	}

## Жовта кнопка: відео — і золото походу ще раз.
func _on_double_gold_pressed() -> void:
	AdsManager.show_rewarded_ad(func() -> void:
		GameState.add_gold(_run_gold)
		_run_gold *= 2
		if _results != null:
			_results.set_double_done(true, _run_gold),
		func() -> void:
			if _results != null:
				_results.allow_double_again())

func _leave_to(path: String, title: String) -> void:
	get_tree().paused = false
	SceneLoader.change_scene(path, title)'''),
    ('''	_add_gold(int(round(GOLD_FOR_CLEAR * _gold_scale)))
	GameState.unlock_next_dungeon_level()
	exit_button.visible = false
	_exit_choice = _build_exit_choice()
	hud.add_child(_exit_choice)''', '''	_add_gold(int(round(GOLD_FOR_CLEAR * _gold_scale)))
	GameState.unlock_next_dungeon_level()
	exit_button.visible = false
	_show_results(true)'''),
])
print("patched")
