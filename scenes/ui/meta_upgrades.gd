extends Control

## Екран мета-прогресії ("база"): тут гравець між ранами витрачає
## золото на постійні бонуси для ПОТОЧНОГО обраного героя
## (GameState.selected_hero_id). Золото спільне на всіх, але рівні
## апгрейдів/талантів — окремі для кожного героя (GameState.buy_meta_upgrade
## бере hero_id). 7 спільних статів відповідають розділу 6 ТЗ + один
## унікальний талант героя (HeroDef.unique_talent_id, з TALENTS нижче).

const GENERIC_UPGRADES := [
	{"id": &"meta_max_hp", "title": "Здоров'я", "per_level": "+10 HP"},
	{"id": &"meta_damage", "title": "Шкода", "per_level": "+5%"},
	{"id": &"meta_move_speed", "title": "Швидкість", "per_level": "+3%"},
	{"id": &"meta_pickup_radius", "title": "Радіус підбору", "per_level": "+8"},
	{"id": &"meta_gold_gain", "title": "Приріст золота", "per_level": "+7%"},
	{"id": &"meta_luck", "title": "Удача", "per_level": "+4% шанс кращих апгрейдів"},
	{"id": &"meta_start_level", "title": "Стартовий рівень", "per_level": "+1 рівень старту"},
]

## Унікальні таланти — по одному на героя, id збігається з
## HeroDef.unique_talent_id. Ефект застосовує Hero.apply_meta_upgrades().
const TALENTS := {
	&"talent_bolt_pierce": {"title": "Пробивна Руна", "per_level": "+0.4 м до радіуса Рунної Нови"},
	&"talent_extra_blades": {"title": "Вихор Клинків", "per_level": "+18% шкоди Вихору, -0.4 с перезарядки"},
	&"talent_aura_power": {"title": "Багаття Люті", "per_level": "+15% шкоди й +0.2 м радіуса Вогняного Кола"},
	&"talent_shadow_clones": {"title": "Володар Тіней", "per_level": "+0.5 с Димової Завіси"},
}

const BOTTOM_MARGIN := 24.0
## Тло — храм з колонами й рунним вівтарем (арт гравця).
const TEMPLE_BACKGROUND := "res://assets/ui/backgrounds/temple.jpg"

@onready var content: VBoxContainer = $VBoxContainer
@onready var hero_label: Label = $VBoxContainer/HeroLabel
@onready var gold_label: Label = $VBoxContainer/GoldLabel
@onready var rows_container: VBoxContainer = $VBoxContainer/ScrollContainer/RowsContainer

var _hero_id: StringName
var _gold_badge: CurrencyBadge

func _ready() -> void:
	_hero_id = GameState.selected_hero_id
	_build_frame()
	_rebuild()
	# Банер показуємо лише тут — розділ 8 ТЗ: тільки на екрані
	# мета-прогресії, ніколи під час рану.
	AdsManager.banner_height_changed.connect(_on_banner_height_changed)
	AdsManager.show_banner()

func _exit_tree() -> void:
	AdsManager.banner_height_changed.disconnect(_on_banner_height_changed)
	AdsManager.hide_banner()

## Банер нативний і малюється поверх гри — відсуваємо вміст угору на
## його висоту, щоб він не перекривав кнопку "Назад".
func _on_banner_height_changed(height_px: int) -> void:
	content.offset_bottom = -(BOTTOM_MARGIN + height_px)

## Оформлення як у Ринку й Залі героїв: тло-храм, банер заголовка з
## гербом, золото праворуч, список карток посередині, "Назад" по центру.
## Вузли зі сцени лишаються (на них посилаються @onready), лише ховаємо
## текстові заголовок, підпис героя й золото.
func _build_frame() -> void:
	if ResourceLoader.exists(TEMPLE_BACKGROUND):
		var temple := TextureRect.new()
		temple.texture = load(TEMPLE_BACKGROUND)
		temple.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		temple.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		temple.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		temple.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(temple)
		move_child(temple, $Background.get_index() + 1)

	content.add_theme_constant_override("separation", 10)
	($VBoxContainer/TitleLabel as Label).visible = false
	hero_label.visible = false
	gold_label.visible = false

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	content.add_child(top_row)
	content.move_child(top_row, 0)
	var title := OrnateBanner.new("Храм талантів", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title)
	# Золото — навпроти полотна банера, а не його герба: відступ згори.
	var wallet := MarginContainer.new()
	wallet.add_theme_constant_override("margin_top", int(OrnateBanner.CREST_RISE))
	top_row.add_child(wallet)
	_gold_badge = CurrencyBadge.new(&"gold", 20)
	wallet.add_child(_gold_badge)

	# Список — посередині екрана: на широкому телефоні він інакше тулився
	# до лівого краю, а праворуч зяяла порожнеча.
	rows_container.custom_minimum_size = Vector2(680, 0)
	rows_container.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	rows_container.add_theme_constant_override("separation", 10)

	var back := $VBoxContainer/BackButton as Button
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(170, 52)
	back.add_theme_font_size_override("font_size", 18)

func _rebuild() -> void:
	_gold_badge.set_amount(GameState.gold)
	for child in rows_container.get_children():
		child.queue_free()
	# Чиї таланти — банером розділу, як заголовки на Ринку.
	rows_container.add_child(SectionBanner.new("Таланти героя: %s" % HeroPool.get_def(_hero_id).title, 20))
	for upgrade in GENERIC_UPGRADES:
		rows_container.add_child(_build_row(upgrade.id, upgrade.title, upgrade.per_level))

	var talent_id := HeroPool.get_def(_hero_id).unique_talent_id
	if talent_id != &"" and TALENTS.has(talent_id):
		var talent: Dictionary = TALENTS[talent_id]
		rows_container.add_child(_build_row(talent_id, talent.title, talent.per_level))

## Рядок таланту — картка з відсіком під іконку, як товар на Ринку: назва,
## що дає кожен рівень, смужка рівня й зелена кнопка з ціною. Іконка —
## res://assets/ui/icons/talents/<id таланту>.png; немає — зірка-заглушка.
func _build_row(id: StringName, title: String, per_level: String) -> Control:
	var level := GameState.get_meta_level(_hero_id, id)
	var max_level := GameState.get_meta_max_level(id)

	var own_icon := ArtSlots.talent_icon(id)
	var card: PanelContainer
	if own_icon != null:
		card = UiTheme.make_item_card(own_icon)
	else:
		card = UiTheme.make_item_card(UiTheme.control_icon("star"), UiTheme.HEADING)
	var row := card.get_child(0) as HBoxContainer

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_override("font", UiTheme.font(800))
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	info.add_child(name_label)
	var effect_label := Label.new()
	effect_label.text = "%s за рівень" % per_level
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.add_theme_font_size_override("font_size", 14)
	effect_label.add_theme_color_override("font_color", Color(0.82, 0.8, 0.92))
	info.add_child(effect_label)
	# Рівень — смужкою, а не лише числом: видно, скільки ще лишилось.
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 10)
	info.add_child(level_row)
	var bar := UiTheme.make_bar(UiTheme.GOLD, Vector2(150, 8))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = max_level
	bar.value = level
	level_row.add_child(bar)
	var level_label := Label.new()
	level_label.text = "Рівень %d/%d" % [level, max_level]
	level_label.add_theme_font_size_override("font_size", 13)
	level_label.add_theme_color_override("font_color", UiTheme.GOLD if level >= max_level else Color(0.82, 0.8, 0.92))
	level_row.add_child(level_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(170, 48)
	buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if level >= max_level:
		buy_button.text = "Максимум"
		buy_button.disabled = true
	else:
		var cost := GameState.get_meta_upgrade_cost(_hero_id, id)
		buy_button.disabled = GameState.gold < cost
		if not buy_button.disabled:
			UiTheme.make_primary(buy_button)
		PriceTag.apply(buy_button, &"gold", cost, "Купити")
		buy_button.pressed.connect(_on_buy_pressed.bind(id))
	row.add_child(buy_button)

	UiTheme.tag_scroll_pass(card)
	return card

func _on_buy_pressed(id: StringName) -> void:
	GameState.buy_meta_upgrade(_hero_id, id)
	_rebuild()

func _on_back_pressed() -> void:
	# Назад — туди, звідки прийшли: у місто до дверей будівлі чи в меню.
	GameState.return_from_ui()
