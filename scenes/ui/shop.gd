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
## Тло — крамниця з полицями й скринями (арт гравця).
const SHOP_BACKGROUND := "res://assets/ui/backgrounds/shop.jpg"

var _gems_badge: CurrencyBadge
var _gold_badge: CurrencyBadge
var _rows_container: VBoxContainer
var _status_label: Label
var _restore_button: Button

var _status_left := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.055, 0.065, 0.078)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	if ResourceLoader.exists(SHOP_BACKGROUND):
		var shop_art := TextureRect.new()
		shop_art.texture = load(SHOP_BACKGROUND)
		shop_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shop_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		shop_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shop_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shop_art)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 28.0
	column.offset_top = 16.0
	column.offset_right = -28.0
	column.offset_bottom = -16.0
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var top_row := HBoxContainer.new()
	column.add_child(top_row)
	var title_box := UiTheme.make_title("Ринок", 30)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_box)
	top_row.add_theme_constant_override("separation", 8)
	_gold_badge = CurrencyBadge.new(&"gold")
	top_row.add_child(_gold_badge)
	_gems_badge = CurrencyBadge.new(&"gem")
	top_row.add_child(_gems_badge)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_rows_container = VBoxContainer.new()
	_rows_container.custom_minimum_size = Vector2(680, 0)
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	_rows_container.add_theme_constant_override("separation", 10)
	scroll.add_child(_rows_container)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.add_theme_color_override("font_color", UiTheme.HEADING)
	_status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status_label.add_theme_constant_override("outline_size", 6)
	column.add_child(_status_label)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 16)
	column.add_child(bottom_row)

	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(170, 52)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_on_back_pressed)
	bottom_row.add_child(back)

	_restore_button = Button.new()
	_restore_button.text = "Відновити покупки"
	_restore_button.custom_minimum_size = Vector2(220, 52)
	_restore_button.add_theme_font_size_override("font_size", 16)
	_restore_button.pressed.connect(_on_restore_pressed)
	bottom_row.add_child(_restore_button)

	IapManager.purchase_granted.connect(_on_purchase_granted)
	IapManager.purchase_failed.connect(_on_purchase_failed)
	IapManager.restore_finished.connect(_on_restore_finished)
	IapManager.prices_updated.connect(_rebuild)
	_rebuild()

func _process(delta: float) -> void:
	if _status_left > 0.0:
		_status_left -= delta
		if _status_left <= 0.0:
			_status_label.text = ""

func _rebuild() -> void:
	_gems_badge.set_amount(GameState.gems)
	_gold_badge.set_amount(GameState.gold)
	for child in _rows_container.get_children():
		child.queue_free()

	_rows_container.add_child(_build_header("Геми"))
	for product_id: String in IapManager.GEM_PRODUCTS:
		var amount: int = IapManager.GEM_PRODUCTS[product_id]
		var button := _build_row(GEM_TITLES[product_id], "%s гемів" % UiTheme.format_amount(amount), product_id, UiTheme.GEM)
		button.text = IapManager.get_price_text(product_id)
		UiTheme.make_primary(button)
		button.pressed.connect(IapManager.purchase.bind(product_id))

	_rows_container.add_child(_build_header("Обмін гемів на золото"))
	for i in Balance.GEM_EXCHANGES.size():
		var exchange: Array = Balance.GEM_EXCHANGES[i]
		var button := _build_row("Обмін", "%s золота" % UiTheme.format_amount(exchange[1]), "exchange")
		button.disabled = GameState.gems < exchange[0]
		if not button.disabled:
			UiTheme.make_primary(button)
		PriceTag.apply(button, &"gem", exchange[0])
		button.pressed.connect(_on_exchange_pressed.bind(i))

	_rows_container.add_child(_build_header("Стартові набори (кожен — один раз)"))
	var seconds_left := GameState.get_starter_packs_seconds_left()
	if seconds_left > 0:
		var wait := Label.new()
		wait.text = "З'являться через %d год %d хв" % [seconds_left / 3600, (seconds_left % 3600) / 60]
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wait.add_theme_color_override("font_color", UiTheme.TEXT)
		wait.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		wait.add_theme_constant_override("outline_size", 6)
		_rows_container.add_child(wait)
	else:
		for pack_id: StringName in GameState.STARTER_PACK_IDS:
			var button := _build_row(STARTER_PACK_TITLES[pack_id], _get_pack_desc(pack_id), String(pack_id))
			if GameState.is_starter_pack_claimed(pack_id):
				button.text = "Куплено"
				button.disabled = true
			else:
				var cost := GameState.get_starter_pack_cost(pack_id)
				button.disabled = GameState.gems < cost
				if not button.disabled:
					UiTheme.make_primary(button)
				PriceTag.apply(button, &"gem", cost)
				button.pressed.connect(_on_starter_pack_pressed.bind(pack_id))

	_rows_container.add_child(_build_header("Без реклами"))
	var ads_button := _build_row("Без реклами", "Прибирає банер і рекламу між ранами.\nРолики за нагороду лишаються за бажанням.", "remove_ads")
	if GameState.ads_removed:
		ads_button.text = "Куплено"
		ads_button.disabled = true
	else:
		ads_button.text = IapManager.get_price_text(IapManager.REMOVE_ADS)
		UiTheme.make_primary(ads_button)
		ads_button.pressed.connect(IapManager.purchase.bind(IapManager.REMOVE_ADS))

## Опис набору. Якщо частину набору гравець уже має — пишемо, що
## отримає замість неї (сама логіка в GameState.buy_starter_pack).
func _get_pack_desc(pack_id: StringName) -> String:
	match pack_id:
		&"starter_ads":
			if GameState.ads_removed:
				return "%s золота (реклама вже прибрана)" % UiTheme.format_amount(Balance.STARTER_ADS_GOLD)
			return "%s золота + прибрати банер і рекламу між ранами" % UiTheme.format_amount(Balance.STARTER_ADS_GOLD)
		&"starter_hero":
			var blade_warden := HeroPool.get_def(&"blade_warden")
			if GameState.is_hero_unlocked(&"blade_warden"):
				return "%s золота (герой уже є — замість нього золото)" % UiTheme.format_amount(Balance.STARTER_HERO_GOLD + blade_warden.unlock_cost)
			return "%s + %s золота" % [blade_warden.title, UiTheme.format_amount(Balance.STARTER_HERO_GOLD)]
		&"starter_gold":
			return "%s золота" % UiTheme.format_amount(Balance.STARTER_GOLD_GOLD)
	return ""

func _build_header(text: String) -> Control:
	var row := SectionBanner.new(text, 20)
	var top_gap := Control.new()
	top_gap.custom_minimum_size = Vector2(0, 6)
	top_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows_container.add_child(top_gap)
	return row

## Рядок "іконка + назва + опис + кнопка" — картка товару (арт гравця) з
## відсіком під іконку зліва. Повертає кнопку, щоб виклик сам задав
## текст і дію.
##
## Висота картки фіксована (UiTheme.ITEM_CARD_HEIGHT): відсік — частина
## рамки, і на вищій картці він би витягнувся. Іконка — першою в ряду, і
## картка сама ставить її в центр відсіку, тож іконки всіх карток стоять
## рівно одна під одною. Іконка — файл res://assets/ui/icons/shop/<назва>.png
## (див. assets/ART_GUIDE.md); немає — біла заглушка в кольорі товару.
func _build_row(item_title: String, description: String, icon_name: String = "", accent: Color = Color(1, 0.86, 0.4)) -> Button:
	var own_icon := ArtSlots.shop_icon(icon_name)
	var card: PanelContainer
	if own_icon != null:
		card = UiTheme.make_item_card(own_icon)
	else:
		card = UiTheme.make_item_card(UiTheme.control_icon("money" if icon_name == "exchange" else "star"), accent)
	var row := card.get_child(0) as HBoxContainer

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = item_title
	name_label.add_theme_font_override("font", UiTheme.font(800))
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	info.add_child(name_label)
	var desc_label := Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.82, 0.8, 0.92))
	info.add_child(desc_label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(160, 48)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	_rows_container.add_child(card)
	UiTheme.tag_scroll_pass(card)
	return button

func _show_status(text: String) -> void:
	_status_label.text = text
	_status_left = STATUS_SEC

func _on_exchange_pressed(index: int) -> void:
	if GameState.exchange_gems_for_gold(index):
		AudioManager.play(&"gold", 0.0)
		_show_status("Обмін виконано: +%s золота" % UiTheme.format_amount(Balance.GEM_EXCHANGES[index][1]))
	_rebuild()

func _on_starter_pack_pressed(id: StringName) -> void:
	if GameState.buy_starter_pack(id):
		AudioManager.play(&"purchase", 0.0)
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
	_restore_button.disabled = true
	_show_status("Перевіряємо покупки…")
	IapManager.restore_purchases()

func _on_restore_finished(restored_count: int) -> void:
	_restore_button.disabled = false
	if restored_count > 0:
		_show_status("Покупки відновлено")
	else:
		_show_status("Покупок для відновлення не знайдено")
	_rebuild()

func _on_back_pressed() -> void:
	# Назад — туди, звідки прийшли: у місто до дверей будівлі чи в меню.
	GameState.return_from_ui()
