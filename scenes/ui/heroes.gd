extends Control

## Екран вибору героя — вітрина, а не список. Гравець гортає героїв по
## одному: у центрі 3D-модель, та сама, що й у бою, зі спорядженою
## зброєю в руці; під нею опис і картки здібностей. Натиснув картку —
## прочитав, що саме вміє цей клас.
##
## Якщо моделі героя ще немає, показується тимчасова в його кольорі, і
## екран чесно про це пише. Покладіть файл
## res://assets/models/heroes/<id героя>.glb — і він з'явиться тут сам.
##
## Купівля тут же: звичайні герої за золото (HeroDef.unlock_cost),
## преміум — за геми (HeroDef.gem_cost).

const ABILITY_ICON_SCRIPT := preload("res://scenes/ui/ability_icon.gd")
const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")

@onready var currency_label: Label = $VBoxContainer/TopRow/CurrencyLabel
@onready var stage: Control = $VBoxContainer/StageRow/Stage
## Позицію на сцені тримає окремий вузол-підставка: сам спрайт рухає
## аніматор (дихання, похитування), тож центрувати його напряму не можна
## — вони перезаписували б позицію один одному.
@onready var art_pivot: Node2D = $VBoxContainer/StageRow/Stage/ArtPivot
@onready var hero_art: Sprite2D = $VBoxContainer/StageRow/Stage/ArtPivot/HeroArt
@onready var glow: Control = $VBoxContainer/StageRow/Stage/Glow
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var icons_row: HBoxContainer = $VBoxContainer/IconsRow
@onready var action_button: Button = $VBoxContainer/BottomRow/ActionButton
@onready var popup: Control = $AbilityPopup
@onready var popup_title: Label = $AbilityPopup/Panel/VBoxContainer/TitleLabel
@onready var popup_text: Label = $AbilityPopup/Panel/VBoxContainer/TextLabel

var _index := 0
var _preview: ModelPreview
var _placeholder_label: Label

func _ready() -> void:
	_build_preview()
	_style()
	popup.visible = false
	_index = _find_index(GameState.selected_hero_id)
	_rebuild()

## Фентезійне оформлення (UiTheme): заголовок Зали, ім'я героя між
## розділювачами, опис і здібності — на панелі в рамці.
func _style() -> void:
	var title := $VBoxContainer/TopRow/TitleLabel as Label
	title.text = "Зала героїв"
	title.add_theme_color_override("font_color", UiTheme.HEADING)
	name_label.add_theme_color_override("font_color", UiTheme.TEXT)
	UiTheme.add_dividers(name_label)
	var info: Array[Control] = [description_label, stats_label, icons_row]
	UiTheme.wrap_in_panel(info)
	UiTheme.make_primary(action_button)
	($AbilityPopup/Panel as PanelContainer).add_theme_stylebox_override("panel", UiTheme.panel_box())
	popup_title.add_theme_color_override("font_color", UiTheme.HEADING)

## Вітрина кладеться поверх старої "сцени" зі спрайтом: сам спрайт
## ховаємо, а підсвічування знизу лишаємо — воно гарне.
func _build_preview() -> void:
	hero_art.visible = false
	_preview = MODEL_PREVIEW_SCRIPT.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_preview)

	_placeholder_label = Label.new()
	_placeholder_label.text = "Тимчасова модель — справжня буде пізніше"
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.add_theme_font_size_override("font_size", 13)
	_placeholder_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_placeholder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_placeholder_label)

func _process(_delta: float) -> void:
	glow.queue_redraw()

func _find_index(hero_id: StringName) -> int:
	for i in HeroPool.ALL_HEROES.size():
		if HeroPool.ALL_HEROES[i].id == hero_id:
			return i
	return 0

func _current() -> HeroDef:
	return HeroPool.ALL_HEROES[_index]

func _rebuild() -> void:
	var def := _current()
	currency_label.text = "Золото: %d    Геми: %d" % [GameState.gold, GameState.gems]
	name_label.text = def.title
	description_label.text = def.description
	_update_art(def)
	_update_stats(def)
	_update_icons(def)
	_update_action(def)

func _update_art(def: HeroDef) -> void:
	var weapon := WeaponPool.get_def(GameState.get_equipped_weapon_id(def.id))
	_placeholder_label.visible = _preview.show_hero(def, weapon)

func _update_stats(def: HeroDef) -> void:
	var hp := int(Balance.HERO_MAX_HP + def.bonus_max_hp)
	var speed_percent := int(round(def.move_speed_percent * 100.0))
	var weapon := WeaponPool.get_def(GameState.get_equipped_weapon_id(def.id))
	stats_label.text = "Здоров'я %d    Швидкість %+d%%    Зброя: %s" % [hp, speed_percent, weapon.title]

func _update_icons(def: HeroDef) -> void:
	for child in icons_row.get_children():
		child.queue_free()
	for card: Dictionary in _cards_for(def):
		var holder := VBoxContainer.new()
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		holder.add_theme_constant_override("separation", 4)

		var icon: Button = ABILITY_ICON_SCRIPT.new()
		icon.setup(card.kind, card.color, card.title)
		icon.pressed.connect(_on_ability_pressed.bind(card))
		holder.add_child(icon)

		var label := Label.new()
		label.text = card.title
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", card.color)
		holder.add_child(label)

		icons_row.add_child(holder)

## Картки здібностей беремо з того, що герой СПРАВДІ вміє в бою
## (Skills3D), а не з окремого опису — тоді вітрина не бреше. Третьою
## йде картка про арсенал зброї.
func _cards_for(def: HeroDef) -> Array:
	var cards := []
	# Особлива здібність посоха теж видна — та, що в спорядженого.
	var equipped := WeaponPool.get_def(GameState.get_equipped_weapon_id(def.id))
	for entry: Dictionary in Skills3D.describe(def, equipped):
		cards.append({
			"kind": &"talent" if entry.kind == &"passive" else &"blade",
			"color": entry.color,
			"title": entry.title,
			"text": entry.text,
		})
	var weapons := WeaponPool.get_for_hero(def.id)
	var lines := []
	for weapon: WeaponDef in weapons:
		lines.append("%s — %s" % [weapon.title, weapon.description])
	cards.append({
		"kind": &"weapon", "color": Color(1.0, 0.85, 0.4),
		"title": "Арсенал",
		"text": "\n".join(lines),
	})
	return cards

func _update_action(def: HeroDef) -> void:
	if GameState.selected_hero_id == def.id:
		action_button.text = "Обрано"
		action_button.disabled = true
	elif GameState.is_hero_unlocked(def.id):
		action_button.text = "Обрати"
		action_button.disabled = false
	elif def.gem_cost > 0:
		action_button.text = "Купити за %d гемів" % def.gem_cost
		action_button.disabled = GameState.gems < def.gem_cost
	else:
		action_button.text = "Купити за %d золота" % def.unlock_cost
		action_button.disabled = GameState.gold < def.unlock_cost

func _on_ability_pressed(card: Dictionary) -> void:
	popup_title.text = card.title
	popup_title.add_theme_color_override("font_color", card.color)
	popup_text.text = card.text
	popup.visible = true

func _on_popup_close_pressed() -> void:
	popup.visible = false

func _on_prev_pressed() -> void:
	_index = (_index - 1 + HeroPool.ALL_HEROES.size()) % HeroPool.ALL_HEROES.size()
	_rebuild()

func _on_next_pressed() -> void:
	_index = (_index + 1) % HeroPool.ALL_HEROES.size()
	_rebuild()

## Одна кнопка на три випадки: купити за золото, купити за геми або
## просто обрати вже наявного героя.
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

func _on_back_pressed() -> void:
	# Назад — туди, звідки прийшли: у місто до дверей будівлі чи в меню.
	GameState.return_from_ui()
