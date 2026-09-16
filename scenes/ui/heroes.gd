extends Control

## Екран вибору героя — вітрина, а не список. Гравець гортає героїв по
## одному: у центрі великий живий персонаж (той самий SpriteAnimator, що
## й у бою — дихає, погойдується, підсвічується), під ним опис і три
## іконки здібностей. Натиснув іконку — прочитав, що саме вміє цей клас.
##
## Купівля тут же: звичайні герої за золото (HeroDef.unlock_cost),
## преміум — за геми (HeroDef.gem_cost).

const ABILITY_ICON_SCRIPT := preload("res://scenes/ui/ability_icon.gd")
const ART_HEIGHT := 300.0
const FLOAT_SPEED := 1.6
const FLOAT_HEIGHT := 8.0

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
var _animator: SpriteAnimator
var _float_phase := 0.0

func _ready() -> void:
	_animator = SpriteAnimator.new()
	add_child(_animator)
	popup.visible = false
	_index = _find_index(GameState.selected_hero_id)
	_rebuild()

func _process(delta: float) -> void:
	# Легке "ширяння" поверх дихання аніматора — героя видно живим
	# навіть коли гравець просто роздивляється.
	_float_phase += delta * FLOAT_SPEED
	art_pivot.position = stage.size * 0.5 + Vector2(0, sin(_float_phase) * FLOAT_HEIGHT)
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
	if def.texture == null:
		hero_art.visible = false
		return
	hero_art.visible = true
	hero_art.texture = def.texture
	hero_art.scale = Vector2.ONE * (ART_HEIGHT / float(def.texture.get_height()))
	# Той самий аніматор, що й у бою: герой дихає, а не стоїть картинкою.
	_animator.setup(hero_art, def.texture, def.texture_back)
	_animator.reset()
	_animator.set_move_direction(Vector2.ZERO)

func _update_stats(def: HeroDef) -> void:
	var hp := int(Balance.HERO_MAX_HP + def.bonus_max_hp)
	var speed_percent := int(round(def.move_speed_percent * 100.0))
	var weapons := WeaponPool.get_for_hero(def.id).size()
	stats_label.text = "Здоров'я %d    Швидкість %+d%%    Зброї: %d" % [hp, speed_percent, weapons]

func _update_icons(def: HeroDef) -> void:
	for child in icons_row.get_children():
		child.queue_free()
	for card: Dictionary in HeroShowcase.get_cards(def.id):
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
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
