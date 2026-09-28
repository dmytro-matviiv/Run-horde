extends Control

## Екран вибору апгрейду при левел-апі. Гру ставить на паузу той,
## хто цю сцену створює (run.gd) — сама сцена лише показує картки
## й після кліку віддає id обраного апгрейду через сигнал.

signal upgrade_chosen(id: StringName)

@onready var level_label: Label = $CenterContainer/VBoxContainer/LevelLabel
@onready var cards_container: HBoxContainer = $CenterContainer/VBoxContainer/CardsContainer

## Картки нового зразка: кожна вже знає свій рівень і межу. Саме ними
## користується данж (RunUpgrades), бо його здібності залежать від
## героя та його зброї.
func setup_cards(new_level: int, cards: Array) -> void:
	level_label.text = "Рівень %d!" % new_level
	for card: Dictionary in cards:
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 190)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s

%s

Рівень %d/%d" % [card.title, card.text, card.level, card.max]
		button.pressed.connect(_on_card_pressed.bind(card.id))
		cards_container.add_child(button)

func setup(new_level: int, choices: Array[UpgradeDef], current_levels: Dictionary) -> void:
	level_label.text = "Рівень %d!" % new_level
	for upgrade in choices:
		var current_level: int = current_levels.get(upgrade.id, 0)
		var card := Button.new()
		# Ширина фіксована, а довгий опис переноситься на новий рядок.
		# Без цього картка розтягувалась під найдовший рядок і вилазила
		# за край екрана — опис здібності було не дочитати.
		card.custom_minimum_size = Vector2(250, 190)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.text = "%s\n\n%s\n\nРівень %d/%d" % [
			upgrade.title,
			upgrade.description,
			current_level + 1,
			upgrade.max_level,
		]
		card.pressed.connect(_on_card_pressed.bind(upgrade.id))
		cards_container.add_child(card)

func _on_card_pressed(id: StringName) -> void:
	upgrade_chosen.emit(id)
