extends Control

## СПОРЯДЖЕННЯ. Посередині — твій персонаж на весь зріст (крутиться
## пальцем); що вдягаєш — одразу видно на ньому. Обабіч — слоти: шолом,
## груди, штани, взуття / зброя, талісман, два кільця (прикраси — з 10
## рівня). Ліворуч — характеристики героя з урахуванням надітого,
## праворуч — торба (або скриня вдома, якщо відкрито біля неї).
##
## Натиск на річ — картка речі: усі числа, а поруч зі стрілками — чим
## вона краща (▲ зелене) чи гірша (▼ червоне) за ту, що зараз надіта.
## Кнопки: Вдягти / Зняти / У скриню / У торбу / Продати.
##
## Відкриття біля скрині: GameState.set_meta(&"inventory_stash", true).

const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")
const PEDESTAL_Y := 0.665
const LEFT_SLOTS := ["helmet", "chest", "legs", "boots"]
const RIGHT_SLOTS := ["weapon", "amulet", "ring1", "ring2"]
const SLOT_SIZE := 74.0
const CELL_SIZE := 62.0
const BAG_COLUMNS := 3
const STATS_WIDTH := 236.0
## Ширина місця під персонажа між колонками слотів.
const CHARACTER_GAP := 250.0
## Скільки золота дають за річ кожної рідкості.
const SELL_PRICE := {"common": 15, "uncommon": 40, "rare": 110, "epic": 300, "legendary": 800}
const BASE_HP := 100

var _stash_mode := false
var _show_stash := false
var _preview: ModelPreview
var _slot_buttons := {}
var _stats_box: VBoxContainer
var _bag_grid: GridContainer
var _bag_title: Label
var _gold_badge: CurrencyBadge

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stash_mode = bool(GameState.get_meta(&"inventory_stash", false))
	GameState.set_meta(&"inventory_stash", false)
	_show_stash = _stash_mode
	UiTheme.add_background(self, [UiTheme.BG_HEROES], 0.35)

	_preview = MODEL_PREVIEW_SCRIPT.new()
	_preview.interactive = true
	_preview.anchor_left = 0.5
	_preview.anchor_right = 0.5
	_preview.anchor_top = PEDESTAL_Y
	_preview.anchor_bottom = PEDESTAL_Y
	_preview.offset_left = -170.0
	_preview.offset_right = 170.0
	_preview.offset_top = -430.0
	_preview.offset_bottom = 66.0
	add_child(_preview)

	var title := OrnateBanner.new("Скриня і спорядження" if _stash_mode else "Спорядження", 26)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -230.0
	title.offset_right = 230.0
	title.offset_top = 2.0
	title.offset_bottom = 86.0
	add_child(title)
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

	# Розкладка рядом, що підлаштовується під ширину екрана:
	# [характеристики] [слоти] [персонаж] [слоти] [торба]. Порожні
	# розпірки по краях стискаються першими — нічого не наїжджає.
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14.0
	row.offset_right = -14.0
	row.offset_top = 86.0
	row.offset_bottom = -14.0
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	var stats_panel := OrnatePanel.new()
	stats_panel.custom_minimum_size = Vector2(STATS_WIDTH, 0)
	stats_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(stats_panel)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 3)
	stats_panel.add_child(_stats_box)
	row.add_child(_spacer())

	for side in 2:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		column.custom_minimum_size = Vector2(SLOT_SIZE + 16, 0)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for slot: String in (LEFT_SLOTS if side == 0 else RIGHT_SLOTS):
			var button := _make_cell(SLOT_SIZE)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.pressed.connect(_on_slot_pressed.bind(slot))
			column.add_child(button)
			var caption := Label.new()
			caption.text = ItemDb.SLOT_TITLES[slot]
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.add_theme_font_size_override("font_size", 12)
			column.add_child(caption)
			_slot_buttons[slot] = button
		row.add_child(column)
		if side == 0:
			# Місце під персонажа (він сам — посеред екрана, на постаменті).
			var middle := Control.new()
			middle.custom_minimum_size = Vector2(CHARACTER_GAP, 0)
			middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(middle)
	row.add_child(_spacer())

	var bag_panel := OrnatePanel.new()
	bag_panel.custom_minimum_size = Vector2((CELL_SIZE + 6) * BAG_COLUMNS + 70.0, 0)
	row.add_child(bag_panel)
	var bag_column := VBoxContainer.new()
	bag_column.add_theme_constant_override("separation", 6)
	bag_panel.add_child(bag_column)
	var header := HBoxContainer.new()
	bag_column.add_child(header)
	_bag_title = Label.new()
	_bag_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_title.add_theme_font_size_override("font_size", 18)
	_bag_title.add_theme_color_override("font_color", UiTheme.GOLD)
	header.add_child(_bag_title)
	if _stash_mode:
		var toggle := Button.new()
		toggle.add_theme_font_size_override("font_size", 14)
		toggle.custom_minimum_size = Vector2(110, 36)
		UiTheme.jelly(toggle, "blue")
		toggle.pressed.connect(func() -> void:
			_show_stash = not _show_stash
			_refresh())
		toggle.set_meta(&"toggle", true)
		header.add_child(toggle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bag_column.add_child(scroll)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = BAG_COLUMNS
	_bag_grid.add_theme_constant_override("h_separation", 6)
	_bag_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_bag_grid)

	GameState.equipment_changed.connect(_refresh)
	_refresh()

func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _exit_tree() -> void:
	if GameState.equipment_changed.is_connected(_refresh):
		GameState.equipment_changed.disconnect(_refresh)

## Клітинка під річ: сливова вставка в канті кольору рідкості.
func _make_cell(side: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(side, side)
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	return button

func _style_cell(button: Button, item: Dictionary, placeholder: Texture2D = null, locked: bool = false) -> void:
	var tint := Color(0.6, 0.6, 0.62) if item.is_empty() else ItemDb.color_of(item).lerp(Color.WHITE, 0.25)
	var box := UiTheme.slot_box(tint)
	var press := UiTheme.slot_box(tint * Color(0.8, 0.8, 0.8))
	for state: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("pressed", press)
	button.icon = load(UiTheme.KIT_DIR + "btn_lock.png") if locked else (ItemDb.icon_of(item) if not item.is_empty() else placeholder)
	button.modulate = Color(1, 1, 1, 1) if not item.is_empty() else Color(1, 1, 1, 0.55)
	button.tooltip_text = "" if item.is_empty() else ItemDb.title_of(item)

func _refresh() -> void:
	_gold_badge.set_amount(GameState.gold)
	var equipped := ItemDb.equipped_items()
	for slot: String in _slot_buttons:
		var locked: bool = slot in ["amulet", "ring1", "ring2"] and GameState.hero_level < ItemDb.JEWELRY_LEVEL
		_style_cell(_slot_buttons[slot], equipped.get(slot, {}), ItemDb.slot_icon(slot), locked)
		if locked:
			(_slot_buttons[slot] as Button).tooltip_text = "Відкриється з %d рівня" % ItemDb.JEWELRY_LEVEL
	var weapon: WeaponDef = ItemDb.weapon_def(equipped.get("weapon", {})) if equipped.has("weapon") else null
	_preview.show_character(GameState.character.get("look", {}), ItemDb.gear_look(equipped), "", weapon)
	_fill_stats(equipped)
	_fill_bag()

func _fill_stats(equipped: Dictionary) -> void:
	for child in _stats_box.get_children():
		child.queue_free()
	var name_label := Label.new()
	name_label.text = String(GameState.character.get("name", "Герой"))
	name_label.add_theme_font_override("font", UiTheme.font(900))
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	_stats_box.add_child(name_label)
	var level := Label.new()
	level.text = "Рівень %d" % GameState.hero_level
	level.add_theme_font_size_override("font_size", 15)
	level.add_theme_color_override("font_color", UiTheme.RUNE)
	_stats_box.add_child(level)
	# Клас вирішує зброя в руках — показуємо це прямо, щоб не дивувались,
	# чому в латах танка з посохом немає удару щитом.
	var weapon_class := String(ItemDb.base_of(equipped.get("weapon", {})).get("class", ""))
	var class_label := Label.new()
	class_label.text = ("Клас: %s (від зброї в руках)" % ItemDb.CLASSES.get(weapon_class, weapon_class)) if weapon_class != "" else "Без зброї — б'єш кулаками"
	class_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	class_label.add_theme_font_size_override("font_size", 14)
	class_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.6))
	_stats_box.add_child(class_label)
	var total := ItemDb.total_stats(equipped)
	total["hp"] = BASE_HP + int(total.get("hp", 0))
	for stat: String in ItemDb.STATS:
		if not total.has(stat):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(UiTheme.make_bare_icon(ArtSlots.kit_icon(ItemDb.STATS[stat].icon), 24.0))
		var label := Label.new()
		label.text = ItemDb.STATS[stat].title
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)
		var value := Label.new()
		value.text = "%d%s" % [int(total[stat]), ItemDb.STATS[stat].suffix]
		value.add_theme_font_size_override("font_size", 15)
		value.add_theme_color_override("font_color", UiTheme.GOLD)
		row.add_child(value)
		_stats_box.add_child(row)

func _fill_bag() -> void:
	for child in _bag_grid.get_children():
		child.queue_free()
	var list: Array = GameState.stash if _show_stash else GameState.inventory
	_bag_title.text = ("Скриня (%d)" if _show_stash else "Торба (%d)") % list.size()
	for node in _bag_title.get_parent().get_children():
		if node is Button and node.has_meta(&"toggle"):
			(node as Button).text = "До торби" if _show_stash else "До скрині"
	# Сортування: спершу рідкісніші, далі за слотом.
	var sorted := list.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := ItemDb.RARITIES.find(a.rarity)
		var rb := ItemDb.RARITIES.find(b.rarity)
		return ra > rb if ra != rb else ItemDb.slot_of(a) < ItemDb.slot_of(b))
	for item: Dictionary in sorted:
		var cell := _make_cell(CELL_SIZE)
		_style_cell(cell, item)
		cell.pressed.connect(_show_item.bind(item, _show_stash))
		_bag_grid.add_child(cell)
	if sorted.is_empty() and not _show_stash:
		_bag_title.text = "Торба порожня"
		_bag_title.tooltip_text = "Речі дають жителі за завдання й випадають у данжах"
	# Порожні клітинки — щоб торба не виглядала голою.
	for i in maxi(0, BAG_COLUMNS * 5 - sorted.size()):
		var empty := _make_cell(CELL_SIZE)
		_style_cell(empty, {})
		empty.disabled = true
		_bag_grid.add_child(empty)

func _on_slot_pressed(slot: String) -> void:
	var item := ItemDb.find(String(GameState.equipment.get(slot, "")))
	if item.is_empty():
		_flash_hint("Слот порожній — обери річ у торбі")
		return
	_show_item(item, false, true)

func _flash_hint(text: String) -> void:
	var hint := Label.new()
	hint.text = text
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -60.0
	hint.offset_left = -300.0
	hint.offset_right = 300.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	var tween := hint.create_tween()
	tween.tween_property(hint, "modulate:a", 0.0, 0.6).set_delay(1.2)
	tween.tween_callback(hint.queue_free)

## Картка речі з порівнянням і діями.
func _show_item(item: Dictionary, in_stash: bool, is_equipped: bool = false) -> void:
	var base := ItemDb.base_of(item)
	var dialog := OrnateDialog.new(ItemDb.title_of(item), ItemDb.icon_of(item), ItemDb.color_of(item), 560.0,
		"%s • %s • %s" % [ItemDb.RARITY_TITLES.get(item.rarity, ""), ItemDb.SLOT_TITLES.get(base.get("slot", ""), ""),
			ItemDb.CLASSES.get(base.get("class", "any"), "")])
	var compare := {} if is_equipped else ItemDb.compare(item)
	var has_current := not is_equipped and GameState.equipment.has(ItemDb.slot_of(item))
	var stats: Dictionary = item.get("stats", {})
	var keys := stats.keys()
	for stat: String in compare:
		if not keys.has(stat):
			keys.append(stat)
	for stat: String in keys:
		if not ItemDb.STATS.has(stat):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UiTheme.make_bare_icon(ArtSlots.kit_icon(ItemDb.STATS[stat].icon), 26.0))
		var label := Label.new()
		label.text = ItemDb.STATS[stat].title
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 17)
		row.add_child(label)
		var value := Label.new()
		value.text = "%d%s" % [int(stats.get(stat, 0)), ItemDb.STATS[stat].suffix]
		value.add_theme_font_size_override("font_size", 17)
		value.add_theme_color_override("font_color", UiTheme.GOLD)
		row.add_child(value)
		if has_current:
			var delta := int(compare.get(stat, 0))
			var arrow := Label.new()
			arrow.custom_minimum_size = Vector2(70, 0)
			arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			arrow.add_theme_font_size_override("font_size", 17)
			if delta > 0:
				arrow.text = "▲ +%d" % delta
				arrow.add_theme_color_override("font_color", Color(0.45, 1.0, 0.45))
			elif delta < 0:
				arrow.text = "▼ %d" % delta
				arrow.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
			else:
				arrow.text = "="
				arrow.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
			row.add_child(arrow)
		dialog.body.add_child(row)
	# Унікальне вміння зброї — окремим рядком кольору рідкості.
	var unique_text := String(ItemDb.base_of(item).get("unique_text", ""))
	if unique_text != "":
		dialog.add_text("★ " + unique_text, 16, ItemDb.color_of(item))
	var weapon_class := String(ItemDb.base_of(item).get("class", ""))
	if ItemDb.slot_of(item) == "weapon" and weapon_class != "":
		dialog.add_text("Клас у руках: %s" % ItemDb.CLASSES.get(weapon_class, weapon_class), 14, UiTheme.TEXT_DIM)
	if has_current:
		dialog.add_text("Стрілки — порівняння з тим, що зараз надіто.", 14, UiTheme.TEXT_DIM)
	elif not is_equipped:
		dialog.add_text("Цей слот зараз порожній.", 14, UiTheme.TEXT_DIM)

	if is_equipped:
		dialog.add_button("Зняти", true, func() -> void:
			ItemDb.unequip(ItemDb.slot_of(item))
			dialog.close(), 200.0)
	elif in_stash:
		dialog.add_button("У торбу", true, func() -> void:
			GameState.stash.erase(item)
			GameState.inventory.append(item)
			_saved()
			dialog.close(), 200.0)
	else:
		if ItemDb.can_equip(item):
			dialog.add_button("Вдягти", true, func() -> void:
				ItemDb.equip(item.uid)
				_preview.play_character_anim("Yes")
				dialog.close(), 200.0)
		if _stash_mode:
			dialog.add_button("У скриню", false, func() -> void:
				GameState.inventory.erase(item)
				GameState.stash.append(item)
				_saved()
				dialog.close(), 170.0)
		var price: int = SELL_PRICE.get(item.rarity, 10)
		dialog.add_button("Продати +%d" % price, false, func() -> void:
			GameState.inventory.erase(item)
			GameState.add_gold(price)
			_saved()
			dialog.close(), 170.0)
	add_child(dialog)

func _saved() -> void:
	SaveManager.save_game()
	_refresh()
