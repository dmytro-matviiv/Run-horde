# -*- coding: utf-8 -*-
import os
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:70])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


SHEET_FIELDS = '''
@export_group("Спрайт-лист (куплений набір)")
## Якщо тут лежить аркуш кадрів — персонаж анімується ПОКАДРОВО, як у
## справжніх іграх, а не лише процедурним похитуванням. Порожньо —
## лишається одна картинка й процедурна анімація.
@export var sheet: Texture2D
@export var sheet_hframes: int = 1
@export var sheet_vframes: int = 1
@export var sheet_fps: float = 12.0
## Діапазони кадрів (від, до) для кожного стану. (0, 0) = стану немає.
@export var clip_idle: Vector2i = Vector2i.ZERO
@export var clip_walk: Vector2i = Vector2i.ZERO
@export var clip_attack: Vector2i = Vector2i.ZERO
@export var clip_death: Vector2i = Vector2i.ZERO
'''

patch('data/heroes/hero_def.gd', [
    ("""## Класове вміння (AbilityPool.ABILITIES)""", SHEET_FIELDS + """
## Класове вміння (AbilityPool.ABILITIES)"""),
])

patch('data/enemies/enemy_def.gd', [
    ("""@export_enum("melee", "ranged") var attack_type: String = "melee\"""",
     SHEET_FIELDS + """
@export_enum("melee", "ranged") var attack_type: String = "melee\""""),
])

patch('data/weapons/weapon_def.gd', [
    ("""@export_group("Статус-ефект")""",
     """@export_group("Ефекти")
## Спалах у момент удару (розсічення сокири, вибух метеора). Беруться
## з куплених/безкоштовних наборів ефектів — VfxDef описує аркуш кадрів.
@export var swing_vfx: VfxDef
@export var hit_vfx: VfxDef

@export_group("Статус-ефект")"""),
])

# --- аніматор: покадрова анімація, коли є аркуш ---
patch('scripts/systems/sprite_animator.gd', [
    ("""var _sprite: Sprite2D
var _front: Texture2D
var _back: Texture2D""",
     """var _sprite: Sprite2D
var _front: Texture2D
var _back: Texture2D

# Покадрова анімація з купленого аркуша. Поки її немає, працює лише
# процедурна (підстрибування, дихання) — гра виглядає прийнятно і без
# придбаного арту.
var _has_sheet := false
var _sheet_fps := 12.0
var _clips: Dictionary = {}
var _clip_time := 0.0
var _current_clip: StringName = &\"\""""),
    ("""## Напрямок руху (нульовий — стоїмо). Викликає власник щокадру.""",
     """## Вмикає покадрову анімацію: аркуш кадрів і діапазони (від, до) для
## станів idle/walk/attack/death. Викликається після setup().
func setup_frames(sheet: Texture2D, hframes: int, vframes: int, fps: float, clips: Dictionary) -> void:
	if sheet == null or _sprite == null:
		return
	_has_sheet = true
	_sheet_fps = fps
	_clips = clips
	_sprite.texture = sheet
	_sprite.hframes = maxi(hframes, 1)
	_sprite.vframes = maxi(vframes, 1)
	_current_clip = &\"\"

func has_frame_animation() -> bool:
	return _has_sheet

## Який стан показувати зараз: смерть > удар > хода > спокій.
func _wanted_clip() -> StringName:
	if _death_left > 0.0 and _clips.has(&"death"):
		return &"death"
	if _attack_left > 0.0 and _clips.has(&"attack"):
		return &"attack"
	if _move_direction.length() > 0.1 and _clips.has(&"walk"):
		return &"walk"
	return &"idle"

func _process_frames(delta: float) -> void:
	var clip := _wanted_clip()
	if not _clips.has(clip):
		return
	if clip != _current_clip:
		_current_clip = clip
		_clip_time = 0.0
	_clip_time += delta
	var range_value: Vector2i = _clips[clip]
	var frames := maxi(range_value.y - range_value.x + 1, 1)
	var index := int(_clip_time * _sheet_fps)
	# Удар і смерть грають один раз і застигають на останньому кадрі,
	# хода й спокій крутяться по колу.
	if clip == &"attack" or clip == &"death":
		index = mini(index, frames - 1)
	else:
		index = index % frames
	_sprite.frame = range_value.x + index

## Напрямок руху (нульовий — стоїмо). Викликає власник щокадру."""),
    ("""	var speed := _move_direction.length()
	var offset := Vector2.ZERO
	var scale_factor := Vector2.ONE
	var rotation_value := 0.0

	if speed > 0.1:""",
     """	if _has_sheet:
		_process_frames(delta)

	var speed := _move_direction.length()
	var offset := Vector2.ZERO
	var scale_factor := Vector2.ONE
	var rotation_value := 0.0

	# Якщо кроки вже намальовані на аркуші, процедурне підстрибування
	# лише заважало б — лишаємо дзеркалення, ривок і спалах.
	if _has_sheet:
		pass
	elif speed > 0.1:"""),
])
print('done')
