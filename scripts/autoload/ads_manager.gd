extends Node

## Обгортка над рекламою. Якщо в збірці є нативний AdMob-плагін (Android)
## — показує справжню рекламу; інакше (редактор, ПК) працює заглушка, щоб
## гру можна було тестувати без мобільного SDK. Решта гри викликає лише
## публічні методи нижче й не знає, яка гілка активна.
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

var _is_real := false
var _rewarded_ad: RewardedAd
var _interstitial_ad: InterstitialAd
var _rewarded_loading := false
var _interstitial_loading := false
var _banner: AdView

func _ready() -> void:
	_is_real = Engine.has_singleton("PoingGodotAdMob")
	if not _is_real:
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
		on_reward.call()
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
	if not _is_real or GameState.ads_removed or _interstitial_ad == null:
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
	if not _is_real or GameState.ads_removed or _banner != null:
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
	if _banner == null:
		return
	_banner.destroy()
	_banner = null
	banner_height_changed.emit(0)

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
