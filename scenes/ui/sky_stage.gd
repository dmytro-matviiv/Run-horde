extends Control
class_name SkyStage

## Небо за спиною героя на вітрині (Зала героїв) — блакитний градієнт і
## кілька хмаринок, як у мобільних рольових іграх: персонаж стоїть не на
## темній панелі, а просто неба.

const TOP := Color(0.42, 0.68, 0.95)
const BOTTOM := Color(0.72, 0.85, 0.98)
const CLOUD := Color(1.0, 1.0, 1.0, 0.55)

var _clouds: Array[Dictionary] = []
var _background: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 5:
		_clouds.append({
			"pos": Vector2(rng.randf(), rng.randf_range(0.08, 0.55)),
			"scale": rng.randf_range(0.6, 1.2),
		})
	resized.connect(queue_redraw)

	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# COVERED: картинка завжди заповнює всю смугу, зайве обрізається —
	# вітрина дуже широка й низька, тож квадратна чи портретна картинка
	# розтягнутою не лягла б, а обрізаною зверху/знизу — цілком природно.
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.visible = false
	add_child(_background)

## Свій фон героя (ArtSlots.hero_background) — якщо гравець його поклав;
## null повертає звичайне небо з хмарками, намальоване кодом.
func set_background(texture: Texture2D) -> void:
	_background.texture = texture
	_background.visible = texture != null
	queue_redraw()

func _draw() -> void:
	if _background.visible:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, BOTTOM)
	var steps := 24
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var color := TOP.lerp(BOTTOM, t0)
		draw_rect(Rect2(0, size.y * t0, size.x, size.y * (t1 - t0) + 1.0), color)
	for cloud: Dictionary in _clouds:
		_draw_cloud(Vector2(cloud.pos.x * size.x, cloud.pos.y * size.y), cloud.scale)
	# Легка земля внизу — щоб герой не "висів" у повітрі.
	var ground_h := size.y * 0.16
	draw_rect(Rect2(0, size.y - ground_h, size.x, ground_h), Color(0.55, 0.42, 0.32, 0.35))

func _draw_cloud(center: Vector2, scale: float) -> void:
	var r := 26.0 * scale
	for offset: Vector2 in [Vector2(-1.3, 0.1), Vector2(-0.4, -0.25), Vector2(0.5, -0.15), Vector2(1.3, 0.1), Vector2(0.1, 0.25)]:
		draw_circle(center + offset * r, r * 0.8, CLOUD)
