extends Control

## Головне меню: точка повернення між ранами. "Грати" веде в ран,
## "Апгрейди" — на екран мета-прогресії (тут гравець витрачає золото
## між ранами — наша "база"), "Магазин" — геми, обмін і стартові набори.
## Тут же показуємо офлайн-золото (GameState.pending_offline_gold) і
## скриньку за таймером.

const OFFLINE_REWARD_SCENE := preload("res://scenes/ui/offline_reward.tscn")

@onready var gold_label: Label = $TopBar/GoldLabel
@onready var gems_label: Label = $TopBar/GemsLabel
@onready var hero_label: Label = $CenterContainer/VBoxContainer/HeroLabel
@onready var chest_button: Button = $CenterContainer/VBoxContainer/ChestButton
@onready var graphics_button: Button = $CenterContainer/VBoxContainer/Row3/GraphicsButton
@onready var fps_button: Button = $CenterContainer/VBoxContainer/Row3/FpsButton

const CHEST_MESSAGE_SEC := 3.0

var _chest_refresh_timer := 0.0
var _chest_message_left := 0.0   # поки > 0, щосекундне оновлення не затирає повідомлення

## Кнопки меню мають місце під іконку: поклади
## res://assets/ui/icons/menu/<назва>.png — і вона з'явиться сама.
const MENU_ICONS := {
	"PlayButton": "play",
	"Row1/HeroesButton": "heroes",
	"Row1/WeaponsButton": "weapons",
	"Row2/UpgradesButton": "talents",
	"Row2/ShopButton": "shop",
	"ChestButton": "chest",
}

func _apply_menu_icons() -> void:
	for path: String in MENU_ICONS:
		var button := get_node_or_null("CenterContainer/VBoxContainer/" + path) as Button
		if button == null:
			continue
		var name: String = MENU_ICONS[path]
		button.icon = ArtSlots.icon_or_placeholder(ArtSlots.menu_icon(name), UiTheme.ACCENT, 48)
		button.expand_icon = true
		button.tooltip_text = "Іконка: assets/ui/icons/menu/%s.png" % name

func _ready() -> void:
	_apply_menu_icons()
	_update_gold_label()
	_update_chest_button()
	_update_graphics_buttons()
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
	gems_label.text = "Геми: %d" % GameState.gems
	# Видно одразу, ким і чим підеш у бій — щоб не лізти в меню перевіряти.
	var hero := HeroPool.get_def(GameState.selected_hero_id)
	var weapon := WeaponPool.get_def(GameState.get_equipped_weapon_id(hero.id))
	hero_label.text = "%s  •  %s" % [hero.title, weapon.title]

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

## "Грати" веде на базу героя — звідти він сам піде в данж через портал.
## Старий 2D-ран лишається в проєкті, поки бій не переїде в 3D.
func _on_play_pressed() -> void:
	SceneLoader.change_scene("res://scenes/world/base_island.tscn", "База")

func _on_upgrades_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/meta_upgrades.tscn")

func _on_heroes_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/heroes.tscn")

func _on_weapons_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/weapons.tscn")

func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")

func _on_chest_pressed() -> void:
	chest_button.disabled = true
	AdsManager.show_rewarded_ad(_on_chest_ad_reward, _on_chest_ad_skipped)

func _on_chest_ad_reward() -> void:
	GameState.claim_chest_reward()
	_update_gold_label()
	_update_chest_button()

func _on_chest_ad_skipped() -> void:
	chest_button.text = "Нагороду не отримано"
	_chest_message_left = CHEST_MESSAGE_SEC

## Графіка по колу: Авто -> Низька -> Середня -> Висока -> Авто.
## "Авто" — гра сама підбирає якість під телефон і тримає кадри рівними.
func _on_graphics_pressed() -> void:
	if PerfSettings.auto_quality:
		PerfSettings.set_user_choice(PerfSettings.Quality.LOW)
	elif PerfSettings.quality < PerfSettings.Quality.HIGH:
		PerfSettings.set_user_choice(PerfSettings.quality + 1)
	else:
		PerfSettings.set_user_choice(-1)
	_update_graphics_buttons()

## Лічильник кадрів у кутку екрана — щоб перевірити на телефоні, як
## насправді йде гра.
func _on_fps_pressed() -> void:
	PerfSettings.set_show_fps(not PerfSettings.show_fps)
	_update_graphics_buttons()

func _update_graphics_buttons() -> void:
	if PerfSettings.auto_quality:
		graphics_button.text = "Графіка: Авто (%s)" % PerfSettings.get_quality_title().to_lower()
	else:
		graphics_button.text = "Графіка: %s" % PerfSettings.get_quality_title()
	fps_button.text = "FPS: так" if PerfSettings.show_fps else "FPS: ні"
