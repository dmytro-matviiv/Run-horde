extends Control

## Бойові кнопки в правому нижньому куті, під великим пальцем:
##   велика  — удар (утримання б'є серією, поки є ціль);
##   ліворуч — перекат;
##   вище    — здібності ГЕРОЯ, скільки їх у нього є.
##
## Кнопки здібностей будуються з того, кого обрав гравець: у вартової це
## "Вихор" і "Лють", у руновода — "Рунна Нова". Код кнопок про героїв
## нічого не знає — усе бере з player.get_skills().
##
## Права половина екрана й далі крутить камеру — кнопки забирають собі
## лише дотики, що припали точно на них.

const ATTACK_RADIUS := 64.0
const SMALL_RADIUS := 42.0
const MARGIN := 34.0

var _player: Node
var _attack: CombatButton
var _dodge: CombatButton
var _skill_buttons: Array[CombatButton] = []
var _skills: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)

func setup(player: Node) -> void:
	_player = player
	# Зі стволом у руках кнопка удару стає кнопкою вогню, з посохом —
	# кнопкою чар.
	var ranged: bool = _player.is_ranged()
	var icon := "gun" if ranged else "attack"
	if _player.is_caster():
		icon = {"rune": "book", "cards": "cards"}.get(_player.weapon_def.spell, "staff")
	_attack = _make_button(icon, ATTACK_RADIUS, "", Color(0.98, 0.72, 0.25))
	_dodge = _make_button("dodge", SMALL_RADIUS, "Перекат", Color(0.6, 0.9, 1.0))
	_attack.pressed_down.connect(func() -> void: _player.set_attack_held(true))
	_attack.released.connect(func() -> void: _player.set_attack_held(false))
	_dodge.pressed_down.connect(func() -> void: _player.dodge())

	_skills = _player.get_skills()
	for index in _skills.size():
		var skill: HeroSkill3D = _skills[index]
		var button := _make_button(skill.icon_kind, SMALL_RADIUS, skill.title, skill.color)
		button.icon_texture = ArtSlots.skill_icon(skill.id)
		button.pressed_down.connect(func() -> void: _player.use_skill(index))
		_skill_buttons.append(button)
	_layout()
	# Розмір екрана остаточно відомий лише після першого кадру розкладки.
	_layout.call_deferred()

func _make_button(icon_kind: String, radius: float, caption: String, accent: Color) -> CombatButton:
	var button := CombatButton.new()
	button.icon_kind = icon_kind
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
	# Здібності лягають дугою над кнопкою удару — скільки б їх не було.
	for index in _skill_buttons.size():
		var angle := deg_to_rad(-118.0 + 46.0 * index)
		var distance := ATTACK_RADIUS + SMALL_RADIUS + 34.0
		_place(_skill_buttons[index], attack_center + Vector2(cos(angle), sin(angle)) * distance)

func _place(button: CombatButton, center: Vector2) -> void:
	button.position = center - button.size * 0.5

func _process(_delta: float) -> void:
	if _player == null:
		return
	# Зі стволом кнопка удару показує набої, а під час перезарядки —
	# скільки лишилось.
	if _player.is_ranged():
		var ammo: Vector2i = _player.get_ammo()
		var reload: Vector2 = _player.get_reload()
		if reload.x > 0.0:
			_attack.inner_text = "перезарядка"
			_attack.cooldown_seconds = 0.0
			_attack.cooldown_ratio = reload.x / maxf(reload.y, 0.01)
		else:
			_attack.inner_text = "%d / %d" % [ammo.x, ammo.y]
			_attack.cooldown_ratio = 0.0
		_attack.queue_redraw()

	var dodge: Vector2 = _player.get_dodge_cooldown()
	_dodge.cooldown_seconds = dodge.x
	_dodge.cooldown_ratio = dodge.x / dodge.y if dodge.y > 0.0 else 0.0
	for index in _skill_buttons.size():
		var skill: HeroSkill3D = _skills[index]
		var button := _skill_buttons[index]
		var cooldown: Vector2 = skill.get_cooldown()
		button.cooldown_seconds = cooldown.x
		button.cooldown_ratio = cooldown.x / cooldown.y if cooldown.y > 0.0 else 0.0
		button.charge = skill.get_charge(_player)
