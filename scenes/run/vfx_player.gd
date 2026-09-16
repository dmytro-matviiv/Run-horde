extends Node2D

## Програвач одноразового анімованого ефекту зі спрайт-листа (VfxDef):
## розсічення сокири, вибух метеора, спалах блискавки. Лежить у пулі,
## бо за ран таких спалахів сотні.
##
## Sprite2D уміє різати аркуш сам (hframes/vframes + frame), тож окрема
## AnimatedSprite2D зі своїм ресурсом кадрів не потрібна — менше
## клопоту при підключенні нового набору.

@onready var sprite: Sprite2D = $Sprite

var _pool: ObjectPool
var _def: VfxDef
var _elapsed := 0.0
var _active := false
var _armed := false

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

## rotation_angle — куди "дивиться" ефект (для розсічень і променів).
func play(def: VfxDef, at_position: Vector2, rotation_angle: float = 0.0) -> void:
	if def == null or def.texture == null:
		return
	_def = def
	_elapsed = 0.0
	_armed = true
	global_position = at_position
	rotation = rotation_angle
	sprite.texture = def.texture
	sprite.hframes = maxi(def.hframes, 1)
	sprite.vframes = maxi(def.vframes, 1)
	sprite.frame = def.frame_start
	sprite.modulate = def.modulate_color
	sprite.scale = Vector2.ONE * (def.height / maxf(float(def.texture.get_height()) / float(sprite.vframes), 1.0))
	visible = true

func pool_activate() -> void:
	_active = true
	_armed = false
	visible = false

func pool_deactivate() -> void:
	_active = false
	_armed = false
	visible = false
	global_position = Vector2(-10000, -10000)

func _process(delta: float) -> void:
	if not _active or not _armed or _def == null:
		return
	_elapsed += delta
	var frame_index := _def.frame_start + int(_elapsed * _def.fps)
	if frame_index > _def.frame_start + _def.get_frame_count() - 1:
		_pool.release(self)
		return
	sprite.frame = frame_index
