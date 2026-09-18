extends Control

## Бойові кнопки в правому нижньому куті, під великим пальцем:
##   велика  — удар (утримання б'є серією, поки є ціль);
##   ліворуч — перекат;
##   вище    — вихор, з таймером перезарядки.
##
## Права половина екрана й далі крутить камеру — кнопки забирають собі
## лише дотики, що припали точно на них.

const ATTACK_RADIUS := 64.0
const SMALL_RADIUS := 42.0
const MARGIN := 34.0

var _player: Node
var _attack: CombatButton
var _dodge: CombatButton
var _skill: CombatButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)

func setup(player: Node) -> void:
	_player = player
	_attack = _make_button(CombatButton.Icon.ATTACK, ATTACK_RADIUS, "", Color(0.98, 0.72, 0.25))
	_dodge = _make_button(CombatButton.Icon.DODGE, SMALL_RADIUS, "Перекат", Color(0.6, 0.9, 1.0))
	_skill = _make_button(CombatButton.Icon.SKILL, SMALL_RADIUS, "Вихор", Color(0.35, 0.95, 1.0))
	_attack.pressed_down.connect(func() -> void: _player.set_attack_held(true))
	_attack.released.connect(func() -> void: _player.set_attack_held(false))
	_dodge.pressed_down.connect(func() -> void: _player.dodge())
	_skill.pressed_down.connect(func() -> void: _player.use_skill())
	_layout()
	# Розмір екрана остаточно відомий лише після першого кадру розкладки.
	_layout.call_deferred()

func _make_button(icon: CombatButton.Icon, radius: float, caption: String, accent: Color) -> CombatButton:
	var button := CombatButton.new()
	button.icon = icon
	button.radius = radius
	button.caption = caption
	button.accent = accent
	add_child(button)
	return button

func _layout() -> void:
	if _attack == null:
		return
	# Кнопки ставимо від правого нижнього кута ЕКРАНА, а не від власного
	# розміру вузла: той на старті ще може бути нульовим.
	var area := get_viewport_rect().size
	var attack_center := area - Vector2(MARGIN + ATTACK_RADIUS, MARGIN + ATTACK_RADIUS + 10.0)
	_place(_attack, attack_center)
	_place(_dodge, attack_center + Vector2(-ATTACK_RADIUS - SMALL_RADIUS - 26.0, 18.0))
	_place(_skill, attack_center + Vector2(-ATTACK_RADIUS * 0.55, -ATTACK_RADIUS - SMALL_RADIUS - 30.0))

func _place(button: CombatButton, center: Vector2) -> void:
	button.position = center - button.size * 0.5

func _process(_delta: float) -> void:
	if _player == null:
		return
	var skill: Vector2 = _player.get_skill_cooldown()
	_skill.cooldown_seconds = skill.x
	_skill.cooldown_ratio = skill.x / skill.y if skill.y > 0.0 else 0.0
	var dodge: Vector2 = _player.get_dodge_cooldown()
	_dodge.cooldown_seconds = dodge.x
	_dodge.cooldown_ratio = dodge.x / dodge.y if dodge.y > 0.0 else 0.0
