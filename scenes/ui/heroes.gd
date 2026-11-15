extends Control

## ЗАЛА ГЕРОЇВ («Рунічна казка»).
##
## Герой — живою 3D-моделлю на рунічному постаменті посеред зали (фон
## kit/bg_heroes); його можна крутити пальцем. Ліворуч — сукняна панель:
## ім'я, роль, характеристики смугами (заповнюються анімацією), опис.
## Праворуч — медальйони його прийомів (натиск — вікно з описом). Унизу —
## картки героїв з артом у рамках (обраний — золота, вище за інших;
## закритий — притемнений, із замком і ціною), остання — "скоро" для
## майбутнього героя. Справа внизу — головна дія: обрати або купити.
##
## Переходи: екран в'їжджає частинами (панелі з боків, картки знизу),
## при зміні героя модель "виростає" з постаменту, а смуги
## характеристик набігають заново.

const ABILITY_ICON_SCRIPT := preload("res://scenes/ui/ability_icon.gd")
const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")
const HALL_BACKGROUND := "res://assets/ui/kit/backgrounds/bg_heroes.jpg"
const FRAME_DIR := "res://assets/ui/kit/frames/"
const MYSTERY_ART := "res://assets/ui/kit/heroes/hero_mystery.jpg"
## Де на фоні стоїть верх постаменту (частка висоти екрана).
const PEDESTAL_Y := 0.665
## Картка героя (3:4) і вікно під арт у рамці (частки розміру рамки).
const CARD_SIZE := Vector2(96, 128)
const CARD_WINDOW := Rect2(0.19, 0.2, 0.62, 0.665)
const CARD_LIFT := 12.0
## Найбільша висота списку зброї у вікні Арсеналу — далі він гортається.
const ARSENAL_MAX_HEIGHT := 320.0
const KIND_TAGS := {
	&"talent": "Пасивна риса",
	&"blade": "Здібність",
	&"weapon": "Зброя героя",
}
## Роль героя — коротко, під іменем.
const ROLES := {
	&"blade_warden": "Воїн • ближній бій",
	&"ember_priestess": "Чарівниця вогню • дальній бій",
	&"runewielder": "Маг рун • контроль",
	&"void_assassin": "Тінь • швидкі удари",
}
const NAME_COLOR := Color(1.0, 0.86, 0.45)
const SKILL_SIZE := 78.0

var _index := 0
var _preview: ModelPreview
var _placeholder_label: Label

var _gold_badge: CurrencyBadge
var _gem_badge: CurrencyBadge
var _cards: Array[Control] = []
var _left_panel: Control
var _right_column: VBoxContainer
var _card_row: HBoxContainer
var _name_label: Label
var _role_label: Label
var _description_label: Label
var _stat_bars: Array[ProgressBar] = []
var _stat_values: Array[Label] = []
var _action_button: Button
var _skills_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if has_node("Background"):
		($Background as CanvasItem).visible = false
	UiTheme.add_background(self, [HALL_BACKGROUND])

	# --- герой на постаменті ---
	_preview = MODEL_PREVIEW_SCRIPT.new()
	_preview.interactive = true
	_preview.anchor_left = 0.5
	_preview.anchor_right = 0.5
	_preview.anchor_top = PEDESTAL_Y
	_preview.anchor_bottom = PEDESTAL_Y
	_preview.offset_left = -200.0
	_preview.offset_right = 200.0
	_preview.offset_top = -340.0
	_preview.offset_bottom = 22.0
	add_child(_preview)
	_placeholder_label = Label.new()
	_placeholder_label.text = "Тимчасова модель — справжня буде пізніше"
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_placeholder_label.offset_top = -170.0
	_placeholder_label.add_theme_font_size_override("font_size", 13)
	add_child(_placeholder_label)

	# --- верх: назад, стрічка, гаманець ---
	var back := UiTheme.make_icon_button("back", 58.0, "Назад")
	back.icon = load(UiTheme.KIT_DIR + "btn_back.png") if ResourceLoader.exists(UiTheme.KIT_DIR + "btn_back.png") else back.icon
	for state: String in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	back.expand_icon = true
	back.position = Vector2(18, 14)
	back.pressed.connect(_on_back_pressed)
	add_child(back)

	var title := OrnateBanner.new("Зала героїв", 28)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -210.0
	title.offset_right = 210.0
	title.offset_top = 2.0
	title.offset_bottom = 86.0
	add_child(title)

	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 8)
	wallet.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	wallet.offset_left = -330.0
	wallet.offset_right = -18.0
	wallet.offset_top = 20.0
	wallet.alignment = BoxContainer.ALIGNMENT_END
	add_child(wallet)
	_gold_badge = CurrencyBadge.new(&"gold", 19)
	wallet.add_child(_gold_badge)
	_gem_badge = CurrencyBadge.new(&"gem", 19)
	wallet.add_child(_gem_badge)

	# --- ліворуч: ім'я, роль, характеристики, опис ---
	var panel := OrnatePanel.new()
	panel.position = Vector2(18, 92)
	panel.custom_minimum_size = Vector2(330, 0)
	panel.size = Vector2(330, 0)
	add_child(panel)
	_left_panel = panel
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	panel.add_child(info)
	_name_label = Label.new()
	_name_label.add_theme_font_override("font", UiTheme.font(900))
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.add_theme_color_override("font_color", NAME_COLOR)
	_name_label.add_theme_constant_override("outline_size", 7)
	info.add_child(_name_label)
	_role_label = Label.new()
	_role_label.add_theme_font_size_override("font_size", 15)
	_role_label.add_theme_color_override("font_color", UiTheme.RUNE)
	info.add_child(_role_label)
	var stats := GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 6)
	info.add_child(stats)
	for row: Array in [["stat_hp", "Здоров'я", Color(0.93, 0.33, 0.3)], ["stat_speed", "Швидкість", Color(0.36, 0.8, 0.95)],
			["stat_damage", "Сила зброї", Color(1.0, 0.72, 0.25)]]:
		var icon := UiTheme.make_bare_icon(ArtSlots.kit_icon(row[0]), 30.0)
		icon.tooltip_text = row[1]
		stats.add_child(icon)
		var bar := UiTheme.make_bar(row[2], Vector2(170, 18))
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 1.0
		bar.step = 0.001
		stats.add_child(bar)
		_stat_bars.append(bar)
		var value := Label.new()
		value.custom_minimum_size = Vector2(54, 0)
		value.add_theme_font_size_override("font_size", 16)
		stats.add_child(value)
		_stat_values.append(value)
	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(250, 0)
	_description_label.add_theme_font_size_override("font_size", 14)
	_description_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	info.add_child(_description_label)

	# --- праворуч: прийоми медальйонами ---
	_right_column = VBoxContainer.new()
	_right_column.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_right_column.offset_left = -150.0
	_right_column.offset_right = -18.0
	_right_column.offset_top = 92.0
	_right_column.add_theme_constant_override("separation", 4)
	add_child(_right_column)
	var skills_title := Label.new()
	skills_title.text = "Прийоми"
	skills_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skills_title.add_theme_font_size_override("font_size", 17)
	skills_title.add_theme_color_override("font_color", UiTheme.GOLD)
	_right_column.add_child(skills_title)
	_skills_box = VBoxContainer.new()
	_skills_box.add_theme_constant_override("separation", 2)
	_right_column.add_child(_skills_box)

	# --- унизу: картки героїв і головна дія ---
	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 12)
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_card_row.offset_top = -CARD_SIZE.y - 34.0
	_card_row.offset_bottom = -10.0
	_card_row.offset_left = -330.0
	_card_row.offset_right = 330.0
	add_child(_card_row)
	for i in HeroPool.ALL_HEROES.size():
		var card := _make_card(HeroPool.ALL_HEROES[i])
		card.gui_input.connect(_on_card_input.bind(i))
		_card_row.add_child(card)
		_cards.append(card)
	_card_row.add_child(_make_mystery_card())

	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(230, 58)
	_action_button.add_theme_font_size_override("font_size", 22)
	_action_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_action_button.offset_left = -248.0
	_action_button.offset_top = -78.0
	_action_button.offset_right = -18.0
	_action_button.offset_bottom = -20.0
	_action_button.pressed.connect(_on_action_pressed)
	add_child(_action_button)

	_index = _find_index(GameState.selected_hero_id)
	_rebuild()
	_intro()

## Екран в'їжджає частинами.
func _intro() -> void:
	var pieces := [[_left_panel, Vector2(-380, 0)], [_right_column, Vector2(200, 0)], [_card_row, Vector2(0, 180)],
		[_action_button, Vector2(280, 0)]]
	for i in pieces.size():
		var node: Control = pieces[i][0]
		var shift: Vector2 = pieces[i][1]
		var home := node.position
		node.position = home + shift
		node.modulate.a = 0.0
		var tween := node.create_tween().set_parallel()
		tween.tween_property(node, "position", home, 0.45).set_delay(0.05 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "modulate:a", 1.0, 0.3).set_delay(0.05 * i)

func _find_index(hero_id: StringName) -> int:
	for i in HeroPool.ALL_HEROES.size():
		if HeroPool.ALL_HEROES[i].id == hero_id:
			return i
	return 0

func _current() -> HeroDef:
	return HeroPool.ALL_HEROES[_index]

func _on_card_input(event: InputEvent, index: int) -> void:
	var press := event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if press or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		_on_slot_pressed(index)

func _on_slot_pressed(index: int) -> void:
	if index == _index:
		return
	_index = index
	_rebuild()

# --- картки ---

func _make_card(def: HeroDef) -> Control:
	var card := Control.new()
	card.custom_minimum_size = CARD_SIZE + Vector2(0, CARD_LIFT + 18)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = CARD_SIZE * 0.5
	var holder := Control.new()
	holder.name = "Holder"
	holder.size = CARD_SIZE
	holder.position = Vector2(0, CARD_LIFT)
	holder.pivot_offset = CARD_SIZE * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(holder)
	var art := TextureRect.new()
	art.name = "Art"
	var texture := ArtSlots.hero_card_art(def.id)
	art.texture = texture if texture != null else ArtSlots.hero_portrait(def.id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = CARD_SIZE * CARD_WINDOW.position
	art.size = CARD_SIZE * CARD_WINDOW.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(art)
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.size = CARD_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)
	var lock := TextureRect.new()
	lock.name = "Lock"
	lock.texture = load(UiTheme.KIT_DIR + "btn_lock.png")
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.size = Vector2(40, 40)
	lock.position = Vector2(CARD_SIZE.x * 0.5 - 20, CARD_SIZE.y * 0.5 - 24)
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lock)
	var caption := Label.new()
	caption.name = "Caption"
	caption.text = def.title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.position = Vector2(-20, CARD_LIFT + CARD_SIZE.y - 4)
	caption.size = Vector2(CARD_SIZE.x + 40, 18)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(caption)
	return card

## Картка майбутнього героя: силует лучника за рунічним знаком питання.
func _make_mystery_card() -> Control:
	var fake := HeroDef.new()
	fake.id = &"mystery"
	fake.title = "Скоро"
	var card := _make_card(fake)
	var art := card.get_node("Holder/Art") as TextureRect
	if ResourceLoader.exists(MYSTERY_ART):
		art.texture = load(MYSTERY_ART)
	(card.get_node("Holder/Frame") as TextureRect).texture = load(FRAME_DIR + "card_common.png")
	(card.get_node("Holder/Lock") as CanvasItem).visible = false
	card.modulate = Color(0.85, 0.85, 0.9)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.tooltip_text = "Новий герой — скоро"
	return card

func _style_cards() -> void:
	for i in _cards.size():
		var def := HeroPool.ALL_HEROES[i]
		var card := _cards[i]
		var selected := i == _index
		var unlocked := GameState.is_hero_unlocked(def.id)
		var rarity := "legendary" if selected else ("epic" if GameState.selected_hero_id == def.id else ("rare" if unlocked else "common"))
		(card.get_node("Holder/Frame") as TextureRect).texture = load(FRAME_DIR + "card_%s.png" % rarity)
		(card.get_node("Holder/Art") as CanvasItem).modulate = Color.WHITE if unlocked else Color(0.35, 0.33, 0.4)
		(card.get_node("Holder/Lock") as CanvasItem).visible = not unlocked
		var caption := card.get_node("Caption") as Label
		caption.add_theme_color_override("font_color", NAME_COLOR if selected else UiTheme.TEXT_DIM)
		var holder := card.get_node("Holder") as Control
		var tween := holder.create_tween().set_parallel()
		tween.tween_property(holder, "position:y", 0.0 if selected else CARD_LIFT, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(holder, "scale", Vector2.ONE * (1.08 if selected else 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- герой ---

func _rebuild() -> void:
	var def := _current()
	_gold_badge.set_amount(GameState.gold)
	_gem_badge.set_amount(GameState.gems)
	_style_cards()

	var weapon := WeaponPool.get_def(GameState.get_equipped_weapon_id(def.id))
	_placeholder_label.visible = _preview.show_hero(def, weapon)

	_name_label.text = def.title
	_role_label.text = ROLES.get(def.id, "")
	_description_label.text = def.description
	_pop(_name_label)
	_fill_stats(def, weapon)
	_fill_skills(def)

	PriceTag.clear(_action_button)
	_action_button.disabled = false
	if GameState.selected_hero_id == def.id:
		_action_button.text = "Обрано"
		_action_button.disabled = true
		UiTheme.jelly(_action_button, "green")
	elif GameState.is_hero_unlocked(def.id):
		_action_button.text = "Обрати"
		UiTheme.jelly(_action_button, "green")
	elif def.gem_cost > 0:
		UiTheme.jelly(_action_button, "gold")
		_action_button.disabled = GameState.gems < def.gem_cost
		PriceTag.apply(_action_button, &"gem", def.gem_cost, "Купити")
	else:
		UiTheme.jelly(_action_button, "gold")
		_action_button.disabled = GameState.gold < def.unlock_cost
		PriceTag.apply(_action_button, &"gold", def.unlock_cost, "Купити")

## Ім'я "підстрибує", коли змінюється герой.
func _pop(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * 0.85
	node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Смуги характеристик відносно найсильнішого героя — набігають заново.
func _fill_stats(def: HeroDef, weapon: WeaponDef) -> void:
	var best_hp := 1.0
	var best_speed := 1.0
	for other: HeroDef in HeroPool.ALL_HEROES:
		best_hp = maxf(best_hp, Balance.HERO_MAX_HP + other.bonus_max_hp)
		best_speed = maxf(best_speed, 1.0 + other.move_speed_percent)
	var hp := Balance.HERO_MAX_HP + def.bonus_max_hp
	var speed := 1.0 + def.move_speed_percent
	var power := weapon.damage_mult_3d if weapon != null else 1.0
	var fractions := [hp / best_hp * 0.92, speed / best_speed * 0.92, clampf(power / 1.6, 0.1, 1.0)]
	var texts := ["%d" % int(hp), "%+d%%" % int(round(def.move_speed_percent * 100.0)), "%d%%" % int(round(power * 100.0))]
	for i in _stat_bars.size():
		var bar := _stat_bars[i]
		bar.value = 0.0
		bar.create_tween().tween_property(bar, "value", fractions[i], 0.6).set_delay(0.08 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_stat_values[i].text = texts[i]

func _fill_skills(def: HeroDef) -> void:
	for child in _skills_box.get_children():
		child.queue_free()
	var cards := _cards_for(def)
	for i in cards.size():
		var tile := _build_ability_slot(cards[i])
		tile.modulate.a = 0.0
		tile.create_tween().tween_property(tile, "modulate:a", 1.0, 0.25).set_delay(0.06 * i)
		_skills_box.add_child(tile)

## Медальйон прийому з підписом; натиск — вікно з описом.
func _build_ability_slot(card: Dictionary) -> Button:
	var tile := Button.new()
	tile.flat = true
	tile.focus_mode = Control.FOCUS_NONE
	tile.tooltip_text = card.title
	tile.custom_minimum_size = Vector2(132, SKILL_SIZE + 18)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		tile.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	tile.pressed.connect(_on_ability_pressed.bind(card))
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(content)
	var own_icon := ArtSlots.skill_icon(card.get("id", &""))
	if own_icon != null:
		var image := UiTheme.make_bare_icon(own_icon, SKILL_SIZE)
		image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(image)
	else:
		var drawn: Button = ABILITY_ICON_SCRIPT.new()
		drawn.setup(card.kind, card.color, card.title)
		drawn.custom_minimum_size = Vector2(SKILL_SIZE, SKILL_SIZE)
		drawn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(drawn)
	var caption := Label.new()
	caption.text = card.title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 13)
	content.add_child(caption)
	return tile

## Картки здібностей беремо з того, що герой СПРАВДІ вміє в бою
## (Skills3D), а не з окремого опису — тоді вітрина не бреше. Останньою
## йде картка про арсенал зброї.
func _cards_for(def: HeroDef) -> Array:
	var cards := []
	var equipped := WeaponPool.get_def(GameState.get_equipped_weapon_id(def.id))
	for entry: Dictionary in Skills3D.describe(def, equipped):
		cards.append({
			"kind": &"talent" if entry.kind == &"passive" else &"blade",
			"color": entry.color,
			"title": entry.title,
			"text": entry.text,
			"id": entry.id,
		})
	var weapons := WeaponPool.get_for_hero(def.id)
	var lines := []
	for weapon: WeaponDef in weapons:
		lines.append("%s — %s" % [weapon.title, weapon.description])
	cards.append({
		"kind": &"weapon", "color": Color(1.0, 0.85, 0.4),
		"title": "Арсенал",
		"text": "\n".join(lines),
		"id": &"arsenal",
		"hero_id": def.id,
	})
	return cards

## Опис прийому — у вікні з рамкою: іконка, назва, вид прийому, текст.
## Арсенал — списком зброї з картинками.
func _on_ability_pressed(card: Dictionary) -> void:
	var is_arsenal: bool = card.has("hero_id")
	var dialog := OrnateDialog.new(card.title, ArtSlots.skill_icon(card.get("id", &"")), card.color,
		640.0 if is_arsenal else 560.0, KIND_TAGS.get(card.kind, ""))
	if is_arsenal:
		dialog.body.add_child(_arsenal_list(card.hero_id))
	else:
		dialog.add_text(card.text)
	dialog.add_button("Зрозуміло")
	add_child(dialog)

func _arsenal_list(hero_id: StringName) -> Control:
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	var equipped := GameState.get_equipped_weapon_id(hero_id)
	for weapon: WeaponDef in WeaponPool.get_for_hero(hero_id):
		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override("panel", UiTheme.inset_box())
		list.add_child(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row_panel.add_child(row)
		var texture := ArtSlots.weapon_icon(weapon.id, weapon.icon)
		if texture == null:
			texture = ArtSlots.placeholder_icon(weapon.color, 64)
		row.add_child(UiTheme.make_bare_icon(texture, 50.0))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.add_theme_constant_override("separation", 1)
		row.add_child(text)
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		text.add_child(name_row)
		var name_label := Label.new()
		name_label.text = weapon.title
		name_label.add_theme_font_override("font", UiTheme.font(900))
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", NAME_COLOR)
		name_row.add_child(name_label)
		if weapon.id == equipped:
			name_row.add_child(OrnateDialog.make_tag("У руках", Color(0.45, 0.9, 0.5)))
		elif not GameState.is_weapon_owned(weapon.id):
			var price := CurrencyBadge.new(&"gold", 14, false)
			price.set_amount(weapon.cost_gold)
			name_row.add_child(price)
		var description := Label.new()
		description.text = weapon.description
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 14)
		description.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		text.add_child(description)
	UiTheme.tag_scroll_pass(list)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, ARSENAL_MAX_HEIGHT)
	scroll.add_child(list)
	list.resized.connect(func() -> void:
		scroll.custom_minimum_size.y = minf(list.size.y, ARSENAL_MAX_HEIGHT))
	return scroll

func _on_action_pressed() -> void:
	var def := _current()
	if GameState.is_hero_unlocked(def.id):
		GameState.select_hero(def.id)
	elif def.gem_cost > 0:
		if GameState.unlock_hero_with_gems(def.id):
			AudioManager.play(&"purchase", 0.0)
			GameState.select_hero(def.id)
	elif GameState.unlock_hero(def.id):
		AudioManager.play(&"purchase", 0.0)
		GameState.select_hero(def.id)
	_rebuild()
	# Святковий спалах на обраному герої.
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.92, 0.6, 0.35)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.45)
	tween.tween_callback(flash.queue_free)

func _on_back_pressed() -> void:
	GameState.return_from_ui()
