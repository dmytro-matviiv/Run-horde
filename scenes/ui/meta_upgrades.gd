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

@onready var content: VBoxContainer = $VBoxContainer
@onready var hero_label: Label = $VBoxContainer/HeroLabel
@onready var gold_label: Label = $VBoxContainer/GoldLabel
@onready var rows_container: VBoxContainer = $VBoxContainer/ScrollContainer/RowsContainer

var _hero_id: StringName

func _ready() -> void:
	_hero_id = GameState.selected_hero_id
	hero_label.text = "Таланти: %s" % HeroPool.get_def(_hero_id).title
	var title := $VBoxContainer/TitleLabel as Label
	title.text = "Храм — таланти"
	title.add_theme_color_override("font_color", UiTheme.HEADING)
	UiTheme.add_dividers(title)
	# Список — посередині екрана: на широкому телефоні він інакше тулився
	# до лівого краю, а праворуч зяяла порожнеча.
	rows_container.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
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

func _rebuild() -> void:
	gold_label.text = "Золото: %d" % GameState.gold
	for child in rows_container.get_children():
		child.queue_free()
	for upgrade in GENERIC_UPGRADES:
		rows_container.add_child(_build_row(upgrade.id, upgrade.title, upgrade.per_level))

	var talent_id := HeroPool.get_def(_hero_id).unique_talent_id
	if talent_id != &"" and TALENTS.has(talent_id):
		var talent: Dictionary = TALENTS[talent_id]
		rows_container.add_child(_build_row(talent_id, talent.title, talent.per_level))

## Рядок таланту. Ліворуч — місце під іконку: щойно покладете файл
## res://assets/ui/icons/talents/<id таланту>.png, вона з'явиться тут
## замість кольорової заглушки.
func _build_row(id: StringName, title: String, per_level: String) -> Control:
	var level := GameState.get_meta_level(_hero_id, id)
	var max_level := GameState.get_meta_max_level(id)

	# Кожен талант — картка в рамці; іконка — у слоті. Своєї картинки
	# (assets/ui/icons/talents/<id>.png) ще немає — стоїть зірка.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_box())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var own_icon := ArtSlots.talent_icon(id)
	if own_icon != null:
		# Готовий арт — без рамки-слота, вона лише забруднює картинку.
		row.add_child(UiTheme.make_bare_icon(own_icon, 60.0))
	else:
		row.add_child(UiTheme.make_slot(UiTheme.control_icon("star"), 44.0, UiTheme.HEADING))

	var info := Label.new()
	info.custom_minimum_size = Vector2(400, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "%s (%s) — рівень %d/%d" % [title, per_level, level, max_level]
	row.add_child(info)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(170, 44)
	buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if level >= max_level:
		buy_button.text = "Максимум"
		buy_button.disabled = true
	else:
		var cost := GameState.get_meta_upgrade_cost(_hero_id, id)
		buy_button.text = "Купити (%d)" % cost
		buy_button.disabled = GameState.gold < cost
		buy_button.pressed.connect(_on_buy_pressed.bind(id))
	row.add_child(buy_button)

	return card

func _on_buy_pressed(id: StringName) -> void:
	GameState.buy_meta_upgrade(_hero_id, id)
	_rebuild()

func _on_back_pressed() -> void:
	# Назад — туди, звідки прийшли: у місто до дверей будівлі чи в меню.
	GameState.return_from_ui()
