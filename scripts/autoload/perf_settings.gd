extends Node

## Налаштування продуктивності під пристрій.
##
## На телефоні гра має не "виглядати ідеально", а йти плавно й не
## гріти пристрій. Тому тут вимикається все, що коштує дорого й майже
## не помітне на п'ятидюймовому екрані.
##
## Інтерфейс це не зачіпає: він малюється окремо й завжди різко.

## 3D малюємо у 75% роздільної здатності екрана. У телефонів дуже
## щільні екрани, тож на око різниці майже немає, а навантаження падає
## майже вдвічі.
const MOBILE_RENDER_SCALE := 0.75

## Фізику рахуємо 30 разів на секунду замість 60. Для гри, де немає ні
## куль, що летять крізь стіни, ні складної балістики, цього достатньо,
## а процесору вдвічі легше.
const MOBILE_PHYSICS_TICKS := 30

const MOBILE_MAX_FPS := 60
const MOBILE_SHADOW_ATLAS := 1024

func _ready() -> void:
	if not OS.has_feature("mobile"):
		return

	var root := get_tree().root
	root.scaling_3d_scale = MOBILE_RENDER_SCALE
	# Згладжування на телефоні коштує помітно, а на щільному екрані його
	# майже не видно.
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	root.use_taa = false
	# Менший атлас тіней: тіні лишаються, але коштують у рази менше.
	root.positional_shadow_atlas_size = MOBILE_SHADOW_ATLAS

	Engine.physics_ticks_per_second = MOBILE_PHYSICS_TICKS
	Engine.max_fps = MOBILE_MAX_FPS
