extends Control

## Екран вибору апгрейду при левел-апі. Гру ставить на паузу той,
## хто цю сцену створює (run.gd) — сама сцена лише показує картки
## й після кліку віддає id обраного апгрейду через сигнал.

signal upgrade_chosen(id: StringName)

@onready var level_label: Label = $CenterContainer/VBoxContainer/LevelLabel
@onready var cards_container: HBoxContainer = $CenterContainer/VBoxContainer/CardsContainer

func setup(new_level: int, choices: Array[UpgradeDef], current_levels: Dictionary) -> void:
	level_label.text = "Рівень %d!" % new_level
	for upgrade in choices:
		var current_level: int = current_levels.get(upgrade.id, 0)
		var card := Button.new()
		card.custom_minimum_size = Vector2(220, 180)
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
