extends Control

## Вітальний бонус на вході в гру: "З поверненням!" і скільки золота
## герої зібрали, поки гравця не було (GameState.pending_offline_gold,
## порахований у GameState._ready()). Головне меню показує вікно, якщо там
## є що забрати. Вигляд — спільне OrnateDialog: рамка гравця, монета з
## сумою, зелена кнопка "×2 за рекламу" і синя "Забрати".

signal closed

var _dialog: OrnateDialog
var _double_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog = OrnateDialog.new("З поверненням!", ArtSlots.currency_icon(&"gold"), UiTheme.GOLD, 520.0, "Вітальний бонус")
	# Нагороду не закривають повз рамку — лише забирають.
	_dialog.closable = false
	add_child(_dialog)
	_dialog.add_text("Поки тебе не було, твої герої зібрали:")
	var amount := CurrencyBadge.new(&"gold", 40, false)
	amount.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	amount.set_text("+" + UiTheme.format_amount(GameState.pending_offline_gold))
	_dialog.body.add_child(amount)
	_dialog.add_text("Подивись коротку рекламу — і забереш удвічі більше.", 15, Color(0.8, 0.78, 0.9))
	_double_button = _dialog.add_button("Забрати ×2", true, _on_claim_double_pressed, 200.0)
	_dialog.add_button("Забрати", false, _on_claim_pressed, 200.0)

func _on_claim_pressed() -> void:
	GameState.claim_offline_gold(1)
	_close()

func _on_claim_double_pressed() -> void:
	_double_button.disabled = true
	AdsManager.show_rewarded_ad(_on_ad_reward_granted, _on_ad_skipped)

func _on_ad_reward_granted() -> void:
	GameState.claim_offline_gold(2)
	_close()

## Ролик не завантажився або його закрили — звичайне "Забрати" лишається.
func _on_ad_skipped() -> void:
	_double_button.text = "Не вийшло"

func _close() -> void:
	closed.emit()
	queue_free()
