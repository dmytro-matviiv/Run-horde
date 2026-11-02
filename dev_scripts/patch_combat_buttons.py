# -*- coding: utf-8 -*-
# Кнопки бою будуються зі здібностей героя; заготовка під іконки-картинки.
import os
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:80])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


patch('scenes/ui/combat_button.gd', [
    ('''## Уміє показувати перезарядку: темний сектор, що зменшується, і секунди.''',
     '''## Уміє показувати перезарядку (темний сектор і секунди) та шкалу
## накопичення — як "Лють" вартової, що заряджається від ударів.
##
## Якщо в res://assets/ui/icons/skills/<id>.png лежить картинка, кнопка
## бере її; поки немає — малює просту фігуру за назвою (меч, стрілки,
## вихор, нова, вогонь, дим).'''),
    ('''enum Icon {ATTACK, DODGE, SKILL}

var radius := 60.0
var icon: Icon = Icon.ATTACK
var caption := ""
var accent := Color(0.98, 0.72, 0.25)''',
     '''var radius := 60.0
## Яку фігуру малювати: attack, dodge, whirl, dash, nova, fire, smoke.
var icon_kind := "attack"
## Готова картинка (якщо художник уже дав) — малюється замість фігури.
var icon_texture: Texture2D
var caption := ""
var accent := Color(0.98, 0.72, 0.25)

## Шкала накопичення 0..1 (лють, заряд) або -1, якщо її немає.
var charge := -1.0:
	set(value):
		if not is_equal_approx(value, charge):
			charge = value
			queue_redraw()'''),
    ('''	var is_ready := cooldown_ratio <= 0.0''',
     '''	var is_ready := cooldown_ratio <= 0.0 and (charge < 0.0 or charge >= 1.0)'''),
    ('''	var glyph_color := Color(1, 1, 1, 0.95 if is_ready else 0.45)
	match icon:
		Icon.ATTACK:
			_draw_sword(center, radius * 0.5, glyph_color)
		Icon.DODGE:
			_draw_chevrons(center, radius * 0.42, glyph_color)
		Icon.SKILL:
			_draw_whirl(center, radius * 0.45, glyph_color)''',
     '''	var glyph_color := Color(1, 1, 1, 0.95 if is_ready else 0.45)
	if icon_texture != null:
		var side := radius * 1.1
		draw_texture_rect(icon_texture, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)),
			false, Color(1, 1, 1, 0.95 if is_ready else 0.5))
	else:
		match icon_kind:
			"attack":
				_draw_sword(center, radius * 0.5, glyph_color)
			"dodge":
				_draw_chevrons(center, radius * 0.42, glyph_color)
			"dash":
				_draw_dash(center, radius * 0.45, glyph_color)
			"nova":
				_draw_nova(center, radius * 0.45, glyph_color)
			"fire":
				_draw_fire(center, radius * 0.45, glyph_color)
			"smoke":
				_draw_smoke(center, radius * 0.45, glyph_color)
			_:
				_draw_whirl(center, radius * 0.45, glyph_color)

	# Шкала накопичення: кільце наповнюється знизу за годинниковою.
	if charge >= 0.0 and charge < 1.0:
		var points := PackedVector2Array([center])
		var steps := 28
		for i in steps + 1:
			var angle := -PI * 0.5 + TAU * (1.0 - charge) * float(i) / steps
			points.append(center + Vector2(cos(angle), sin(angle)) * (radius - 3.0))
		draw_colored_polygon(points, Color(0, 0, 0, 0.5))
	elif charge >= 1.0:
		# Готово — кнопка світиться.
		draw_circle(center, radius + 3.0, Color(accent, 0.35))'''),
    ('''## Три дуги по колу — вихор.''',
     '''## Стріла вперед — ривок.
func _draw_dash(center: Vector2, size_px: float, color: Color) -> void:
	draw_line(center - Vector2(size_px, 0), center + Vector2(size_px * 0.4, 0), color, size_px * 0.25)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(size_px, 0),
		center + Vector2(size_px * 0.2, -size_px * 0.55),
		center + Vector2(size_px * 0.2, size_px * 0.55)]), color)

## Кола, що розходяться, — нова.
func _draw_nova(center: Vector2, size_px: float, color: Color) -> void:
	draw_circle(center, size_px * 0.28, color)
	draw_arc(center, size_px * 0.62, 0.0, TAU, 20, color, size_px * 0.13)
	draw_arc(center, size_px * 0.95, 0.0, TAU, 24, Color(color, color.a * 0.6), size_px * 0.1)

## Язик полум'я.
func _draw_fire(center: Vector2, size_px: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -size_px),
		center + Vector2(size_px * 0.6, size_px * 0.2),
		center + Vector2(0, size_px * 0.9),
		center + Vector2(-size_px * 0.6, size_px * 0.2)]), color)
	draw_circle(center + Vector2(0, size_px * 0.35), size_px * 0.3, Color(1, 1, 1, color.a * 0.7))

## Клуби диму.
func _draw_smoke(center: Vector2, size_px: float, color: Color) -> void:
	draw_circle(center + Vector2(-size_px * 0.4, size_px * 0.15), size_px * 0.45, color)
	draw_circle(center + Vector2(size_px * 0.35, size_px * 0.25), size_px * 0.4, Color(color, color.a * 0.8))
	draw_circle(center + Vector2(0, -size_px * 0.3), size_px * 0.5, Color(color, color.a * 0.6))

## Три дуги по колу — вихор.'''),
])

patch('scenes/ui/combat_buttons.gd', [
    ('''## Бойові кнопки в правому нижньому куті, під великим пальцем:
##   велика  — удар (утримання б'є серією, поки є ціль);
##   ліворуч — перекат;
##   вище    — вихор, з таймером перезарядки.''',
     '''## Бойові кнопки в правому нижньому куті, під великим пальцем:
##   велика  — удар (утримання б'є серією, поки є ціль);
##   ліворуч — перекат;
##   вище    — здібності ГЕРОЯ, скільки їх у нього є.
##
## Кнопки здібностей будуються з того, кого обрав гравець: у вартової це
## "Вихор" і "Лють", у руновода — "Рунна Нова". Код кнопок про героїв
## нічого не знає — усе бере з player.get_skills().'''),
    ('''var _player: Node
var _attack: CombatButton
var _dodge: CombatButton
var _skill: CombatButton''',
     '''var _player: Node
var _attack: CombatButton
var _dodge: CombatButton
var _skill_buttons: Array[CombatButton] = []
var _skills: Array = []'''),
    ('''	_attack = _make_button(CombatButton.Icon.ATTACK, ATTACK_RADIUS, "", Color(0.98, 0.72, 0.25))
	_dodge = _make_button(CombatButton.Icon.DODGE, SMALL_RADIUS, "Перекат", Color(0.6, 0.9, 1.0))
	_skill = _make_button(CombatButton.Icon.SKILL, SMALL_RADIUS, "Вихор", Color(0.35, 0.95, 1.0))
	_attack.pressed_down.connect(func() -> void: _player.set_attack_held(true))
	_attack.released.connect(func() -> void: _player.set_attack_held(false))
	_dodge.pressed_down.connect(func() -> void: _player.dodge())
	_skill.pressed_down.connect(func() -> void: _player.use_skill())''',
     '''	_attack = _make_button("attack", ATTACK_RADIUS, "", Color(0.98, 0.72, 0.25))
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
		_skill_buttons.append(button)'''),
    ('''func _make_button(icon: CombatButton.Icon, radius: float, caption: String, accent: Color) -> CombatButton:
	var button := CombatButton.new()
	button.icon = icon''',
     '''func _make_button(icon_kind: String, radius: float, caption: String, accent: Color) -> CombatButton:
	var button := CombatButton.new()
	button.icon_kind = icon_kind'''),
    ('''	_place(_attack, attack_center)
	_place(_dodge, attack_center + Vector2(-ATTACK_RADIUS - SMALL_RADIUS - 26.0, 18.0))
	_place(_skill, attack_center + Vector2(-ATTACK_RADIUS * 0.55, -ATTACK_RADIUS - SMALL_RADIUS - 30.0))''',
     '''	_place(_attack, attack_center)
	_place(_dodge, attack_center + Vector2(-ATTACK_RADIUS - SMALL_RADIUS - 26.0, 18.0))
	# Здібності лягають дугою над кнопкою удару — скільки б їх не було.
	for index in _skill_buttons.size():
		var angle := deg_to_rad(-118.0 + 46.0 * index)
		var distance := ATTACK_RADIUS + SMALL_RADIUS + 34.0
		_place(_skill_buttons[index], attack_center + Vector2(cos(angle), sin(angle)) * distance)'''),
    ('''func _process(_delta: float) -> void:
	if _player == null:
		return
	var skill: Vector2 = _player.get_skill_cooldown()
	_skill.cooldown_seconds = skill.x
	_skill.cooldown_ratio = skill.x / skill.y if skill.y > 0.0 else 0.0
	var dodge: Vector2 = _player.get_dodge_cooldown()
	_dodge.cooldown_seconds = dodge.x
	_dodge.cooldown_ratio = dodge.x / dodge.y if dodge.y > 0.0 else 0.0''',
     '''func _process(_delta: float) -> void:
	if _player == null:
		return
	var dodge: Vector2 = _player.get_dodge_cooldown()
	_dodge.cooldown_seconds = dodge.x
	_dodge.cooldown_ratio = dodge.x / dodge.y if dodge.y > 0.0 else 0.0
	for index in _skill_buttons.size():
		var skill: HeroSkill3D = _skills[index]
		var button := _skill_buttons[index]
		var cooldown: Vector2 = skill.get_cooldown()
		button.cooldown_seconds = cooldown.x
		button.cooldown_ratio = cooldown.x / cooldown.y if cooldown.y > 0.0 else 0.0
		button.charge = skill.get_charge(_player)'''),
])
