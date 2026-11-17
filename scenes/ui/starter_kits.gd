extends Control

## СПОРЯДЖЕННЯ КЛАСІВ — крамниця Наставниці Дарини. П'ять класів:
## Мечник, Танк, Маг, Лучник, Друїд. У кожного — зброя й сет броні з
## чотирьох речей. Клас вирішує ЗБРОЯ в руках (вона дає прийоми), броня
## лише підсилює. Згори Дарина з портретом пояснює це новачкові —
## сторінка за сторінкою, поки в нього немає жодної класової зброї.

const WEAPON_PRICE := 150
const SET_PRICE := 300
const CARD_WIDTH := 178.0
const KITS := [
	{"title": "Мечник", "icon": "tal_branch_knight", "weapon": "iron_sword",
		"set": ["knight_hood", "knight_coat", "knight_legs", "knight_boots"],
		"text": "Швидкий клинок і ривок крізь ворогів. Лють росте з кожним ударом."},
	{"title": "Танк", "icon": "tal_branch_tank", "weapon": "guard_sword",
		"set": ["tank_hood", "tank_coat", "tank_legs", "tank_boots"],
		"text": "Меч і щит. Найбільше здоров'я й броні, оглушує щитом, стоїть стіною."},
	{"title": "Маг", "icon": "tal_branch_mage", "weapon": "oak_staff",
		"set": ["mage_cowl", "mage_robe", "mage_pants", "mage_shoes"],
		"text": "Чари здалеку. Прийоми живляться маною — вона сама відновлюється."},
	{"title": "Лучник", "icon": "tal_branch_archer", "weapon": "hunter_bow",
		"set": ["archer_hood", "archer_jacket", "archer_pants", "archer_boots"],
		"text": "Прудкий стрілець: тримає дистанцію й косить натовп віялом стріл."},
	{"title": "Друїд", "icon": "tal_branch_druid", "weapon": "druid_staff",
		"set": ["druid_hood", "druid_mantle", "druid_pants", "druid_boots"],
		"text": "Чари природи, а в бою — Ведмідь-броненосець чи прудкий вовк Фенрір."},
]
## Навчання від Дарини (поки гравець не має жодної класової зброї).
const LESSON := [
	"Ага, новенький! Я — Дарина. Тридцять зим одягаю героїв Прихистку, тож слухай уважно: у підземеллі вчитися буде пізно.",
	"Головне правило: ким ти є — вирішує зброя в руках. Меч — і ти мечник. Меч зі щитом — танк. Посох — маг, лук — лучник, а посох друїда навчить ставати звіром.",
	"Броня лише підсилює. Вдягнеш латну куртку танка й візьмеш посох — будеш магом у залізі: міцним, але щитом не вдариш. А в мантії мага з мечем — жодного закляття.",
	"Тож бери зброю свого класу й сет броні до неї — вони підсилюють одне одного. Старійшина за перші доручення дасть досить золота саме на це.",
	"Передумаєш — вертайся. Клас змінюється будь-коли: просто візьми в руки іншу зброю. Ну що, кого з тебе зробимо?",
]
const GREETING := "Знову ти! Пам'ятай: клас вирішує зброя в руках, а броня — підсилює. Що візьмеш сьогодні?"

var _gold_badge: CurrencyBadge
var _cards: HBoxContainer
var _speech: Label
var _next: Button
var _page := 0
var _lesson := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.add_background(self, [UiTheme.BG_HEROES], 0.45)

	var back := TextureButton.new()
	back.texture_normal = load(UiTheme.KIT_DIR + "btn_back.png")
	back.ignore_texture_size = true
	back.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back.size = Vector2(58, 58)
	back.position = Vector2(18, 14)
	back.pressed.connect(func() -> void: GameState.return_from_ui())
	add_child(back)
	_gold_badge = CurrencyBadge.new(&"gold", 19)
	_gold_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_gold_badge.offset_left = -150.0
	_gold_badge.offset_right = -18.0
	_gold_badge.offset_top = 20.0
	add_child(_gold_badge)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 90.0
	column.offset_right = -170.0
	column.offset_top = 8.0
	column.offset_bottom = -8.0
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	column.add_child(_build_speech())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 6)
	center.add_child(_cards)
	# Картки ширші за вузький екран — тоді розкладка тягнеться на всю ширину.
	column.offset_right = -18.0
	column.offset_left = 18.0

	_lesson = not _has_class_weapon()
	_page = 0
	_show_page()
	_refresh()

## Плашка з Дариною: портрет, ім'я, що каже, і кнопка «Далі».
func _build_speech() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.ACCENT))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(820, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = NpcDialog.portrait_of(&"mentor")
	portrait.custom_minimum_size = Vector2(104, 104)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 4)
	row.add_child(text_column)
	var name_label := Label.new()
	UiTheme.hud_text(name_label, 20, UiTheme.GOLD)
	name_label.text = "Наставниця Дарина"
	text_column.add_child(name_label)
	_speech = Label.new()
	UiTheme.hud_text(_speech, 17, UiTheme.TEXT)
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.custom_minimum_size = Vector2(560, 0)
	text_column.add_child(_speech)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(110, 46)
	_next.add_theme_font_size_override("font_size", 17)
	_next.size_flags_vertical = Control.SIZE_SHRINK_END
	UiTheme.jelly(_next, "green")
	_next.pressed.connect(_on_next)
	row.add_child(_next)
	return panel

func _show_page() -> void:
	if _lesson:
		_speech.text = LESSON[_page]
		_next.text = "Далі ▸" if _page < LESSON.size() - 1 else "Ясно!"
		_next.visible = true
	else:
		_speech.text = GREETING
		_next.text = "Нагадай"
		_next.visible = true

func _on_next() -> void:
	if not _lesson:
		_lesson = true
		_page = 0
	elif _page < LESSON.size() - 1:
		_page += 1
	else:
		_lesson = false
	_show_page()

func _refresh() -> void:
	_gold_badge.set_amount(GameState.gold)
	for child in _cards.get_children():
		child.queue_free()
	for kit: Dictionary in KITS:
		_cards.add_child(_make_card(kit))

func _make_card(kit: Dictionary) -> Control:
	var panel := OrnatePanel.new()
	# Рамка картки тонша за звичайну панель — щоб усі п'ять класів стали в ряд.
	var frame := UiTheme.panel_box().duplicate() as StyleBox
	frame.content_margin_left = 20.0
	frame.content_margin_right = 20.0
	frame.content_margin_top = 18.0
	frame.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", frame)
	panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	head.add_child(_icon(ArtSlots.kit_icon(String(kit.icon)), 50))
	var name_label := _label(String(kit.title), 21, UiTheme.HEADING)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_label)
	var text := _label(String(kit.text), 13, Color(0.95, 0.93, 0.86))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	box.add_child(text)

	for skill_id: StringName in _skills_of(String(kit.weapon)):
		var skill := Skills3D.create_skill(skill_id)
		if skill == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		var skill_icon := _icon(ArtSlots.skill_icon(skill_id), 28)
		skill_icon.tooltip_text = skill.description
		row.add_child(skill_icon)
		var skill_name := _label(skill.title, 13, Color.WHITE)
		skill_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(skill_name)
		box.add_child(row)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	# Зброя — вона й робить тебе цим класом.
	var weapon_base := String(kit.weapon)
	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 6)
	var weapon_icon := _icon(ItemDb.icon_of({"base": weapon_base}), 38)
	weapon_icon.tooltip_text = String(ItemDb.BASES[weapon_base].title)
	weapon_row.add_child(weapon_icon)
	var weapon_button := _button()
	weapon_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _equipped_base("weapon") == weapon_base:
		weapon_button.text = "У руках ✓"
		weapon_button.disabled = true
		UiTheme.jelly(weapon_button, "green")
		weapon_button.add_theme_stylebox_override("disabled", UiTheme.jelly_box("green"))
	elif _owned(weapon_base) != "":
		weapon_button.text = "Взяти в руки"
		UiTheme.jelly(weapon_button, "blue")
		weapon_button.pressed.connect(_wear.bind([weapon_base], String(kit.title)))
	else:
		weapon_button.text = "Зброя %d" % WEAPON_PRICE
		UiTheme.jelly(weapon_button, "gold")
		weapon_button.disabled = GameState.gold < WEAPON_PRICE
		weapon_button.pressed.connect(_buy.bind([weapon_base], WEAPON_PRICE, String(kit.title)))
	weapon_row.add_child(weapon_button)
	box.add_child(weapon_row)

	# Сет броні з чотирьох речей.
	var set_icons := HBoxContainer.new()
	set_icons.add_theme_constant_override("separation", 0)
	for base_id: String in kit.set:
		var piece := _icon(ItemDb.icon_of({"base": base_id}), 38)
		piece.tooltip_text = String(ItemDb.BASES[base_id].title)
		piece.self_modulate = ItemDb.BASES[base_id].get("tint", Color.WHITE)
		set_icons.add_child(piece)
	box.add_child(set_icons)
	var set_button := _button()
	var worn := 0
	var owned := 0
	for base_id: String in kit.set:
		if _owned(base_id) != "":
			owned += 1
		if _equipped_base(String(ItemDb.BASES[base_id].slot)) == base_id:
			worn += 1
	if worn == kit.set.size():
		set_button.text = "Сет на тобі ✓"
		set_button.disabled = true
		UiTheme.jelly(set_button, "green")
		set_button.add_theme_stylebox_override("disabled", UiTheme.jelly_box("green"))
	elif owned == kit.set.size():
		set_button.text = "Вдягти сет"
		UiTheme.jelly(set_button, "blue")
		set_button.pressed.connect(_wear.bind(kit.set, String(kit.title)))
	else:
		set_button.text = "Сет броні %d" % SET_PRICE
		UiTheme.jelly(set_button, "gold")
		set_button.disabled = GameState.gold < SET_PRICE
		set_button.pressed.connect(_buy.bind(kit.set, SET_PRICE, String(kit.title)))
	box.add_child(set_button)
	return panel

## Прийоми, які дає зброя: прийоми класу + особлива здібність посоха.
func _skills_of(weapon_base: String) -> Array[StringName]:
	var result: Array[StringName] = []
	var weapon := WeaponPool.get_def(StringName(ItemDb.BASES[weapon_base].weapon))
	if weapon == null:
		return result
	result.append_array(HeroPool.get_def(weapon.hero_id).skill_ids)
	if weapon.staff_skill != &"":
		result.append(weapon.staff_skill)
	return result

func _equipped_base(slot: String) -> String:
	return String(ItemDb.equipped_items().get(slot, {}).get("base", ""))

## uid речі цієї заготовки, якщо вона є (у торбі чи надіта).
func _owned(base_id: String) -> String:
	for list: Array in [GameState.equipped_store, GameState.inventory]:
		for item: Dictionary in list:
			if String(item.get("base", "")) == base_id:
				return String(item.uid)
	return ""

func _has_class_weapon() -> bool:
	for kit: Dictionary in KITS:
		if _owned(String(kit.weapon)) != "":
			return true
	return false

func _buy(bases: Array, price: int, class_title: String) -> void:
	if GameState.gold < price:
		return
	GameState.gold -= price
	for base_id: String in bases:
		var item := ItemDb.roll(base_id, "common")
		ItemDb.give(item)
		ItemDb.equip(item.uid)
	SaveManager.save_game()
	_say_bought(bases, class_title)
	_refresh()

func _wear(bases: Array, class_title: String) -> void:
	for base_id: String in bases:
		var uid := _owned(base_id)
		if uid != "":
			ItemDb.equip(uid)
	SaveManager.save_game()
	_say_bought(bases, class_title)
	_refresh()

## Дарина коментує покупку — і нагадує, якщо броня й зброя різних класів.
func _say_bought(bases: Array, class_title: String) -> void:
	_lesson = false
	var weapon_class := String(ItemDb.BASES.get(_equipped_base("weapon"), {}).get("class", ""))
	var chest_class := String(ItemDb.BASES.get(_equipped_base("chest"), {}).get("class", ""))
	if bases.size() == 1:
		_speech.text = "Тепер ти — %s! Відчуваєш, як зброя лягає в руку? Нові прийоми вже чекають у бою." % class_title
	else:
		_speech.text = "Сет «%s» на тобі. Сидить як влитий!" % class_title
	if weapon_class != "" and chest_class != "" and chest_class != "any" and weapon_class != chest_class:
		_speech.text += " Але зважай: у руках зброя класу «%s», тож і прийоми — його. Броня лише підсилює." % ItemDb.CLASSES.get(weapon_class, weapon_class)
	_next.text = "Нагадай"

func _button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 14)
	return button

func _icon(texture: Texture2D, size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", UiTheme.OUTLINE)
	label.add_theme_constant_override("outline_size", 5)
	return label
