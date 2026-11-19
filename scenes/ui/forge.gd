extends Control

## КУЗНЯ БОГДАНА. Три режими:
##   Купити     — уся зброя й броня гри, по класах; у класі — зброя (від
##                сірої до легендарної), далі сети (по одному на рідкість:
##                4 речі й бонуси за 2/3/4). Що ще не траплялось герою —
##                під замком; що хоч раз було (навіть продане) — відкрите.
##                Купівля — нова річ 1-го рівня, без покращень.
##   Покращити  — речі в торбі й на герої: +1 рівень (+8% чисел), до +10.
##   Продати    — речі з торби; ціна нижча за купівлю, але вкладене в
##                покращення повертається на 70%.

const CLASS_TABS := ["knight", "tank", "mage", "archer", "druid", "any"]
const CLASS_TITLES := {"knight": "Мечник", "tank": "Танк", "mage": "Маг", "archer": "Лучник", "druid": "Друїд", "any": "Загальне"}
const CARD := Vector2(112, 150)

var _mode := "buy"
var _class := "knight"
var _gold_badge: CurrencyBadge
var _mode_buttons := {}
var _class_buttons := {}
var _class_row: HBoxContainer
var _list: VBoxContainer
var _status: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.add_background(self, [UiTheme.BG_HEROES], 0.5)
	var current := TalentTree.current_class()
	if current != "":
		_class = current

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 88.0
	root.offset_right = -16.0
	root.offset_top = 10.0
	root.offset_bottom = -8.0
	root.add_theme_constant_override("separation", 6)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	for mode: Array in [["buy", "Купити"], ["upgrade", "Покращити"], ["sell", "Продати"]]:
		var button := Button.new()
		button.text = mode[1]
		button.custom_minimum_size = Vector2(170, 50)
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(func() -> void:
			_mode = mode[0]
			_refresh())
		top.add_child(button)
		_mode_buttons[mode[0]] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_status = Label.new()
	UiTheme.hud_text(_status, 16, Color(0.7, 1.0, 0.6))
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_status)
	_gold_badge = CurrencyBadge.new(&"gold", 19)
	top.add_child(_gold_badge)

	_class_row = HBoxContainer.new()
	_class_row.add_theme_constant_override("separation", 6)
	root.add_child(_class_row)
	for cls: String in CLASS_TABS:
		var tab := Button.new()
		tab.text = CLASS_TITLES[cls]
		tab.custom_minimum_size = Vector2(140, 42)
		tab.add_theme_font_size_override("font_size", 16)
		tab.pressed.connect(func() -> void:
			_class = cls
			_refresh())
		_class_row.add_child(tab)
		_class_buttons[cls] = tab

	var panel := PanelContainer.new()
	var frame := UiTheme.panel_box().duplicate() as StyleBox
	frame.content_margin_left = 18.0
	frame.content_margin_right = 18.0
	frame.content_margin_top = 12.0
	frame.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", frame)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	var back := TextureButton.new()
	back.texture_normal = load(UiTheme.KIT_DIR + "btn_back.png")
	back.ignore_texture_size = true
	back.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back.size = Vector2(58, 58)
	back.position = Vector2(18, 14)
	back.pressed.connect(func() -> void: GameState.return_from_ui())
	add_child(back)
	_refresh()

func _refresh() -> void:
	_gold_badge.set_amount(GameState.gold)
	for mode: String in _mode_buttons:
		UiTheme.jelly(_mode_buttons[mode], "green" if mode == _mode else "blue")
	for cls: String in _class_buttons:
		UiTheme.jelly(_class_buttons[cls], "gold" if cls == _class else "blue")
	_class_row.visible = _mode == "buy"
	for child in _list.get_children():
		child.queue_free()
	match _mode:
		"buy":
			_build_buy()
		"upgrade":
			_build_owned(true)
		_:
			_build_owned(false)

# --- купити ---

func _build_buy() -> void:
	var weapons := []
	var loose := []
	for id: String in ItemDb.BASES:
		var base: Dictionary = ItemDb.BASES[id]
		if String(base.get("class", "any")) != _class:
			continue
		if String(base.slot) == "weapon":
			weapons.append(id)
		elif not base.has("set"):
			loose.append(id)
	weapons.sort_custom(func(a: String, b: String) -> bool:
		return ItemDb.RARITIES.find(ItemDb.rarity_of_base(a)) < ItemDb.RARITIES.find(ItemDb.rarity_of_base(b)))
	if not weapons.is_empty():
		_list.add_child(_section("Зброя"))
		_list.add_child(_card_row(weapons))
	if _class != "any":
		_list.add_child(_section("Сети броні — бонуси за 2, 3 і 4 речі"))
		for rarity: String in ItemDb.RARITIES:
			var set_id := "%s_%s" % [_class, rarity]
			if ItemDb.SETS.has(set_id):
				_list.add_child(_set_block(set_id))
	if not loose.is_empty():
		_list.add_child(_section("Броня"))
		_list.add_child(_card_row(loose))
	var open := 0
	var total := 0
	for id: String in ItemDb.BASES:
		total += 1
		if ItemDb.is_discovered(id):
			open += 1
	_status.text = "Відкрито речей: %d з %d" % [open, total]

func _set_block(set_id: String) -> Control:
	var info: Dictionary = ItemDb.SETS[set_id]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := Label.new()
	UiTheme.hud_text(title, 18, ItemDb.RARITY_COLORS.get(info.rarity, Color.WHITE))
	title.text = "%s · %s" % [info.title, String(ItemDb.RARITY_TITLES[info.rarity])]
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	row.add_child(_card_row(info.pieces))
	var bonus := VBoxContainer.new()
	bonus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for need: int in info.bonus:
		var line := Label.new()
		UiTheme.hud_text(line, 14, UiTheme.TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(300, 0)
		line.text = "%d речі: %s" % [need, ItemDb.describe_effects(info.bonus[need])]
		bonus.add_child(line)
	row.add_child(bonus)
	return box

func _card_row(ids: Array) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for id: String in ids:
		flow.add_child(_shop_card(id))
	return flow

func _shop_card(base_id: String) -> Control:
	var base: Dictionary = ItemDb.BASES[base_id]
	var rarity := ItemDb.rarity_of_base(base_id)
	var open := ItemDb.is_discovered(base_id)
	var card := _card_shell(ItemDb.icon_of({"base": base_id, "rarity": rarity}), rarity, String(base.title), not open)
	var button := Button.new()
	button.custom_minimum_size = Vector2(CARD.x, 30)
	button.add_theme_font_size_override("font_size", 13)
	if open:
		button.text = "%d" % ItemDb.buy_price(base_id)
		UiTheme.jelly(button, "gold")
		button.disabled = GameState.gold < ItemDb.buy_price(base_id)
	else:
		button.text = "Не знайдено"
		UiTheme.jelly(button, "grey")
		button.disabled = true
	button.pressed.connect(_show_buy.bind(base_id))
	card.add_child(button)
	(card.get_child(0) as Button).pressed.connect(_show_buy.bind(base_id))
	return card

## Картка: кнопка-іконка в рамці кольору рідкості, назва; замок — якщо закрито.
func _card_shell(icon: Texture2D, rarity: String, title: String, locked: bool) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	card.custom_minimum_size = Vector2(CARD.x, 0)
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(CARD.x, CARD.x)
	var box := UiTheme.slot_box(ItemDb.RARITY_COLORS.get(rarity, Color.WHITE) if not locked else Color(0.4, 0.4, 0.4))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		slot.add_theme_stylebox_override(state, box)
	var art := TextureRect.new()
	art.texture = icon
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 10.0
	art.offset_top = 10.0
	art.offset_right = -10.0
	art.offset_bottom = -10.0
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		art.modulate = Color(0.15, 0.15, 0.18, 0.85)
		var lock := TextureRect.new()
		lock.texture = load(UiTheme.KIT_DIR + "btn_lock.png")
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lock.offset_left = -26.0
		lock.offset_top = -26.0
		lock.offset_right = 26.0
		lock.offset_bottom = 26.0
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(art)
		slot.add_child(lock)
	else:
		slot.add_child(art)
	card.add_child(slot)
	var name_label := Label.new()
	UiTheme.hud_text(name_label, 12, ItemDb.RARITY_COLORS.get(rarity, Color.WHITE) if not locked else UiTheme.TEXT_DIM)
	name_label.text = title if not locked else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(CARD.x, 0)
	card.add_child(name_label)
	return card

func _show_buy(base_id: String) -> void:
	var base: Dictionary = ItemDb.BASES[base_id]
	var rarity := ItemDb.rarity_of_base(base_id)
	var open := ItemDb.is_discovered(base_id)
	var dialog := OrnateDialog.new(String(base.title) if open else "Ще не знайдено", ItemDb.icon_of({"base": base_id}),
		ItemDb.RARITY_COLORS.get(rarity, Color.WHITE), 560.0,
		"%s • %s • %s" % [String(ItemDb.RARITY_TITLES[rarity]), ItemDb.SLOT_TITLES.get(base.slot, ""), ItemDb.CLASSES.get(base.get("class", "any"), "")])
	if not open:
		dialog.add_text("Ця річ ще жодного разу тобі не траплялась. Знайди її в данжі — і Богдан навчиться її кувати.", 16)
		dialog.add_button("Гаразд")
		add_child(dialog)
		return
	var power: float = ItemDb.RARITY_POWER.get(rarity, 1.0)
	var lines := PackedStringArray()
	for stat: String in base.base:
		lines.append("%s: %d%s" % [ItemDb.STATS[stat].title, roundi(float(base.base[stat]) * power), ItemDb.STATS[stat].suffix])
	dialog.add_text("\n".join(lines), 17)
	if base.has("unique_text"):
		dialog.add_text("★ " + String(base.unique_text), 16, ItemDb.RARITY_COLORS.get(rarity, Color.WHITE))
	if base.has("set") and ItemDb.SETS.has(String(base.set)):
		var info: Dictionary = ItemDb.SETS[String(base.set)]
		dialog.add_text(String(info.title), 16, ItemDb.RARITY_COLORS.get(rarity, Color.WHITE))
		for need: int in info.bonus:
			dialog.add_text("%d речі: %s" % [need, ItemDb.describe_effects(info.bonus[need])], 14, UiTheme.TEXT_DIM)
	var price := ItemDb.buy_price(base_id)
	dialog.add_text("Нова річ 1-го рівня, без покращень.", 13, UiTheme.TEXT_DIM)
	if GameState.gold >= price:
		dialog.add_button("Купити за %d" % price, true, func() -> void:
			var item := ItemDb.buy(base_id)
			if not item.is_empty():
				_status.text = "Куплено: " + ItemDb.title_of(item)
			dialog.close()
			_refresh(), 260.0)
	else:
		dialog.add_text("Не вистачає золота: потрібно %d." % price, 15, Color(1.0, 0.55, 0.45))
	dialog.add_button("Ні", false)
	add_child(dialog)

# --- покращити / продати ---

func _build_owned(upgrade: bool) -> void:
	var items := []
	if upgrade:
		for slot: String in ItemDb.equipped_items():
			items.append(ItemDb.equipped_items()[slot])
	items.append_array(GameState.inventory)
	_status.text = "Покращення: +8% до всіх чисел за рівень, до +10." if upgrade else "Продаж: третина ціни, вкладене в покращення — на 70%."
	if items.is_empty():
		var empty := Label.new()
		UiTheme.hud_text(empty, 18, UiTheme.TEXT_DIM)
		empty.text = "Нічого немає." if upgrade else "У торбі порожньо — продавати нічого."
		_list.add_child(empty)
		return
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return ItemDb.RARITIES.find(String(a.rarity)) > ItemDb.RARITIES.find(String(b.rarity)))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	_list.add_child(flow)
	for item: Dictionary in items:
		var card := _card_shell(ItemDb.icon_of(item), String(item.rarity), ItemDb.title_of(item), false)
		var button := Button.new()
		button.custom_minimum_size = Vector2(CARD.x, 30)
		button.add_theme_font_size_override("font_size", 13)
		var uid := String(item.uid)
		if upgrade:
			var maxed := ItemDb.plus_of(item) >= ItemDb.MAX_PLUS
			var cost := ItemDb.upgrade_cost(item)
			button.text = "Макс." if maxed else "+1 · %d" % cost
			UiTheme.jelly(button, "green")
			button.disabled = maxed or GameState.gold < cost
			button.pressed.connect(func() -> void:
				if ItemDb.upgrade(uid):
					_status.text = "Покращено: " + ItemDb.title_of(ItemDb.find(uid))
				_refresh())
		else:
			button.text = "Продати %d" % ItemDb.sell_price(item)
			UiTheme.jelly(button, "red")
			button.pressed.connect(func() -> void:
				var got := ItemDb.sell(uid)
				_status.text = "Продано за %d" % got
				_refresh())
		card.add_child(button)
		flow.add_child(card)

func _section(text: String) -> Control:
	var label := Label.new()
	UiTheme.hud_text(label, 20, UiTheme.GOLD)
	label.text = text
	return label
