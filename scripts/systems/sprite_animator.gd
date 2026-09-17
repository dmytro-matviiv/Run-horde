extends Node
class_name SpriteAnimator

## Оживляє один спрайт: крок, дихання на місці, поворот у бік руху,
## замах при атаці, здригання від удару, згасання при смерті.
##
## Зроблено процедурно, а не покадровою мальованою анімацією, свідомо:
## покадрова вимагала б десятків малюнків на кожного героя й ворога в
## кожному напрямку. Тут та сама "жива" картинка рухається за
## математикою — хода з підстрибуванням і нахилом, від чого персонаж
## перестає "їздити по підлозі".
##
## Вигляд спереду/ззаду перемикається двома картинками: йдеш угору —
## видно спину, йдеш униз — обличчя. Якщо картинки спини ще немає,
## лишається та, що є, і нічого не ламається.

const STEP_SPEED := 9.0        # частота кроків
const STEP_HEIGHT := 3.0       # на скільки пікселів підстрибує на кроці
const STEP_SQUASH := 0.06      # присідання під час кроку
const SWAY_ANGLE := 0.07       # похитування корпусом, радіани
const BREATH_SPEED := 2.2
const BREATH_SCALE := 0.02

const ATTACK_TIME := 0.18
const ATTACK_LUNGE := 10.0     # ривок у бік цілі під час удару
const FLASH_TIME := 0.09
const DEATH_TIME := 0.16

var _sprite: Sprite2D
var _front: Texture2D
var _back: Texture2D

# Покадрова анімація з купленого аркуша. Поки її немає, працює лише
# процедурна (підстрибування, дихання) — гра виглядає прийнятно і без
# придбаного арту.
var _has_sheet := false
var _sheet_fps := 12.0
var _clips: Dictionary = {}
## Ті самі стани, але знятi ззаду: на аркуші це просто інші рядки, тож
## "показати спину" — це взяти інший діапазон кадрів, а не іншу картинку.
var _back_clips: Dictionary = {}
var _clip_time := 0.0
var _current_clip: StringName = &""
var _base_scale := Vector2.ONE
var _base_tint := Color.WHITE

var _step_phase := 0.0
var _move_direction := Vector2.ZERO
var _facing_back := false
var _flip := false
## Чи можна взагалі показувати спину. Для героя — так (гравець веде
## його вгору й бачить спину, як у справжніх іграх). Для ворогів — ні:
## вони сходяться до героя з усіх боків, і половина з них ішла б до
## гравця спиною. Вороги завжди обернені обличчям до екрана.
var _back_view_enabled := true

var _attack_left := 0.0
var _attack_aim := Vector2.RIGHT
var _flash_left := 0.0
var _death_left := 0.0

## front/back — картинки спереду й ззаду; back може бути null.
func setup(sprite: Sprite2D, front: Texture2D, back: Texture2D = null) -> void:
	_sprite = sprite
	_front = front
	_back = back
	_base_scale = sprite.scale
	_base_tint = sprite.modulate
	if front != null:
		sprite.texture = front

## Вмикає покадрову анімацію: аркуш кадрів і діапазони (від, до) для
## станів idle/walk/attack/death. Викликається після setup().
func setup_frames(sheet: Texture2D, hframes: int, vframes: int, fps: float, clips: Dictionary, back_clips: Dictionary = {}) -> void:
	if sheet == null or _sprite == null:
		return
	_has_sheet = true
	_sheet_fps = fps
	_clips = clips
	_back_clips = back_clips
	_sprite.texture = sheet
	_sprite.hframes = maxi(hframes, 1)
	_sprite.vframes = maxi(vframes, 1)
	_current_clip = &""

## Вимикає показ спини (див. _back_view_enabled).
func set_back_view_enabled(enabled: bool) -> void:
	_back_view_enabled = enabled
	if not enabled:
		_facing_back = false

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
	# Йде від гравця — беремо кадри, зняті ззаду.
	var source: Dictionary = _back_clips if (_facing_back and _back_clips.has(clip)) else _clips
	var range_value: Vector2i = source[clip]
	var frames := maxi(range_value.y - range_value.x + 1, 1)
	var index := int(_clip_time * _sheet_fps)
	# Удар і смерть грають один раз і застигають на останньому кадрі,
	# хода й спокій крутяться по колу.
	if clip == &"attack" or clip == &"death":
		index = mini(index, frames - 1)
	else:
		index = index % frames
	_sprite.frame = range_value.x + index

## Напрямок руху (нульовий — стоїмо). Викликає власник щокадру.
func set_move_direction(direction: Vector2) -> void:
	_move_direction = direction
	if direction.length() < 0.1:
		return
	# Ліворуч/праворуч — дзеркалимо ту саму картинку; вгору/вниз —
	# міняємо спину на обличчя.
	if absf(direction.x) > 0.25:
		_flip = direction.x < 0.0
	if not _back_view_enabled:
		return
	if direction.y < -0.35:
		_facing_back = true
	elif direction.y > 0.35:
		_facing_back = false

## Замах у бік цілі. Викликається на кожен удар зброї чи ворога.
func play_attack(aim: Vector2) -> void:
	_attack_aim = aim.normalized()
	_attack_left = ATTACK_TIME

## Коротке біле здригання — видно, що удар зарахований.
func play_hit_flash() -> void:
	_flash_left = FLASH_TIME

## Смерть. Якщо в аркуші є намальована смерть — тримаємо ворога на
## екрані рівно стільки, скільки вона триває; інакше коротке стискання.
func play_death() -> void:
	_death_left = DEATH_TIME
	if _has_sheet and _clips.has(&"death"):
		var range_value: Vector2i = _clips[&"death"]
		_death_left = float(range_value.y - range_value.x + 1) / maxf(_sheet_fps, 1.0)

func is_death_finished() -> bool:
	return _death_left <= 0.0

## Колір, до якого все повертається: ним статус-ефекти підсвічують ворога.
func set_base_tint(tint: Color) -> void:
	_base_tint = tint

## Повертає все у вихідний стан — потрібно пулу, бо той самий вузол
## завтра грає іншого ворога.
func reset() -> void:
	_step_phase = 0.0
	_move_direction = Vector2.ZERO
	_attack_left = 0.0
	_flash_left = 0.0
	_death_left = 0.0
	_facing_back = false
	_flip = false
	if _sprite != null:
		_sprite.position = Vector2.ZERO
		_sprite.rotation = 0.0
		_sprite.scale = _base_scale
		_sprite.modulate = _base_tint

func _process(delta: float) -> void:
	if _sprite == null or not is_instance_valid(_sprite):
		return

	if _death_left > 0.0:
		_death_left -= delta
		# З намальованою смертю нічого крутити не треба — вона вже
		# намальована; лишаємо тільки згасання в кінці.
		if _has_sheet and _clips.has(&"death"):
			_process_frames(delta)
			_sprite.modulate = _base_tint * Color(1, 1, 1, clampf(_death_left * 4.0, 0.0, 1.0))
			return
		var death_progress := 1.0 - clampf(_death_left / DEATH_TIME, 0.0, 1.0)
		_sprite.scale = _base_scale * (1.0 - 0.6 * death_progress)
		_sprite.modulate = _base_tint * Color(1, 1, 1, 1.0 - death_progress)
		_sprite.rotation = death_progress * 0.6
		return

	if _has_sheet:
		_process_frames(delta)

	var speed := _move_direction.length()
	var offset := Vector2.ZERO
	var scale_factor := Vector2.ONE
	var rotation_value := 0.0

	# Якщо кроки вже намальовані на аркуші, процедурне підстрибування
	# лише заважало б — лишаємо дзеркалення, ривок і спалах.
	if _has_sheet:
		pass
	elif speed > 0.1:
		# Хода: підстрибування вгору-вниз, присідання й похитування —
		# три речі разом читаються як крок.
		_step_phase += delta * STEP_SPEED * clampf(speed, 0.4, 1.0)
		var bounce := absf(sin(_step_phase))
		offset.y = -bounce * STEP_HEIGHT
		scale_factor.y = 1.0 + STEP_SQUASH * (bounce - 0.5)
		scale_factor.x = 1.0 - STEP_SQUASH * (bounce - 0.5)
		rotation_value = sin(_step_phase * 0.5) * SWAY_ANGLE
	else:
		# Стоїмо — тихо "дихаємо", щоб картинка не була мертвою.
		_step_phase += delta * BREATH_SPEED
		scale_factor.y = 1.0 + sin(_step_phase) * BREATH_SCALE
		scale_factor.x = 1.0 - sin(_step_phase) * BREATH_SCALE * 0.5

	if _attack_left > 0.0:
		_attack_left -= delta
		# Ривок уперед і назад: швидкий поштовх у бік цілі.
		var attack_progress := 1.0 - clampf(_attack_left / ATTACK_TIME, 0.0, 1.0)
		var punch := sin(attack_progress * PI)
		offset += _attack_aim * punch * ATTACK_LUNGE
		scale_factor *= 1.0 + 0.12 * punch

	var tint := _base_tint
	if _flash_left > 0.0:
		_flash_left -= delta
		tint = Color(2.2, 2.2, 2.2, _base_tint.a)

	_sprite.position = offset
	_sprite.rotation = rotation_value
	_sprite.scale = Vector2(_base_scale.x * scale_factor.x * (-1.0 if _flip else 1.0), _base_scale.y * scale_factor.y)
	_sprite.modulate = tint

	# На аркуші кадрів текстуру міняти не можна — там уже всі кадри.
	if _has_sheet:
		return
	var wanted: Texture2D = _back if (_facing_back and _back != null) else _front
	if wanted != null and _sprite.texture != wanted:
		_sprite.texture = wanted
