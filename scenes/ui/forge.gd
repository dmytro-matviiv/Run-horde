extends Control

## КУЗНЯ БОГДАНА — як крамниця в мобільних RPG:
##   зліва — класи (лише в «Купити»), посередині — вкладки «Зброя / Сети /
##   Інше» й сітка речей, справа — картка вибраної речі з цінами й кнопкою.
##   Сети показуються по одному: вибираєш рідкість — бачиш 4 речі сету й
##   бонуси за 2/3/4 (надіті — підсвічені).
##   Купити     — річ 1-го рівня; що ще не траплялось — під замком.
##   Покращити  — надіте й торба: +1 рівень (+8% чисел), до +10.
##   Продати    — торба; дешевше за купівлю, покращення повертається на 70%.

const CLASS_TABS := ["knight", "tank", "mage", "archer", "druid", "any"]
const CLASS_TITLES := {"knight": "Мечник", "tank": "Танк", "mage": "Маг", "archer": "Лучник", "druid": "Друїд", "any": "Загальне"}
const CLASS_ICONS := {"knight": "skill_whirlwind", "tank": "skill_shield_bash", "mage": "skill_fire_ring",
	"archer": "skill_piercing_shot", "druid": "skill_bear_form", "any": "menu_chest"}
const CAT_TITLES := {"weapons": "Зброя", "sets": "Сети броні", "other": "Інше"}
const PIECE_SLOTS := ["helmet", "chest", "legs", "boots"]
const GRID_TILE := 92.0
const SET_TILE := 104.0

var _mode := "buy"
var _class := "knight"
var _cat := "weapons"
var _set_rarity := "common"
var _selected := ""

var _gold_badge: CurrencyBadge
var _status: Label
var _mode_buttons := {}
var _class_buttons := {}
var _class_col: VBoxContainer
var _cat_row: HBoxContainer
var _content: VBoxContainer
var _detail: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.add_background(self, [UiTheme.BG_HEROES], 0.5)
	if TalentTree.current_class() != "":
		_class = TalentTree.current_class()

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 88.0
	root.offset_right = -16.0
	root.offset_top = 12.0
	root.offset_bottom = -10.0
	root.add_theme_constant_override("separation", 8)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Верх: режими, поступ колекції, золото.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	root.add_child(top)
	for mode: Array in [["buy", "Купити"], ["upgrade", "Покращити"], ["sell", "Продати"]]:
		var button := Button.new()
		button.text = mode[1]
		button.custom_minimum_size = Vector2(150, 48)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func() -> void:
			_mode = mode[0]
			_selected = ""
			_refresh())
		top.add_child(button)
		_mode_buttons[mode[0]] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_status = Label.new()
	UiTheme.hud_text(_status, 15, UiTheme.TEXT_DIM)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_status)
	_gold_badge = CurrencyBadge.new(&"gold", 19)
	top.add_child(_gold_badge)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)

	# Зліва — класи.
	_class_col = VBoxContainer.new()
	_class_col.add_theme_constant_override("separation", 6)
	_class_col.custom_minimum_size = Vector2(150, 0)
	body.add_child(_class_col)
	for cls: String in CLASS_TABS:
		var tab := Button.new()
		tab.text = CLASS_TITLES[cls]
		tab.icon = ArtSlots.kit_icon(CLASS_ICONS[cls])
		tab.expand_icon = false
		tab.add_theme_constant_override("icon_max_width", 34)
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size = Vector2(150, 56)
		tab.add_theme_font_size_override("font_size", 16)
		tab.pressed.connect(func() -> void:
			_class = cls
			_selected = ""
			_refresh())
		_class_col.add_child(tab)
		_class_buttons[cls] = tab

	# Посередині — вкладки й сітка.
	var center := PanelContainer.new()
	center.add_theme_stylebox_override("panel", _panel(36.0, 32.0))
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.clip_contents = true
	body.add_child(center)
	var center_box := VBoxContainer.new()
	center_box.add_theme_constant_override("separation", 10)
	center.add_child(center_box)
	_cat_row = HBoxContainer.new()
	_cat_row.add_theme_constant_override("separation", 6)
	center_box.add_child(_cat_row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_box.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)

	# Справа — картка вибраної речі.
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", _panel(36.0, 32.0))
	side.custom_minimum_size = Vector2(330, 0)
	body.add_child(side)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	side.add_child(_detail)

	var back := TextureButton.new()
	back.texture_normal = load(UiTheme.KIT_DIR + "btn_back.png")
	back.ignore_texture_size = true
	back.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back.size = Vector2(58, 58)
	back.position = Vector2(18, 14)
	back.pressed.connect(func() -> void: GameState.return_from_ui())
	add_child(back)
	_refresh()

func _panel(margin_h: float, margin_v: float) -> StyleBox:
	var frame := UiTheme.panel_box().duplicate() as StyleBox
	frame.content_margin_left = margin_h
	frame.content_margin_right = margin_h
	frame.content_margin_top = margin_v
	frame.content_margin_bottom = margin_v
	return frame

func _refresh() -> void:
	_gold_badge.set_amount(GameState.gold)
	for mode: String in _mode_buttons:
		UiTheme.jelly(_mode_buttons[mode], "green" if mode == _mode else "blue")
	for cls: String in _class_buttons:
		UiTheme.jelly(_class_buttons[cls], "gold" if cls == _class else "blue")
	_class_col.visible = _mode == "buy"
	_clear(_cat_row)
	_clear(_content)
	if _mode == "buy":
		_build_buy()
	else:
		_build_owned(_mode == "upgrade")
	_build_detail()

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

# --- купити ---

func _class_lists() -> Dictionary:
	var lists := {"weapons": [], "sets": [], "other": []}
	for id: String in ItemDb.BASES:
		var base: Dictionary = ItemDb.BASES[id]
		if String(base.get("class", "any")) != _class:
			continue
		if String(base.slot) == "weapon":
			lists.weapons.append(id)
		elif not base.has("set"):
			lists.other.append(id)
	for rarity: String in ItemDb.RARITIES:
		if ItemDb.SETS.has("%s_%s" % [_class, rarity]):
			lists.sets.append(rarity)
	var by_rarity := func(a: String, b: String) -> bool:
		return ItemDb.RARITIES.find(ItemDb.rarity_of_base(a)) < ItemDb.RARITIES.find(ItemDb.rarity_of_base(b))
	lists.weapons.sort_custom(by_rarity)
	lists.other.sort_custom(by_rarity)
	return lists

func _build_buy() -> void:
	var lists := _class_lists()
	var cats := []
	for cat: String in ["weapons", "sets", "other"]:
		if not (lists[cat] as Array).is_empty():
			cats.append(cat)
	if cats.is_empty():
		_content.add_child(_dim_label("Тут поки нічого немає."))
		return
	if not cats.has(_cat):
		_cat = cats[0]
	for cat: String in cats:
		var tab := Button.new()
		tab.text = CAT_TITLES[cat]
		tab.custom_minimum_size = Vector2(140, 40)
		tab.add_theme_font_size_override("font_size", 16)
		UiTheme.jelly(tab, "gold" if cat == _cat else "blue")
		tab.pressed.connect(func() -> void:
			_cat = cat
			_selected = ""
			_refresh())
		_cat_row.add_child(tab)

	if _cat == "sets":
		_build_set_view(lists.sets)
	else:
		var ids: Array = lists[_cat]
		if _selected == "" or not ids.has(_selected):
			_selected = ids[0]
		var grid := _grid()
		for id: String in ids:
			grid.add_child(_buy_tile(id, GRID_TILE, ""))
		_content.add_child(grid)

	var open := 0
	for id: String in ItemDb.BASES:
		if ItemDb.is_discovered(id):
			open += 1
	_status.text = "Колекція: %d / %d" % [open, ItemDb.BASES.size()]

func _build_set_view(rarities: Array) -> void:
	if not rarities.has(_set_rarity):
		_set_rarity = rarities[0]
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 5)
	_content.add_child(chips)
	for rarity: String in rarities:
		var chip := Button.new()
		chip.text = String(ItemDb.RARITY_TITLES[rarity])
		chip.custom_minimum_size = Vector2(0, 36)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.clip_text = true
		chip.add_theme_font_size_override("font_size", 12)
		UiTheme.jelly(chip, "gold" if rarity == _set_rarity else "grey")
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := chip.get_theme_stylebox(state)
			if style != null:
				style = style.duplicate()
				style.content_margin_left = 4.0
				style.content_margin_right = 4.0
				chip.add_theme_stylebox_override(state, style)
		if rarity != _set_rarity:
			chip.add_theme_color_override("font_color", ItemDb.RARITY_COLORS[rarity])
		chip.pressed.connect(func() -> void:
			_set_rarity = rarity
			_selected = ""
			_refresh())
		chips.add_child(chip)

	var set_id := "%s_%s" % [_class, _set_rarity]
	var info: Dictionary = ItemDb.SETS[set_id]
	var pieces: Array = info.pieces
	if _selected == "" or not pieces.has(_selected):
		_selected = pieces[0]
	var color: Color = ItemDb.RARITY_COLORS[_set_rarity]
	var open := 0
	for id: String in pieces:
		if ItemDb.is_discovered(id):
			open += 1
	var worn := int(ItemDb.worn_sets().get(set_id, 0))

	var head := HBoxContainer.new()
	var title := Label.new()
	UiTheme.hud_text(title, 21, color)
	title.text = String(info.title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var counts := Label.new()
	UiTheme.hud_text(counts, 14, UiTheme.TEXT_DIM)
	counts.text = "Відкрито %d/4  ·  Надіто %d/4" % [open, worn]
	counts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(counts)
	_content.add_child(head)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for i in pieces.size():
		row.add_child(_buy_tile(pieces[i], SET_TILE, ItemDb.SLOT_TITLES.get(PIECE_SLOTS[i] if i < 4 else "", "")))
	_content.add_child(row)

	var bonus_box := PanelContainer.new()
	bonus_box.add_theme_stylebox_override("panel", UiTheme.make_box(Color(0, 0, 0, 0.28), 12))
	var bonus_list := VBoxContainer.new()
	bonus_list.add_theme_constant_override("separation", 6)
	bonus_box.add_child(bonus_list)
	for need: int in info.bonus:
		bonus_list.add_child(_bonus_line(need, info.bonus[need], worn >= need, 15))
	_content.add_child(bonus_box)

## Рядок бонусу сету: кружечок з числом речей + опис; активний — яскравий.
func _bonus_line(need: int, effects: Dictionary, active: bool, font_size: int) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(30, 30)
	badge.add_theme_stylebox_override("panel", UiTheme.make_box(
		Color(0.35, 0.75, 0.3) if active else Color(0.22, 0.2, 0.24), 15, 2, UiTheme.GOLD if active else Color(0.45, 0.42, 0.45)))
	var number := Label.new()
	UiTheme.hud_text(number, 15, UiTheme.TEXT if active else UiTheme.TEXT_DIM)
	number.text = str(need)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(number)
	line.add_child(badge)
	var text := Label.new()
	UiTheme.hud_text(text, font_size, Color(0.7, 1.0, 0.6) if active else UiTheme.TEXT_DIM)
	text.text = ItemDb.describe_effects(effects)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(text)
	return line

func _buy_tile(base_id: String, side: float, caption: String) -> Control:
	var rarity := ItemDb.rarity_of_base(base_id)
	var open := ItemDb.is_discovered(base_id)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	card.add_child(_tile(ItemDb.icon_of({"base": base_id, "rarity": rarity}), rarity, not open,
		base_id == _selected, side, base_id, ""))
	if caption != "":
		var slot_label := Label.new()
		UiTheme.hud_text(slot_label, 12, UiTheme.TEXT_DIM)
		slot_label.text = caption
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(slot_label)
	var price := Label.new()
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if open:
		var cost := ItemDb.buy_price(base_id)
		UiTheme.hud_text(price, 14, UiTheme.GOLD if GameState.gold >= cost else UiTheme.DANGER)
		price.text = UiTheme.format_amount(cost)
	else:
		UiTheme.hud_text(price, 13, UiTheme.TEXT_DIM)
		price.text = "???"
	card.add_child(price)
	return card

## Клітинка речі: рамка кольору рідкості, замок, мітка, рамка вибору.
func _tile(icon: Texture2D, rarity: String, locked: bool, selected: bool, side: float, key: String, tag: String) -> Button:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(side, side)
	var box := UiTheme.slot_box(ItemDb.RARITY_COLORS.get(rarity, Color.WHITE) if not locked else Color(0.4, 0.4, 0.4))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		slot.add_theme_stylebox_override(state, box)
	var art := TextureRect.new()
	art.texture = icon
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := side * 0.1
	art.offset_left = pad
	art.offset_top = pad
	art.offset_right = -pad
	art.offset_bottom = -pad
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(art)
	if locked:
		art.modulate = Color(0.15, 0.15, 0.18, 0.85)
		var lock := TextureRect.new()
		lock.texture = load(UiTheme.KIT_DIR + "btn_lock.png")
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		var half := side * 0.22
		lock.offset_left = -half
		lock.offset_top = -half
		lock.offset_right = half
		lock.offset_bottom = half
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(lock)
	if tag != "":
		var mark := Label.new()
		UiTheme.hud_text(mark, 11, Color(0.7, 1.0, 0.6))
		mark.text = tag
		mark.position = Vector2(8, 4)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(mark)
	if selected:
		var ring := Panel.new()
		ring.add_theme_stylebox_override("panel", UiTheme.make_box(Color(1, 1, 1, 0.07), 12, 4, UiTheme.GOLD))
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ring.offset_left = -3
		ring.offset_top = -3
		ring.offset_right = 3
		ring.offset_bottom = 3
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ring)
	slot.pressed.connect(func() -> void:
		_selected = key
		_refresh())
	return slot

func _grid() -> HFlowContainer:
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	return grid

# --- покращити / продати ---

func _owned_items(upgrade: bool) -> Array:
	var items := []
	if upgrade:
		for slot: String in ItemDb.equipped_items():
			items.append(ItemDb.equipped_items()[slot])
	items.append_array(GameState.inventory)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return ItemDb.RARITIES.find(String(a.rarity)) > ItemDb.RARITIES.find(String(b.rarity)))
	return items

func _build_owned(upgrade: bool) -> void:
	var hint := Label.new()
	UiTheme.hud_text(hint, 16, UiTheme.HEADING)
	hint.text = "Надіте й торба" if upgrade else "Торба"
	_cat_row.add_child(hint)
	_status.text = "+8% до всіх чисел за рівень, до +10" if upgrade else "Покращення повертається на 70%"
	var items := _owned_items(upgrade)
	if items.is_empty():
		_selected = ""
		_content.add_child(_dim_label("Нічого немає." if upgrade else "У торбі порожньо — продавати нічого."))
		return
	var uids := items.map(func(item: Dictionary) -> String: return String(item.uid))
	if not uids.has(_selected):
		_selected = uids[0]
	var worn := GameState.equipment.values().map(func(v: Variant) -> String: return String(v))
	var grid := _grid()
	for item: Dictionary in items:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		var uid := String(item.uid)
		card.add_child(_tile(ItemDb.icon_of(item), String(item.rarity), false, uid == _selected, GRID_TILE, uid,
			"надіто" if worn.has(uid) else ""))
		var plus := Label.new()
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if upgrade:
			UiTheme.hud_text(plus, 13, UiTheme.TEXT if ItemDb.plus_of(item) > 0 else UiTheme.TEXT_DIM)
			plus.text = "+%d / %d" % [ItemDb.plus_of(item), ItemDb.MAX_PLUS]
		else:
			UiTheme.hud_text(plus, 14, UiTheme.GOLD)
			plus.text = UiTheme.format_amount(ItemDb.sell_price(item))
		card.add_child(plus)
		grid.add_child(card)
	_content.add_child(grid)

func _dim_label(text: String) -> Label:
	var label := Label.new()
	UiTheme.hud_text(label, 18, UiTheme.TEXT_DIM)
	label.text = text
	return label

# --- картка справа ---

func _build_detail() -> void:
	_clear(_detail)
	if _selected == "":
		_detail.add_child(_dim_label("Обери річ"))
		return
	if _mode == "buy":
		_detail_buy(_selected)
	else:
		var item := ItemDb.find(_selected)
		if item.is_empty():
			_detail.add_child(_dim_label("Обери річ"))
		else:
			_detail_owned(item)

func _detail_header(icon: Texture2D, rarity: String, locked: bool, title: String, sub: String) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var tile := _tile(icon, rarity, locked, false, 96, _selected, "")
	tile.disabled = true
	head.add_child(tile)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label := Label.new()
	UiTheme.hud_text(name_label, 20, UiTheme.TEXT_DIM if locked else ItemDb.RARITY_COLORS.get(rarity, Color.WHITE))
	name_label.text = title
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(name_label)
	var sub_label := Label.new()
	UiTheme.hud_text(sub_label, 13, UiTheme.TEXT_DIM)
	sub_label.text = sub
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(sub_label)
	head.add_child(names)
	_detail.add_child(head)
	_detail.add_child(HSeparator.new())

func _detail_body() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	scroll.add_child(body)
	return body

func _stat_line(parent: Control, stat: String, value: int, next: int = -1) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	UiTheme.hud_text(name_label, 15, UiTheme.TEXT_DIM)
	name_label.text = String(ItemDb.STATS[stat].title)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := Label.new()
	UiTheme.hud_text(value_label, 15, UiTheme.TEXT)
	var suffix := String(ItemDb.STATS[stat].suffix)
	value_label.text = "%d%s" % [value, suffix]
	row.add_child(value_label)
	if next >= 0:
		var next_label := Label.new()
		UiTheme.hud_text(next_label, 15, Color(0.7, 1.0, 0.6))
		next_label.text = "  →  %d%s" % [next, suffix]
		row.add_child(next_label)
	parent.add_child(row)

func _text(parent: Control, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	UiTheme.hud_text(label, font_size, color)
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

## Ефект речі й бонуси її сету (для купівлі й для своїх речей).
func _extras(body: VBoxContainer, base: Dictionary, rarity: String) -> void:
	var color: Color = ItemDb.RARITY_COLORS.get(rarity, Color.WHITE)
	if base.has("unique_text"):
		_text(body, "★ " + String(base.unique_text), 14, color)
	if base.has("set") and ItemDb.SETS.has(String(base.set)):
		var info: Dictionary = ItemDb.SETS[String(base.set)]
		var worn := int(ItemDb.worn_sets().get(String(base.set), 0))
		_text(body, "%s  (%d/4)" % [info.title, worn], 15, color)
		for need: int in info.bonus:
			body.add_child(_bonus_line(need, info.bonus[need], worn >= need, 13))

func _action(text: String, color_name: String, enabled: bool, on_press: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 18)
	UiTheme.jelly(button, color_name)
	button.disabled = not enabled
	button.pressed.connect(on_press)
	_detail.add_child(button)

func _detail_buy(base_id: String) -> void:
	var base: Dictionary = ItemDb.BASES[base_id]
	var rarity := ItemDb.rarity_of_base(base_id)
	var open := ItemDb.is_discovered(base_id)
	var sub := "%s · %s · %s" % [ItemDb.RARITY_TITLES[rarity], ItemDb.SLOT_TITLES.get(base.slot, ""), ItemDb.CLASSES.get(base.get("class", "any"), "")]
	_detail_header(ItemDb.icon_of({"base": base_id, "rarity": rarity}), rarity, not open,
		String(base.title) if open else "Ще не знайдено", sub)
	var body := _detail_body()
	if not open:
		_text(body, "Ця річ тобі ще не траплялась. Знайди її в данжі — і Богдан зможе її кувати.", 15, UiTheme.TEXT_DIM)
		_extras(body, base, rarity)
		_action("Не знайдено", "grey", false, func() -> void: pass)
		return
	var power: float = ItemDb.RARITY_POWER.get(rarity, 1.0)
	for stat: String in base.base:
		_stat_line(body, stat, roundi(float(base.base[stat]) * power))
	_extras(body, base, rarity)
	_text(body, "Нова річ 1-го рівня, без покращень.", 12, UiTheme.TEXT_DIM)
	var price := ItemDb.buy_price(base_id)
	var rich := GameState.gold >= price
	_action("Купити · %s" % UiTheme.format_amount(price) if rich else "Бракує золота · %s" % UiTheme.format_amount(price),
		"gold", rich, func() -> void:
			var item := ItemDb.buy(base_id)
			if not item.is_empty():
				_status.text = "Куплено: " + ItemDb.title_of(item)
			_refresh())

func _detail_owned(item: Dictionary) -> void:
	var base := ItemDb.base_of(item)
	var rarity := String(item.rarity)
	var uid := String(item.uid)
	var sub := "%s · %s · %s" % [ItemDb.RARITY_TITLES.get(rarity, ""), ItemDb.SLOT_TITLES.get(base.get("slot", ""), ""),
		ItemDb.CLASSES.get(base.get("class", "any"), "")]
	_detail_header(ItemDb.icon_of(item), rarity, false, ItemDb.title_of(item), sub)
	var body := _detail_body()
	var stats: Dictionary = item.get("stats", {})
	var plus := ItemDb.plus_of(item)
	var maxed := plus >= ItemDb.MAX_PLUS
	if _mode == "upgrade" and not maxed:
		var raw: Dictionary = item.get("raw", stats)
		for stat: String in stats:
			var next := maxi(int(raw.get(stat, stats[stat])) + 1, roundi(float(raw.get(stat, stats[stat])) * (1.0 + ItemDb.PLUS_STEP * (plus + 1))))
			_stat_line(body, stat, int(stats[stat]), next)
	else:
		for stat: String in stats:
			_stat_line(body, stat, int(stats[stat]))
	_extras(body, base, rarity)
	if _mode == "upgrade":
		_text(body, "Рівень покращення: +%d з %d" % [plus, ItemDb.MAX_PLUS], 13, UiTheme.TEXT_DIM)
		var cost := ItemDb.upgrade_cost(item)
		var text := "Максимум" if maxed else ("Покращити · %s" % UiTheme.format_amount(cost) if GameState.gold >= cost else "Бракує золота · %s" % UiTheme.format_amount(cost))
		_action(text, "green", not maxed and GameState.gold >= cost, func() -> void:
			if ItemDb.upgrade(uid):
				_status.text = "Покращено: " + ItemDb.title_of(ItemDb.find(uid))
			_refresh())
	else:
		var price := ItemDb.sell_price(item)
		_action("Продати · %s" % UiTheme.format_amount(price), "red", true, func() -> void:
			var got := ItemDb.sell(uid)
			_status.text = "Продано за %d" % got
			_selected = ""
			_refresh())
