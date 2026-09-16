extends Control

## Магазин: геми за реальні гроші (IapManager), обмін гемів на золото,
## три стартові набори за геми (кожен — один раз, гравець обирає сам)
## і remove_ads. Кнопка "Відновити покупки" обов'язкова за правилами
## магазинів (розділ 8 ТЗ).

const STARTER_PACK_TITLES := {
	&"starter_ads": "Набір без реклами",
	&"starter_hero": "Набір героя",
	&"starter_gold": "Набір скарбника",
}

const GEM_TITLES := {
	"gems_small": "Жменя гемів",
	"gems_medium": "Мішечок гемів",
	"gems_large": "Скриня гемів",
}

const STATUS_SEC := 3.0

@onready var gems_label: Label = $VBoxContainer/CurrencyRow/GemsLabel
@onready var gold_label: Label = $VBoxContainer/CurrencyRow/GoldLabel
@onready var rows_container: VBoxContainer = $VBoxContainer/ScrollContainer/RowsContainer
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var restore_button: Button = $VBoxContainer/BottomRow/RestoreButton

var _status_left := 0.0

func _ready() -> void:
	IapManager.purchase_granted.connect(_on_purchase_granted)
	IapManager.purchase_failed.connect(_on_purchase_failed)
	IapManager.restore_finished.connect(_on_restore_finished)
	IapManager.prices_updated.connect(_rebuild)
	status_label.text = ""
	_rebuild()

func _process(delta: float) -> void:
	if _status_left > 0.0:
		_status_left -= delta
		if _status_left <= 0.0:
			status_label.text = ""

func _rebuild() -> void:
	gems_label.text = "Геми: %d" % GameState.gems
	gold_label.text = "Золото: %d" % GameState.gold
	for child in rows_container.get_children():
		child.queue_free()

	rows_container.add_child(_build_header("Геми"))
	for product_id: String in IapManager.GEM_PRODUCTS:
		var amount: int = IapManager.GEM_PRODUCTS[product_id]
		var button := _build_row(rows_container, "%s — %d гемів" % [GEM_TITLES[product_id], amount])
		button.text = IapManager.get_price_text(product_id)
		button.pressed.connect(IapManager.purchase.bind(product_id))

	rows_container.add_child(_build_header("Обмін гемів на золото"))
	for i in Balance.GEM_EXCHANGES.size():
		var exchange: Array = Balance.GEM_EXCHANGES[i]
		var button := _build_row(rows_container, "%d золота" % exchange[1])
		button.text = "%d гемів" % exchange[0]
		button.disabled = GameState.gems < exchange[0]
		button.pressed.connect(_on_exchange_pressed.bind(i))

	rows_container.add_child(_build_header("Стартові набори (кожен — один раз)"))
	var seconds_left := GameState.get_starter_packs_seconds_left()
	if seconds_left > 0:
		var wait := Label.new()
		wait.text = "З'являться через %d год %d хв" % [seconds_left / 3600, (seconds_left % 3600) / 60]
		rows_container.add_child(wait)
	else:
		for pack_id: StringName in GameState.STARTER_PACK_IDS:
			var text := "%s\n%s" % [STARTER_PACK_TITLES[pack_id], _get_pack_desc(pack_id)]
			var button := _build_row(rows_container, text)
			if GameState.is_starter_pack_claimed(pack_id):
				button.text = "Куплено"
				button.disabled = true
			else:
				var cost := GameState.get_starter_pack_cost(pack_id)
				button.text = "%d гемів" % cost
				button.disabled = GameState.gems < cost
				button.pressed.connect(_on_starter_pack_pressed.bind(pack_id))

	rows_container.add_child(_build_header("Без реклами"))
	var ads_button := _build_row(rows_container, "Прибирає банер і рекламу між ранами.\nРолики за нагороду лишаються за бажанням.")
	if GameState.ads_removed:
		ads_button.text = "Куплено"
		ads_button.disabled = true
	else:
		ads_button.text = IapManager.get_price_text(IapManager.REMOVE_ADS)
		ads_button.pressed.connect(IapManager.purchase.bind(IapManager.REMOVE_ADS))

## Опис набору. Якщо частину набору гравець уже має — пишемо, що
## отримає замість неї (сама логіка в GameState.buy_starter_pack).
func _get_pack_desc(pack_id: StringName) -> String:
	match pack_id:
		&"starter_ads":
			if GameState.ads_removed:
				return "%d золота (реклама вже прибрана)" % Balance.STARTER_ADS_GOLD
			return "%d золота + прибрати банер і рекламу між ранами" % Balance.STARTER_ADS_GOLD
		&"starter_hero":
			var blade_warden := HeroPool.get_def(&"blade_warden")
			if GameState.is_hero_unlocked(&"blade_warden"):
				return "%d золота (герой уже є — замість нього золото)" % (Balance.STARTER_HERO_GOLD + blade_warden.unlock_cost)
			return "%s + %d золота" % [blade_warden.title, Balance.STARTER_HERO_GOLD]
		&"starter_gold":
			return "%d золота" % Balance.STARTER_GOLD_GOLD
	return ""

func _build_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1))
	return label

## Рядок "опис + кнопка". Повертає кнопку, щоб виклик сам задав текст і дію.
func _build_row(parent: Control, info_text: String) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var info := Label.new()
	info.custom_minimum_size = Vector2(400, 0)
	info.text = info_text
	row.add_child(info)
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 44)
	row.add_child(button)
	parent.add_child(row)
	return button

func _show_status(text: String) -> void:
	status_label.text = text
	_status_left = STATUS_SEC

func _on_exchange_pressed(index: int) -> void:
	if GameState.exchange_gems_for_gold(index):
		_show_status("Обмін виконано: +%d золота" % Balance.GEM_EXCHANGES[index][1])
	_rebuild()

func _on_starter_pack_pressed(id: StringName) -> void:
	if GameState.buy_starter_pack(id):
		_show_status("Набір отримано!")
	_rebuild()

func _on_purchase_granted(product_id: String) -> void:
	if IapManager.GEM_PRODUCTS.has(product_id):
		_show_status("+%d гемів" % IapManager.GEM_PRODUCTS[product_id])
	elif product_id == IapManager.REMOVE_ADS:
		_show_status("Рекламу прибрано")
	_rebuild()

func _on_purchase_failed(_product_id: String, message: String) -> void:
	_show_status(message)

func _on_restore_pressed() -> void:
	restore_button.disabled = true
	_show_status("Перевіряємо покупки…")
	IapManager.restore_purchases()

func _on_restore_finished(restored_count: int) -> void:
	restore_button.disabled = false
	if restored_count > 0:
		_show_status("Покупки відновлено")
	else:
		_show_status("Покупок для відновлення не знайдено")
	_rebuild()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
