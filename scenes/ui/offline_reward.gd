extends Control

## Попап "Поки тебе не було" — головне меню показує його, якщо на
## старті застосунку накопичилось офлайн-золото
## (GameState.pending_offline_gold, порахований у GameState._ready()).

signal closed

@onready var amount_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/AmountLabel

func _ready() -> void:
	amount_label.text = "+%d золота" % GameState.pending_offline_gold

func _on_claim_pressed() -> void:
	GameState.claim_offline_gold(1)
	_close()

func _on_claim_double_pressed() -> void:
	AdsManager.show_rewarded_ad(_on_ad_reward_granted)

func _on_ad_reward_granted() -> void:
	GameState.claim_offline_gold(2)
	_close()

func _close() -> void:
	closed.emit()
	queue_free()
