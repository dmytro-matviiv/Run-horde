extends Control

## Головне меню: точка повернення між ранами. "Грати" веде в ран,
## "Апгрейди" — на екран мета-прогресії (тут гравець витрачає золото
## між ранами — наша "база"). Тут же показуємо офлайн-золото
## (GameState.pending_offline_gold) і скриньку за таймером.

const OFFLINE_REWARD_SCENE := preload("res://scenes/ui/offline_reward.tscn")

@onready var gold_label: Label = $CenterContainer/VBoxContainer/GoldLabel
@onready var chest_button: Button = $CenterContainer/VBoxContainer/ChestButton

const CHEST_MESSAGE_SEC := 3.0

var _chest_refresh_timer := 0.0
var _chest_message_left := 0.0   # поки > 0, щосекундне оновлення не затирає повідомлення

func _ready() -> void:
	_update_gold_label()
	_update_chest_button()
	if GameState.pending_offline_gold > 0:
		_show_offline_reward()

func _process(delta: float) -> void:
	if _chest_message_left > 0.0:
		_chest_message_left -= delta
		return
	_chest_refresh_timer += delta
	if _chest_refresh_timer >= 1.0:
		_chest_refresh_timer = 0.0
		_update_chest_button()

func _update_gold_label() -> void:
	gold_label.text = "Золото: %d" % GameState.gold

func _update_chest_button() -> void:
	if GameState.is_chest_available():
		chest_button.text = "Скринька (реклама)"
		chest_button.disabled = false
	else:
		var minutes_left := GameState.get_chest_seconds_left() / 60
		chest_button.text = "Скринька через %d хв" % minutes_left
		chest_button.disabled = true

func _show_offline_reward() -> void:
	var popup: Node = OFFLINE_REWARD_SCENE.instantiate()
	add_child(popup)
	popup.closed.connect(_update_gold_label)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/run/run.tscn")

func _on_upgrades_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/meta_upgrades.tscn")

func _on_heroes_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/heroes.tscn")

func _on_chest_pressed() -> void:
	chest_button.disabled = true
	AdsManager.show_rewarded_ad(_on_chest_ad_reward, _on_chest_ad_skipped)

func _on_chest_ad_reward() -> void:
	GameState.claim_chest_reward()
	_update_gold_label()
	_update_chest_button()

func _on_chest_ad_skipped() -> void:
	chest_button.text = "Реклама недоступна"
	_chest_message_left = CHEST_MESSAGE_SEC
