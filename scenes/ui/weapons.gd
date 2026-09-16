extends Control

## Арсенал обраного героя: у кожного героя свій набір зброї (стартова
## безкоштовна + три за геми). Тут її купують і споряджають — саме
## спорядженою зброєю герой б'ється в наступному рані
## (GameState.get_equipped_weapon_id → run.gd → Hero.equip_weapon).

const ARCHETYPE_HINTS := {
	"projectile": "Постріл",
	"aoe_projectile": "Вибух по площі",
	"cone": "Конус полум'я",
	"melee_arc": "Ближній замах",
	"chain": "Ланцюг блискавки",
	"orbit_storm": "Вихор навколо себе",
	"ground_zone": "Зона на землі",
}

@onready var hero_label: Label = $VBoxContainer/HeroLabel
@onready var gems_label: Label = $VBoxContainer/GemsLabel
@onready var rows_container: VBoxContainer = $VBoxContainer/ScrollContainer/RowsContainer

var _hero_id: StringName

func _ready() -> void:
	_hero_id = GameState.selected_hero_id
	hero_label.text = "Арсенал: %s" % HeroPool.get_def(_hero_id).title
	_rebuild()

func _rebuild() -> void:
	gems_label.text = "Геми: %d    Золото: %d" % [GameState.gems, GameState.gold]
	for child in rows_container.get_children():
		child.queue_free()
	var equipped := GameState.get_equipped_weapon_id(_hero_id)
	for def in WeaponPool.get_for_hero(_hero_id):
		rows_container.add_child(_build_row(def, equipped))

func _build_row(def: WeaponDef, equipped_id: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var info := Label.new()
	info.custom_minimum_size = Vector2(430, 0)
	info.text = "%s — %s\n%s" % [def.title, ARCHETYPE_HINTS.get(def.archetype, ""), def.description]
	info.add_theme_color_override("font_color", def.color)
	row.add_child(info)

	var button := Button.new()
	button.custom_minimum_size = Vector2(160, 48)
	if equipped_id == def.id:
		button.text = "Споряджено"
		button.disabled = true
	elif GameState.is_weapon_owned(def.id):
		button.text = "Спорядити"
		button.pressed.connect(_on_equip_pressed.bind(def.id))
	else:
		button.text = "%d гемів" % def.cost_gems
		button.disabled = GameState.gems < def.cost_gems
		button.pressed.connect(_on_buy_pressed.bind(def.id))
	row.add_child(button)
	return row

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
