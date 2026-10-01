extends Control

## Попап "Поки тебе не було" — головне меню показує його, якщо на
## старті застосунку накопичилось офлайн-золото
## (GameState.pending_offline_gold, порахований у GameState._ready()).

signal closed

@onready var amount_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/AmountLabel
@onready var claim_double_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ClaimDoubleButton

func _ready() -> void:
	amount_label.text = "+%d золота" % GameState.pending_offline_gold
	# Оформлення (UiTheme): заголовок блідо-зелений, подвоєння — світла
	# головна кнопка.
	var title := $CenterContainer/Panel/MarginContainer/VBoxContainer/TitleLabel as Label
	title.add_theme_color_override("font_color", UiTheme.HEADING)
	amount_label.add_theme_color_override("font_color", UiTheme.GOLD)
	# Сума — з монетою (арт гравця) замість слова "золота".
	var amount := CurrencyBadge.new(&"gold", 30, false)
	amount.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	amount.set_text("+" + UiTheme.format_amount(GameState.pending_offline_gold))
	amount_label.add_sibling(amount)
	amount_label.visible = false
	UiTheme.make_primary(claim_double_button)

func _on_claim_pressed() -> void:
	GameState.claim_offline_gold(1)
	_close()

func _on_claim_double_pressed() -> void:
	claim_double_button.disabled = true
	AdsManager.show_rewarded_ad(_on_ad_reward_granted, _on_ad_skipped)

func _on_ad_reward_granted() -> void:
	GameState.claim_offline_gold(2)
	_close()

## Ролик не завантажився або його закрили — звичайне "Забрати" лишається.
func _on_ad_skipped() -> void:
	claim_double_button.text = "Нагороду не отримано"

func _close() -> void:
	closed.emit()
	queue_free()
