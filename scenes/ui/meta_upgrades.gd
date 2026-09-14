extends Control

## Екран мета-прогресії ("база"): тут гравець між ранами витрачає
## золото на постійні бонуси (GameState.buy_meta_upgrade). Список
## відповідає розділу 6 ТЗ. Розблокування 2-го/3-го героя свідомо
## не додане — героїв поки один, це Фаза 5.

const UPGRADES := [
	{"id": &"meta_max_hp", "title": "Здоров'я", "per_level": "+10 HP"},
	{"id": &"meta_damage", "title": "Шкода", "per_level": "+5%"},
	{"id": &"meta_move_speed", "title": "Швидкість", "per_level": "+3%"},
	{"id": &"meta_pickup_radius", "title": "Радіус підбору", "per_level": "+8"},
	{"id": &"meta_gold_gain", "title": "Приріст золота", "per_level": "+7%"},
	{"id": &"meta_luck", "title": "Удача", "per_level": "+4% шанс кращих апгрейдів"},
	{"id": &"meta_start_level", "title": "Стартовий рівень", "per_level": "+1 рівень старту"},
]

@onready var gold_label: Label = $VBoxContainer/GoldLabel
@onready var rows_container: VBoxContainer = $VBoxContainer/ScrollContainer/RowsContainer

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	gold_label.text = "Золото: %d" % GameState.gold
	for child in rows_container.get_children():
		child.queue_free()
	for upgrade in UPGRADES:
		rows_container.add_child(_build_row(upgrade))

func _build_row(upgrade: Dictionary) -> Control:
	var id: StringName = upgrade.id
	var level := GameState.get_meta_level(id)
	var max_level := GameState.get_meta_max_level(id)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var info := Label.new()
	info.custom_minimum_size = Vector2(400, 0)
	info.text = "%s (%s) — рівень %d/%d" % [upgrade.title, upgrade.per_level, level, max_level]
	row.add_child(info)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(150, 40)
	if level >= max_level:
		buy_button.text = "Максимум"
		buy_button.disabled = true
	else:
		var cost := GameState.get_meta_upgrade_cost(id)
		buy_button.text = "Купити (%d)" % cost
		buy_button.disabled = GameState.gold < cost
		buy_button.pressed.connect(_on_buy_pressed.bind(id))
	row.add_child(buy_button)

	return row

func _on_buy_pressed(id: StringName) -> void:
	GameState.buy_meta_upgrade(id)
	_rebuild()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
