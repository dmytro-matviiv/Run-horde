extends Resource
class_name VfxDef

## Опис анімованого ефекту зі спрайт-листа (розсічення, вибух, спалах
## магії тощо). Художники продають ефекти саме так: одна картинка, на
## якій кадри йдуть сіткою.
##
## Зроблено ресурсом, а не кодом, щоб підключення купленого набору
## зводилось до "створити .tres і вписати числа" — без правок гри.

@export var texture: Texture2D

## Скільки кадрів по горизонталі й вертикалі на аркуші.
@export var hframes: int = 1
@export var vframes: int = 1

## Які кадри програвати (включно). end < 0 — до останнього кадру аркуша.
@export var frame_start: int = 0
@export var frame_end: int = -1

@export var fps: float = 20.0

## Розмір ефекту на екрані у пікселях (по висоті кадру).
@export var height: float = 96.0

@export var modulate_color: Color = Color.WHITE

## Скільки кадрів має цей ефект.
func get_frame_count() -> int:
	var last := frame_end if frame_end >= 0 else hframes * vframes - 1
	return maxi(last - frame_start + 1, 1)

func get_duration() -> float:
	return get_frame_count() / maxf(fps, 1.0)
