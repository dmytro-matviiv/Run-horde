extends Node

## Обгортка над покупками за реальні гроші (розділ 8 ТЗ). Як і
## AdsManager: якщо в збірці є нативний плагін Google Play Billing
## (Android) — справжня покупка через Google Play; інакше (редактор, ПК)
## — видиме вікно "Тестова покупка", щоб увесь сценарій магазину можна
## було пройти без телефона. Гроші на ПК не списуються.
##
## Гра не видає товар у момент натискання "Купити": Google може
## повідомити про покупку пізніше (оплата готівкою в терміналі, збій
## зв'язку, перезапуск гри). Тому товар видається в одному місці —
## _grant() — а екран дізнається про це сигналом purchase_granted.
##
## Справжні покупки працюють лише зі збірки, завантаженої в Play Console
## (хоча б у внутрішнє тестування), з товарами, створеними там з тими ж id.

signal purchase_granted(product_id: String)
signal purchase_failed(product_id: String, message: String)
signal restore_finished(restored_count: int)
signal prices_updated

const REMOVE_ADS := "remove_ads"
const GEM_PRODUCTS := {
	"gems_small": Balance.GEMS_SMALL,
	"gems_medium": Balance.GEMS_MEDIUM,
	"gems_large": Balance.GEMS_LARGE,
}
## Показуються, поки Google не повернув справжні ціни у валюті гравця
## (і завжди на ПК). Ціни з ТЗ.
const FALLBACK_PRICES := {
	"gems_small": "$0.99",
	"gems_medium": "$4.99",
	"gems_large": "$19.99",
	REMOVE_ADS: "$1.99",
}

const RECONNECT_DELAY := 30.0

var _is_real := false
var _billing: BillingClient
var _prices: Dictionary = {}          # product_id -> ціна рядком від Google ("99,99 грн")
var _consume_tokens: Dictionary = {}  # purchase_token -> product_id гемів, що чекають consume
var _mock_layer: CanvasLayer
var _restoring := false
var _restored_count := 0
var _reconnect_scheduled := false

func _ready() -> void:
	_is_real = Engine.has_singleton("GodotGooglePlayBilling")
	if not _is_real:
		_mock_layer = CanvasLayer.new()
		_mock_layer.layer = 100
		_mock_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_mock_layer)
		return
	_billing = BillingClient.new()
	add_child(_billing)
	_billing.connected.connect(_on_connected)
	_billing.disconnected.connect(_schedule_reconnect)
	_billing.connect_error.connect(func(_code: int, _msg: String) -> void: _schedule_reconnect())
	_billing.query_product_details_response.connect(_on_product_details)
	_billing.query_purchases_response.connect(_on_query_purchases)
	_billing.on_purchase_updated.connect(_on_purchase_updated)
	_billing.consume_purchase_response.connect(_on_consume_response)
	_billing.acknowledge_purchase_response.connect(_on_acknowledge_response)
	_billing.start_connection()

func get_all_product_ids() -> PackedStringArray:
	var ids := PackedStringArray(GEM_PRODUCTS.keys())
	ids.append(REMOVE_ADS)
	return ids

func get_price_text(product_id: String) -> String:
	return _prices.get(product_id, FALLBACK_PRICES.get(product_id, "?"))

## Запускає покупку. Результат приходить сигналом purchase_granted або
## purchase_failed (зокрема, якщо гравець сам закрив вікно оплати).
func purchase(product_id: String) -> void:
	if not _is_real:
		_show_mock_purchase(product_id)
		return
	if not _billing.is_ready():
		_billing.start_connection()
		purchase_failed.emit(product_id, "Немає зв'язку з Google Play")
		return
	var result := _billing.purchase(product_id)
	if result.get("response_code", -1) != BillingClient.BillingResponseCode.OK:
		purchase_failed.emit(product_id, "Покупка недоступна")

## Кнопка "Відновити покупки" — повертає remove_ads після перевстановлення
## гри чи на новому телефоні. Геми не відновлюються: вони витратні.
func restore_purchases() -> void:
	if not _is_real:
		# На ПК купівлі не в Google, а просто в сейві — відновлювати нічого.
		restore_finished.emit(0)
		return
	if not _billing.is_ready():
		_billing.start_connection()
		restore_finished.emit(0)
		return
	_restoring = true
	_restored_count = 0
	_billing.query_purchases(BillingClient.ProductType.INAPP)

func _on_connected() -> void:
	_billing.query_product_details(get_all_product_ids(), BillingClient.ProductType.INAPP)
	# Одразу перевіряємо власні покупки: remove_ads на новому телефоні й
	# геми, які оплатили, але гра закрилась до того, як їх видала.
	_billing.query_purchases(BillingClient.ProductType.INAPP)

func _schedule_reconnect() -> void:
	if _reconnect_scheduled:
		return
	_reconnect_scheduled = true
	await get_tree().create_timer(RECONNECT_DELAY).timeout
	_reconnect_scheduled = false
	_billing.start_connection()

func _on_product_details(response: Dictionary) -> void:
	if response.get("response_code", -1) != BillingClient.BillingResponseCode.OK:
		return
	for details: Dictionary in response.get("product_details", []):
		var offers: Variant = details.get("one_time_purchase_offer_details_list")
		if offers is Array and not offers.is_empty():
			_prices[details.product_id] = offers[0].get("formatted_price", "")
	prices_updated.emit()

func _on_query_purchases(response: Dictionary) -> void:
	if response.get("response_code", -1) == BillingClient.BillingResponseCode.OK:
		for purchase_data: Dictionary in response.get("purchases", []):
			_process_purchase(purchase_data)
	if _restoring:
		_restoring = false
		restore_finished.emit(_restored_count)

func _on_purchase_updated(response: Dictionary) -> void:
	var code: int = response.get("response_code", -1)
	if code == BillingClient.BillingResponseCode.OK:
		for purchase_data: Dictionary in response.get("purchases", []):
			_process_purchase(purchase_data)
	elif code == BillingClient.BillingResponseCode.USER_CANCELED:
		purchase_failed.emit("", "Покупку скасовано")
	elif code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
		# Напр. remove_ads куплено на іншому телефоні — просто відновлюємо.
		_billing.query_purchases(BillingClient.ProductType.INAPP)
	else:
		purchase_failed.emit("", "Помилка оплати")

func _process_purchase(purchase_data: Dictionary) -> void:
	# Array(...) — плагін може віддати і Array, і PackedStringArray.
	var product_ids := Array(purchase_data.get("product_ids", []))
	if product_ids.is_empty():
		return
	var product_id: String = product_ids[0]
	var token: String = purchase_data.get("purchase_token", "")
	if purchase_data.get("purchase_state", 0) != BillingClient.PurchaseState.PURCHASED:
		# PENDING: гравець ще не оплатив (напр. готівкою) — нічого не видаємо,
		# Google надішле on_purchase_updated, коли оплата пройде.
		purchase_failed.emit(product_id, "Оплата очікується — товар прийде після оплати")
		return

	if GEM_PRODUCTS.has(product_id):
		# Витратний товар: спершу consume, а геми — лише коли Google
		# підтвердив (_on_consume_response). Так геми не видаються двічі.
		if _consume_tokens.has(token):
			return   # consume цієї покупки вже в дорозі
		_consume_tokens[token] = product_id
		_billing.consume_purchase(token)
	elif product_id == REMOVE_ADS:
		if purchase_data.get("is_acknowledged", false):
			if _restoring:
				_restored_count += 1
			_grant(product_id)
		else:
			# Без acknowledge Google через 3 дні поверне гравцю гроші.
			_billing.acknowledge_purchase(token)

func _on_consume_response(response: Dictionary) -> void:
	var token: String = response.get("token", "")
	if not _consume_tokens.has(token):
		return
	var product_id: String = _consume_tokens[token]
	_consume_tokens.erase(token)
	if response.get("response_code", -1) == BillingClient.BillingResponseCode.OK:
		_grant(product_id)
	else:
		# Не consumed — покупка лишиться в Google, і наступний запуск
		# (query_purchases) спробує ще раз.
		purchase_failed.emit(product_id, "Покупку не підтверджено, спробуємо пізніше")

func _on_acknowledge_response(response: Dictionary) -> void:
	if response.get("response_code", -1) == BillingClient.BillingResponseCode.OK:
		_grant(REMOVE_ADS)

## Єдине місце, де покупка перетворюється на товар у грі.
func _grant(product_id: String) -> void:
	if GEM_PRODUCTS.has(product_id):
		GameState.add_gems(GEM_PRODUCTS[product_id])
	elif product_id == REMOVE_ADS:
		if GameState.ads_removed:
			return   # уже видано (повторне відновлення) — сигнал не потрібен
		GameState.grant_remove_ads()
	purchase_granted.emit(product_id)

## Імітація вікна оплати Google Play на ПК.
func _show_mock_purchase(product_id: String) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mock_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "ТЕСТОВА ПОКУПКА (Google Play)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var item := Label.new()
	item.text = "%s — %s" % [product_id, get_price_text(product_id)]
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_font_size_override("font_size", 20)
	box.add_child(item)

	var hint := Label.new()
	hint.text = "Заглушка на ПК — гроші не списуються.\nНа телефоні тут справжнє вікно оплати."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	box.add_child(hint)

	var buy_button := Button.new()
	buy_button.text = "Купити"
	buy_button.custom_minimum_size = Vector2(260, 50)
	box.add_child(buy_button)

	var cancel_button := Button.new()
	cancel_button.text = "Скасувати"
	cancel_button.custom_minimum_size = Vector2(260, 50)
	box.add_child(cancel_button)

	# Словник, бо лямбди захоплюють bool за значенням: подвійний клік
	# не видасть товар двічі.
	var state := {"finished": false}
	buy_button.pressed.connect(func() -> void:
		if state.finished:
			return
		state.finished = true
		overlay.queue_free()
		_grant(product_id))
	cancel_button.pressed.connect(func() -> void:
		if state.finished:
			return
		state.finished = true
		overlay.queue_free()
		purchase_failed.emit(product_id, "Покупку скасовано"))
