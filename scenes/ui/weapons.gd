extends Control

## Арсенал обраного героя. Кожна зброя — картка: місце під картинку
## (WeaponIcon), назва, як саме вона б'є, головні числа й дія (купити,
## спорядити або "вже в руках").
##
## У кожного героя свій набір: сокира вартової не з'являється в жриці.
## Спорядженою зброєю герой б'ється в наступному рані
## (GameState.get_equipped_weapon_id -> run.gd -> Hero.equip_weapon).

const WEAPON_ICON_SCRIPT := preload("res://scenes/ui/weapon_icon.gd")
const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")

const ARCHETYPE_HINTS := {
	"projectile": "Постріл",
	"aoe_projectile": "Вибух по площі",
	"cone": "Конус полум'я",
	"melee_arc": "Ближній замах",
	"chain": "Ланцюг блискавки",
	"orbit_storm": "Вихор навколо себе",
	"ground_zone": "Зона на землі",
}

const STATUS_HINTS := {
	&"poison": "отрута",
	&"burn": "підпал",
	&"slow": "сповільнення",
	&"mark": "мітка",
}

@onready var hero_label: Label = $VBoxContainer/HeroLabel
@onready var gems_label: Label = $VBoxContainer/GemsLabel
@onready var rows_container: VBoxContainer = $VBoxContainer/ScrollContainer/RowsContainer

var _hero_id: StringName

var _preview: ModelPreview
var _preview_note: Label

## Над списком — 3D-вітрина спорядженої зброї: видно, що саме герой
## візьме в руку. Немає моделі — показуємо тимчасову й пишемо про це.
func _build_preview() -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, 190)
	_preview = MODEL_PREVIEW_SCRIPT.new()
	_preview.custom_minimum_size = Vector2(0, 160)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(_preview)
	_preview_note = Label.new()
	_preview_note.text = "Тимчасова модель зброї — справжню підключимо пізніше"
	_preview_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_note.add_theme_font_size_override("font_size", 13)
	_preview_note.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	holder.add_child(_preview_note)
	var column: VBoxContainer = $VBoxContainer
	column.add_child(holder)
	column.move_child(holder, 3)

func _ready() -> void:
	_build_preview()
	_hero_id = GameState.selected_hero_id
	hero_label.text = "Арсенал: %s" % HeroPool.get_def(_hero_id).title
	_rebuild()

func _show_equipped() -> void:
	var equipped := GameState.get_equipped_weapon_id(GameState.selected_hero_id)
	var def := WeaponPool.get_def(equipped)
	if def != null and _preview != null:
		_preview_note.visible = _preview.show_weapon(def)

func _rebuild() -> void:
	_show_equipped()
	gems_label.text = "Геми: %d        Золото: %d" % [GameState.gems, GameState.gold]
	for child in rows_container.get_children():
		child.queue_free()
	var equipped := GameState.get_equipped_weapon_id(_hero_id)
	for def in WeaponPool.get_for_hero(_hero_id):
		rows_container.add_child(_build_card(def, equipped))

func _build_card(def: WeaponDef, equipped_id: StringName) -> Control:
	var owned := GameState.is_weapon_owned(def.id)
	var card := PanelContainer.new()
	# Споряджену зброю підсвічуємо рамкою її ж кольору — видно з першого погляду.
	if equipped_id == def.id:
		card.add_theme_stylebox_override("panel", UiTheme.make_box(UiTheme.PANEL_LIGHT, 14, 3, def.color))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	# Є готова картинка (assets/ui/icons/weapons/<id>.png) — беремо її,
	# інакше малюємо фігуру за архетипом зброї.
	var picture := ArtSlots.weapon_icon(def.id, def.icon)
	if picture != null:
		var image := TextureRect.new()
		image.texture = picture
		image.custom_minimum_size = Vector2(96, 96)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return image
	var icon: Control = WEAPON_ICON_SCRIPT.new()
	icon.setup(def, owned)
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var title := Label.new()
	title.text = def.title
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", def.color if owned else UiTheme.TEXT_DIM)
	info.add_child(title)

	var kind := Label.new()
	kind.text = ARCHETYPE_HINTS.get(def.archetype, "")
	kind.add_theme_font_size_override("font_size", 14)
	kind.add_theme_color_override("font_color", UiTheme.GEM)
	info.add_child(kind)

	var stats := Label.new()
	stats.text = _build_stats_text(def)
	stats.add_theme_font_size_override("font_size", 14)
	stats.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	info.add_child(stats)

	var description := Label.new()
	description.text = def.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(360, 0)
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", UiTheme.TEXT)
	info.add_child(description)

	row.add_child(_build_action_button(def, equipped_id, owned))
	return card

## Головні числа зброї людською мовою: скільки б'є, як часто і що
## лишає на ворогові.
func _build_stats_text(def: WeaponDef) -> String:
	var parts: Array[String] = ["Шкода %d" % int(def.damage)]
	if def.cooldown > 0.0:
		parts.append("раз на %.1f с" % def.cooldown)
	if def.shots > 1:
		parts.append("%d снаряди" % def.shots)
	if def.pierce > 0:
		parts.append("пробиває %d" % def.pierce)
	if def.status != &"" and STATUS_HINTS.has(def.status):
		parts.append(STATUS_HINTS[def.status])
	return "   •   ".join(parts)

func _build_action_button(def: WeaponDef, equipped_id: StringName, owned: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(170, 56)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if equipped_id == def.id:
		button.text = "У руках"
		button.disabled = true
	elif owned:
		button.text = "Спорядити"
		button.pressed.connect(_on_equip_pressed.bind(def.id))
	else:
		button.text = "%d гемів" % def.cost_gems
		button.disabled = GameState.gems < def.cost_gems
		button.pressed.connect(_on_buy_pressed.bind(def.id))
	return button

## Куплену зброю одразу вдягаємо — гравець хотів саме її, зайвий
## другий клік нічого не додає.
func _on_buy_pressed(id: StringName) -> void:
	if GameState.buy_weapon(id):
		AudioManager.play(&"purchase", 0.0)
		GameState.equip_weapon(_hero_id, id)
	_rebuild()

func _on_equip_pressed(id: StringName) -> void:
	GameState.equip_weapon(_hero_id, id)
	_rebuild()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
