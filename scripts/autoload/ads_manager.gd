extends Node

## Обгортка над рекламою. Якщо в збірці є нативний AdMob-плагін (Android)
## — показує справжню рекламу; інакше (редактор, ПК) малює видиму
## заглушку (екран "Тестова реклама" з відліком і тестовий банер), щоб
## увесь сценарій можна було перевірити без телефона. Решта гри викликає
## лише публічні методи нижче й не знає, яка гілка активна.
##
## ID нижче — офіційні тестові від Google: завжди показують тестову
## рекламу й безпечні без AdMob-акаунта. Перед релізом замінити на реальні
## з AdMob-консолі, а App ID — у Project Settings → admob/general/android/app_id
## (зараз там дефолтний тестовий).

signal banner_height_changed(height_px: int)

const REWARDED_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"
const INTERSTITIAL_UNIT_ID := "ca-app-pub-3940256099942544/1033173712"
const BANNER_UNIT_ID := "ca-app-pub-3940256099942544/6300978111"

const RELOAD_DELAY := 30.0   # сек до повторної спроби, якщо ролик не завантажився

const MOCK_REWARDED_SEC := 3
const MOCK_INTERSTITIAL_SEC := 2
const MOCK_BANNER_HEIGHT := 60

var _is_real := false
var _rewarded_ad: RewardedAd
var _interstitial_ad: InterstitialAd
var _rewarded_loading := false
var _interstitial_loading := false
var _banner: AdView
var _mock_layer: CanvasLayer
var _mock_banner: Control

func _ready() -> void:
	_is_real = Engine.has_singleton("PoingGodotAdMob")
	if not _is_real:
		# Шар поверх усього й працює на паузі — воскресіння показує
		# рекламу, коли дерево сцени вже зупинене.
		_mock_layer = CanvasLayer.new()
		_mock_layer.layer = 100
		_mock_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_mock_layer)
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_load_rewarded()
		_load_interstitial()
	MobileAds.initialize(listener)

## Показує rewarded-відео. on_reward — гравець додивився до кінця;
## on_skipped — закрив достроково або ролик ще не завантажився.
## remove_ads на rewarded свідомо не впливає (розділ 8 ТЗ): платник має
## й далі могти добровільно дивитись ролики за нагороду.
func show_rewarded_ad(on_reward: Callable, on_skipped: Callable = Callable()) -> void:
	if not _is_real:
		_show_mock_fullscreen(true, on_reward, on_skipped)
		return
	if _rewarded_ad == null:
		_load_rewarded()
		if on_skipped.is_valid():
			on_skipped.call()
		return

	var ad := _rewarded_ad
	_rewarded_ad = null
	# Словник, а не bool: лямбди GDScript захоплюють локальні змінні за
	# значенням, тож присвоєння bool всередині лямбди назовні не видно.
	var state := {"earned": false}

	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_load_rewarded()
		# Нагороду віддаємо лише після закриття ролика, а не в момент
		# on_user_earned_reward — інакше UI гри міняється під рекламою.
		if state.earned:
			on_reward.call()
		elif on_skipped.is_valid():
			on_skipped.call()
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		ad.destroy()
		_load_rewarded()
		if on_skipped.is_valid():
			on_skipped.call()

	var reward_listener := OnUserEarnedRewardListener.new()
	reward_listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		state.earned = true
	ad.show(reward_listener)

## Показує interstitial, якщо він завантажений. Коли саме показувати,
## вирішує виклик (GameState.is_interstitial_due) — тут лише сам показ.
func show_interstitial() -> void:
	if GameState.ads_removed:
		return
	if not _is_real:
		GameState.mark_interstitial_shown()
		_show_mock_fullscreen(false, Callable(), Callable())
		return
	if _interstitial_ad == null:
		return
	var ad := _interstitial_ad
	_interstitial_ad = null
	GameState.mark_interstitial_shown()
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_load_interstitial()
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		ad.destroy()
		_load_interstitial()
	ad.show()

## Банер знизу екрана. Висота в пікселях приходить сигналом
## banner_height_changed, щоб екран міг відсунути свої кнопки й банер
## їх не перекривав.
func show_banner() -> void:
	if GameState.ads_removed:
		return
	if not _is_real:
		_show_mock_banner()
		return
	if _banner != null:
		return
	var size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_banner = AdView.new(BANNER_UNIT_ID, size, AdPosition.BOTTOM)
	var listener := AdListener.new()
	listener.on_ad_loaded = func() -> void:
		if _banner != null:
			banner_height_changed.emit(_banner.get_height_in_pixels())
	_banner.ad_listener = listener
	_banner.load_ad(AdRequest.new())

func hide_banner() -> void:
	if _mock_banner != null:
		_mock_banner.queue_free()
		_mock_banner = null
		banner_height_changed.emit(0)
	if _banner == null:
		return
	_banner.destroy()
	_banner = null
	banner_height_changed.emit(0)

## Імітація повноекранної реклами на ПК. Rewarded: дочекатись відліку й
## забрати нагороду або закрити раніше (= on_skipped, як на телефоні).
## Interstitial: кнопка "Закрити" стає активною після відліку.
func _show_mock_fullscreen(is_rewarded: bool, on_reward: Callable, on_skipped: Callable) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.08, 0.08, 0.12, 0.95)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mock_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = "ТЕСТОВА РЕКЛАМА\n(%s)" % ("за нагороду" if is_rewarded else "між ранами")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Заглушка на ПК — на телефоні тут справжній ролик"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	box.add_child(hint)

	var countdown := Label.new()
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.add_theme_font_size_override("font_size", 40)
	box.add_child(countdown)

	var reward_button := Button.new()
	reward_button.text = "Отримати нагороду"
	reward_button.custom_minimum_size = Vector2(280, 52)
	reward_button.visible = false
	box.add_child(reward_button)

	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(280, 52)
	box.add_child(close_button)

	if is_rewarded:
		close_button.text = "Закрити (без нагороди)"
		# Словник, бо лямбди захоплюють bool за значенням. Гарантує, що
		# нагорода/відмова спрацює рівно один раз, хоч би скільки натискань.
		var state := {"finished": false}
		reward_button.pressed.connect(func() -> void:
			if state.finished:
				return
			state.finished = true
			overlay.queue_free()
			on_reward.call())
		close_button.pressed.connect(func() -> void:
			if state.finished:
				return
			state.finished = true
			overlay.queue_free()
			if on_skipped.is_valid():
				on_skipped.call())
	else:
		close_button.text = "Закрити"
		close_button.disabled = true
		close_button.pressed.connect(overlay.queue_free)

	var seconds := MOCK_REWARDED_SEC if is_rewarded else MOCK_INTERSTITIAL_SEC
	for i in range(seconds, 0, -1):
		countdown.text = str(i)
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(overlay) or overlay.is_queued_for_deletion():
			return
	countdown.text = ""
	if is_rewarded:
		reward_button.visible = true
	else:
		close_button.disabled = false

func _show_mock_banner() -> void:
	if _mock_banner != null:
		return
	var banner := ColorRect.new()
	banner.color = Color(0.2, 0.2, 0.28, 1)
	banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	banner.offset_top = -MOCK_BANNER_HEIGHT
	banner.offset_bottom = 0
	_mock_layer.add_child(banner)

	var label := Label.new()
	label.text = "ТЕСТОВИЙ БАНЕР (заглушка на ПК)"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_child(label)

	_mock_banner = banner
	banner_height_changed.emit(MOCK_BANNER_HEIGHT)

func _load_rewarded() -> void:
	if _rewarded_loading or _rewarded_ad != null:
		return
	_rewarded_loading = true
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded_loading = false
		_rewarded_ad = ad
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_rewarded_loading = false
		get_tree().create_timer(RELOAD_DELAY).timeout.connect(_load_rewarded)
	RewardedAdLoader.new().load(REWARDED_UNIT_ID, AdRequest.new(), callback)

func _load_interstitial() -> void:
	if _interstitial_loading or _interstitial_ad != null or GameState.ads_removed:
		return
	_interstitial_loading = true
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial_loading = false
		_interstitial_ad = ad
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_interstitial_loading = false
		get_tree().create_timer(RELOAD_DELAY).timeout.connect(_load_interstitial)
	InterstitialAdLoader.new().load(INTERSTITIAL_UNIT_ID, AdRequest.new(), callback)
