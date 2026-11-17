extends Control

## ХРАМ ТАЛАНТІВ (у Мудреця). Угорі — вкладки п'яти класів; відкривається
## вкладка класу зброї в руках («твій клас»). Гілка — шість ярусів
## знизу вгору: ярус відкривається, коли в гілку вкладено досить очок.
## Вузли з рангами (2/5): характеристики, посилення прийомів,
## суперпасивки, суперздібності (золоті) й ключові (червоні).
## Праворуч — картка вибраного вузла з кнопкою «Вивчити».
## Кнопка «Здібності» — які 2 прийоми стоять у слотах бою: відкриті
## можна поставити, закриті показують, яким талантом відкриваються.

const CELL := 74.0
const SUPER_CELL := 86.0
const KIND_TITLES := {"stat": "Характеристика", "upgrade": "Посилення прийому", "proc": "Суперпасивка",
	"super": "Суперздібність", "keystone": "Ключовий талант"}
const KIND_COLORS := {"stat": Color(0.75, 0.75, 0.7), "upgrade": Color(0.45, 0.85, 1.0), "proc": Color(0.75, 0.55, 1.0),
	"super": Color(1.0, 0.8, 0.3), "keystone": Color(1.0, 0.4, 0.35)}
## Набори здібностей у вікні «Здібності» для кожного класу.
const LOADOUT_SETS := {"knight": ["knight"], "tank": ["tank"], "mage": ["mage"], "archer": ["archer"], "druid": ["fenrir", "bear"]}
const SET_TITLES := {"knight": "Мечник", "tank": "Танк", "mage": "Маг", "archer": "Лучник", "fenrir": "Фенрір", "bear": "Ведмідь"}

var _branch := "knight"
var _selected := ""
var _tabs := {}
var _tiers_box: VBoxContainer
var _card: VBoxContainer
var _points_label: Label
var _reset_button: Button
var _loadout_layer: Control
var _loadout_slot := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.add_background(self, [UiTheme.BG_TALENTS], 0.7)
	var current := TalentTree.current_class()
	_branch = current if current != "" else "knight"

	var back := TextureButton.new()
	back.texture_normal = load(UiTheme.KIT_DIR + "btn_back.png")
	back.ignore_texture_size = true
	back.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back.size = Vector2(58, 58)
	back.position = Vector2(18, 14)
	back.pressed.connect(func() -> void: GameState.return_from_ui())
	add_child(back)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 90.0
	root.offset_right = -14.0
	root.offset_top = 10.0
	root.offset_bottom = -10.0
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Вкладки класів + очки.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	root.add_child(top)
	for cls: String in TalentTree.CLASS_ORDER:
		var tab := Button.new()
		tab.custom_minimum_size = Vector2(150, 50)
		tab.add_theme_font_size_override("font_size", 16)
		tab.icon = ArtSlots.kit_icon(String(TalentTree.CLASSES[cls].icon))
		tab.expand_icon = true
		tab.add_theme_constant_override("icon_max_width", 34)
		tab.pressed.connect(_select_branch.bind(cls))
		top.add_child(tab)
		_tabs[cls] = tab
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_points_label = Label.new()
	UiTheme.hud_text(_points_label, 18, UiTheme.GOLD)
	_points_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_points_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)

	var tree_panel := PanelContainer.new()
	var frame := UiTheme.panel_box().duplicate() as StyleBox
	frame.content_margin_left = 18.0
	frame.content_margin_right = 18.0
	frame.content_margin_top = 14.0
	frame.content_margin_bottom = 14.0
	tree_panel.add_theme_stylebox_override("panel", frame)
	tree_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(tree_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tree_panel.add_child(scroll)
	_tiers_box = VBoxContainer.new()
	_tiers_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tiers_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_tiers_box)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(320, 0)
	side.add_theme_constant_override("separation", 8)
	body.add_child(side)
	var card_panel := PanelContainer.new()
	card_panel.add_theme_stylebox_override("panel", frame)
	card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(card_panel)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 8)
	card_panel.add_child(_card)
	var skills_button := Button.new()
	skills_button.text = "Здібності в бою"
	skills_button.custom_minimum_size = Vector2(0, 54)
	skills_button.add_theme_font_size_override("font_size", 19)
	UiTheme.jelly(skills_button, "gold")
	skills_button.pressed.connect(_open_loadout)
	side.add_child(skills_button)
	_reset_button = Button.new()
	_reset_button.custom_minimum_size = Vector2(0, 44)
	_reset_button.add_theme_font_size_override("font_size", 15)
	UiTheme.jelly(_reset_button, "red")
	_reset_button.pressed.connect(_on_reset)
	side.add_child(_reset_button)

	GameState.talents_changed.connect(_refresh)
	_refresh()

func _exit_tree() -> void:
	if GameState.talents_changed.is_connected(_refresh):
		GameState.talents_changed.disconnect(_refresh)

func _select_branch(cls: String) -> void:
	_branch = cls
	_selected = ""
	_refresh()

func _refresh() -> void:
	var current := TalentTree.current_class()
	for cls: String in _tabs:
		var tab: Button = _tabs[cls]
		var title := String(TalentTree.CLASSES[cls].title)
		var spent := TalentTree.points_spent(cls)
		tab.text = title + (" ★" if cls == current else "") + ("  %d" % spent if spent > 0 else "")
		UiTheme.jelly(tab, "green" if cls == _branch else "blue")
	_points_label.text = "Вільних очок: %d" % TalentTree.points_free()
	var cost := TalentTree.reset_cost()
	_reset_button.text = "Скинути таланти" + ("" if cost == 0 else " · %d золота" % cost)
	_reset_button.disabled = TalentTree.points_spent() == 0 or GameState.gold < cost
	_build_tiers()
	_build_card()

# --- яруси ---

func _build_tiers() -> void:
	for child in _tiers_box.get_children():
		child.queue_free()
	var tiers: Array = TalentTree.BRANCHES[_branch]
	# Згори — найвищий ярус: дерево «росте» знизу вгору.
	for t in range(tiers.size() - 1, -1, -1):
		var open := TalentTree.tier_open(_branch, t)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.modulate = Color.WHITE if open else Color(0.55, 0.55, 0.6)
		var label := Label.new()
		label.custom_minimum_size = Vector2(92, 0)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiTheme.hud_text(label, 14, UiTheme.HEADING if open else UiTheme.TEXT)
		var need := int(TalentTree.TIER_POINTS[t])
		label.text = "Ярус %d" % (t + 1) + ("" if open else "\n🔒 %d очок у гілці" % need)
		row.add_child(label)
		var cells := HBoxContainer.new()
		cells.add_theme_constant_override("separation", 14)
		cells.alignment = BoxContainer.ALIGNMENT_CENTER
		cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cells)
		for entry: Array in tiers[t]:
			cells.add_child(_make_cell(TalentTree.get_node(String(entry[0]))))
		_tiers_box.add_child(row)

func _make_cell(node: Dictionary) -> Control:
	var id := String(node.id)
	var kind := String(node.kind)
	var side := SUPER_CELL if kind in ["super", "keystone"] else CELL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.custom_minimum_size = Vector2(maxf(side, 104.0), 0)
	var button := Button.new()
	button.custom_minimum_size = Vector2(side, side)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rank := TalentTree.rank(id)
	var accent: Color = KIND_COLORS.get(kind, Color.WHITE)
	var box := UiTheme.slot_box(accent if rank > 0 else Color(0.6, 0.6, 0.6))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(func() -> void:
		_selected = id
		_build_card())
	var icon := TextureRect.new()
	icon.texture = ArtSlots.kit_icon(String(node.icon))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6.0
	icon.offset_top = 6.0
	icon.offset_right = -6.0
	icon.offset_bottom = -6.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rank == 0:
		icon.modulate = Color(0.55, 0.55, 0.55) if not TalentTree.can_learn(id) else Color(0.85, 0.85, 0.85)
	button.add_child(icon)
	var badge := Label.new()
	UiTheme.hud_text(badge, 14, UiTheme.GOLD if rank >= int(node.max) else Color.WHITE)
	badge.text = "%d/%d" % [rank, int(node.max)]
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -38.0
	badge.offset_top = -22.0
	badge.offset_right = -4.0
	badge.offset_bottom = -2.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_child(badge)
	if TalentTree.can_learn(id):
		var plus := Label.new()
		UiTheme.hud_text(plus, 18, Color(0.5, 1.0, 0.5))
		plus.text = "+"
		plus.position = Vector2(5, 0)
		button.add_child(plus)
	if id == _selected:
		button.modulate = Color(1.25, 1.2, 1.0)
	column.add_child(button)
	var name_label := Label.new()
	UiTheme.hud_text(name_label, 12, accent if kind != "stat" else UiTheme.TEXT)
	name_label.text = String(node.title)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	return column

# --- картка вузла ---

func _build_card() -> void:
	for child in _card.get_children():
		child.queue_free()
	if _selected == "":
		_card_intro()
		return
	var node := TalentTree.get_node(_selected)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_card.add_child(head)
	var icon := TextureRect.new()
	icon.texture = ArtSlots.kit_icon(String(node.icon))
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	var name_label := Label.new()
	UiTheme.hud_text(name_label, 21, UiTheme.GOLD)
	name_label.text = String(node.title)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(name_label)
	var kind_label := Label.new()
	UiTheme.hud_text(kind_label, 14, KIND_COLORS.get(String(node.kind), Color.WHITE))
	kind_label.text = "%s · ранг %d з %d" % [KIND_TITLES.get(String(node.kind), ""), TalentTree.rank(_selected), int(node.max)]
	titles.add_child(kind_label)
	var text := Label.new()
	UiTheme.hud_text(text, 16, UiTheme.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(280, 0)
	text.text = String(node.text)
	_card.add_child(text)
	if String(node.kind) == "super":
		var hint := Label.new()
		UiTheme.hud_text(hint, 14, Color(0.7, 1.0, 0.6))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(280, 0)
		hint.text = "Після вивчення постав її в слот: кнопка «Здібності в бою»."
		_card.add_child(hint)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card.add_child(spacer)
	var learn := Button.new()
	learn.custom_minimum_size = Vector2(0, 52)
	learn.add_theme_font_size_override("font_size", 19)
	var rank := TalentTree.rank(_selected)
	if rank >= int(node.max):
		learn.text = "Вивчено повністю ✓"
		learn.disabled = true
		UiTheme.jelly(learn, "green")
		learn.add_theme_stylebox_override("disabled", UiTheme.jelly_box("green"))
	elif not TalentTree.tier_open(String(node.branch), int(node.tier)):
		learn.text = "Ярус закрито: %d очок у гілці" % int(TalentTree.TIER_POINTS[int(node.tier)])
		learn.disabled = true
		UiTheme.jelly(learn, "grey")
	elif TalentTree.points_free() <= 0:
		learn.text = "Немає вільних очок"
		learn.disabled = true
		UiTheme.jelly(learn, "grey")
	else:
		learn.text = "Вивчити (1 очко)"
		UiTheme.jelly(learn, "green")
		learn.pressed.connect(func() -> void: TalentTree.learn(_selected))
	_card.add_child(learn)

## Без вибраного вузла — про клас: атрибут, правило зброї, скільки вкладено.
func _card_intro() -> void:
	var info: Dictionary = TalentTree.CLASSES[_branch]
	var attribute: Dictionary = TalentTree.ATTRIBUTES[String(info.attribute)]
	var title := Label.new()
	UiTheme.hud_text(title, 24, UiTheme.GOLD)
	title.text = String(info.title)
	_card.add_child(title)
	var lines := PackedStringArray()
	lines.append("Основний атрибут — %s: кожне очко дає %s." % [String(attribute.title).to_lower(), attribute.text])
	lines.append("Гілка працює лише тоді, коли в руках зброя цього класу.")
	if TalentTree.current_class() == _branch:
		lines.append("★ Це твій клас зараз.")
	else:
		lines.append("Зараз у руках інша зброя — ці таланти чекатимуть, поки візьмеш зброю класу «%s»." % info.title)
	lines.append("Вкладено в гілку: %d очок." % TalentTree.points_spent(_branch))
	lines.append("Натисни на вузол, щоб побачити опис.")
	var text := Label.new()
	UiTheme.hud_text(text, 16, UiTheme.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(280, 0)
	text.text = "\n\n".join(lines)
	_card.add_child(text)

func _on_reset() -> void:
	TalentTree.reset()

# --- здібності в слотах ---

func _staff_skill() -> String:
	var weapon_item: Dictionary = ItemDb.equipped_items().get("weapon", {})
	var weapon_id := String(ItemDb.base_of(weapon_item).get("weapon", ""))
	var weapon := WeaponPool.get_def(StringName(weapon_id)) if weapon_id != "" else null
	return String(weapon.staff_skill) if weapon != null and weapon.staff_skill != &"" else ""

func _open_loadout() -> void:
	if _loadout_layer != null:
		_loadout_layer.queue_free()
	_loadout_layer = Control.new()
	_loadout_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_loadout_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loadout_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.ACCENT))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loadout_layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(760, 0)
	panel.add_child(column)
	var title := Label.new()
	UiTheme.hud_text(title, 24, UiTheme.GOLD)
	title.text = "Здібності в бою — %s" % TalentTree.CLASSES[_branch].title
	column.add_child(title)
	var hint := Label.new()
	UiTheme.hud_text(hint, 15, UiTheme.TEXT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "У бою — удар, 2 здібності й перекат. Обери слот, потім натисни відкриту здібність. Закриті відкриваються суперталантами гілки."
	column.add_child(hint)
	for set_id: String in LOADOUT_SETS[_branch]:
		column.add_child(_loadout_set(set_id))
	var close := Button.new()
	close.text = "Готово"
	close.custom_minimum_size = Vector2(200, 50)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 19)
	UiTheme.jelly(close, "green")
	close.pressed.connect(func() -> void:
		_loadout_layer.queue_free()
		_loadout_layer = null)
	column.add_child(close)

func _loadout_set(set_id: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var staff := _staff_skill() if set_id == "mage" else ""
	if LOADOUT_SETS[_branch].size() > 1:
		var name_label := Label.new()
		UiTheme.hud_text(name_label, 18, UiTheme.HEADING)
		name_label.text = SET_TITLES[set_id]
		box.add_child(name_label)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 10)
	box.add_child(slots)
	var current := TalentTree.loadout(set_id, staff)
	for slot in TalentTree.SKILL_SLOTS:
		var skill_id: String = current[slot] if slot < current.size() else ""
		var button := _skill_button(skill_id, true, "Слот %d" % (slot + 1))
		if slot == _loadout_slot:
			button.modulate = Color(1.3, 1.25, 0.9)
		button.pressed.connect(func() -> void:
			_loadout_slot = slot
			_open_loadout())
		slots.add_child(button)
	var arrow := Label.new()
	UiTheme.hud_text(arrow, 22, UiTheme.GOLD)
	arrow.text = "  ◀  "
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slots.add_child(arrow)
	for entry: Dictionary in TalentTree.skill_pool(set_id, staff):
		var pick := _skill_button(String(entry.id), bool(entry.open), "" if entry.open else "🔒")
		if entry.open:
			var chosen := String(entry.id)
			pick.pressed.connect(func() -> void:
				TalentTree.set_slot(set_id, _loadout_slot, chosen, staff)
				_open_loadout())
		else:
			pick.tooltip_text = "Відкривається суперталантом гілки"
		slots.add_child(pick)
	return box

func _skill_button(skill_id: String, open: bool, caption: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(92, 112)
	button.add_theme_stylebox_override("normal", UiTheme.slot_box(Color(1.0, 0.8, 0.3) if open else Color(0.5, 0.5, 0.5)))
	button.add_theme_stylebox_override("hover", UiTheme.slot_box(Color(1.0, 0.9, 0.5)))
	button.add_theme_stylebox_override("pressed", UiTheme.slot_box(Color(1.0, 0.9, 0.5)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var skill := Skills3D.create_skill(StringName(skill_id)) if skill_id != "" else null
	var icon := TextureRect.new()
	icon.texture = ArtSlots.skill_icon(StringName(skill_id)) if skill_id != "" else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(14, 8)
	icon.size = Vector2(64, 64)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not open:
		icon.modulate = Color(0.4, 0.4, 0.4)
	button.add_child(icon)
	var label := Label.new()
	UiTheme.hud_text(label, 12, Color.WHITE if open else Color(0.7, 0.7, 0.7))
	label.text = (skill.title if skill != null else "порожньо") + ("\n" + caption if caption != "" else "")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(2, 72)
	label.size = Vector2(88, 40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	if skill != null:
		button.tooltip_text = skill.description
	return button
