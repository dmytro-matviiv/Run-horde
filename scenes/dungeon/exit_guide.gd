extends Node3D
class_name ExitGuide

## СТРІЛКА ДО ПОРТАЛУ. Після перемоги над босом довкола героя на підлозі
## ходить по колу світна стрілка й показує, куди йти до порталу виходу.
## Напрям — не навпростець крізь стіни, а вздовж маршруту по карті
## (навігація та сама, що й у ворогів): за рогом стрілка повертає за ріг.
##
## Лежить на підлозі за кроком від героя: її видно, але вона не затуляє
## ні героя, ні ворогів, ні кнопок. Злегка "дихає" — пульсує й
## поштовхами подається вперед, як підказка "туди". Біля самого порталу
## ховається: там уже є кнопка виходу.

## Арка зі стрілок: дві шеврони, передня яскравіша; хвиля яскравості
## біжить від задньої до передньої — стрілка "кличе" вперед.
const ARROW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.74, 0.2, 1.0);
uniform float fade = 1.0;

// Відстань до шеврона "^", що дивиться вперед (+y).
float chevron_distance(vec2 p, float offset) {
	return abs(p.y - offset + abs(p.x) * 0.85) + max(abs(p.x) - 0.66, 0.0);
}

void fragment() {
	// UV.y = 1 — уперед, туди, куди веде стрілка.
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y * 2.0 - 1.0);
	float wave = fract(TIME * 1.1);
	float d_back = chevron_distance(p, -0.08);
	float d_front = chevron_distance(p, 0.4);
	float back = (1.0 - smoothstep(0.07, 0.11, d_back)) * (0.55 + 0.45 * smoothstep(0.35, 0.0, abs(wave - 0.25)));
	float front = (1.0 - smoothstep(0.08, 0.12, d_front)) * (0.8 + 0.2 * smoothstep(0.35, 0.0, abs(wave - 0.7)));
	float body = max(back, front);
	// Темна облямівка — щоб стрілку було видно й на світлій підлозі (крига).
	float rim = 1.0 - smoothstep(0.11, 0.2, min(d_back, d_front));
	float hot = smoothstep(0.75, 1.0, body);
	vec3 bright = mix(color.rgb, vec3(1.0, 0.97, 0.85), hot * 0.55);
	ALBEDO = mix(vec3(0.12, 0.06, 0.02), bright, body);
	ALPHA = clamp(max(body, rim * 0.55), 0.0, 1.0) * fade * color.a;
}
"""

## Як далеко від героя лежить стрілка й наскільки вона велика (м).
const ORBIT_RADIUS := 2.3
const ARROW_SIZE := 1.5
## Як часто перераховувати маршрут, с.
const REPATH_INTERVAL := 0.3
## Ближче за це до порталу стрілка ховається — далі веде кнопка виходу.
const HIDE_DISTANCE := 4.5
const TURN_SPEED := 9.0

var _player: Node3D
var _target := Vector3.ZERO
var _arrow: MeshInstance3D
var _yaw := 0.0
var _wanted_yaw := 0.0
var _repath_left := 0.0
var _visible_amount := 0.0
var _time := 0.0

func setup(player: Node3D, target: Vector3) -> void:
	_player = player
	_target = target
	_arrow = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(ARROW_SIZE, ARROW_SIZE)
	_arrow.mesh = quad
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = ARROW_SHADER
	material.shader = shader
	_arrow.material_override = material
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arrow)
	CombatVfx.set_param(_arrow, &"fade", 0.0)
	_update_direction()
	_yaw = _wanted_yaw

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		queue_free()
		return
	_time += delta
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = REPATH_INTERVAL
		_update_direction()
	_yaw = lerp_angle(_yaw, _wanted_yaw, minf(TURN_SPEED * delta, 1.0))

	var flat := _target - _player.global_position
	flat.y = 0.0
	var show := flat.length() > HIDE_DISTANCE
	_visible_amount = move_toward(_visible_amount, 1.0 if show else 0.0, delta * 3.0)
	visible = _visible_amount > 0.01
	if not visible:
		return
	# Пульс: стрілка дихає розміром і поштовхом подається вперед.
	var beat := 0.5 + 0.5 * sin(_time * 4.2)
	var direction := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var origin := _player.global_position
	_arrow.global_position = Vector3(origin.x, DungeonBuilder.FLOOR_TOP + 0.06, origin.z) \
		+ direction * (ORBIT_RADIUS + 0.12 * beat)
	_arrow.global_rotation = Vector3(0.0, _yaw, 0.0)
	_arrow.scale = Vector3.ONE * (0.92 + 0.12 * beat)
	CombatVfx.set_param(_arrow, &"fade", _visible_amount * (0.75 + 0.25 * beat))

## Куди йти: наступний поворот маршруту по навігаційній карті данжу.
## Якщо маршрут не знайшовся — просто на портал.
func _update_direction() -> void:
	var from := _player.global_position
	var aim := _target
	var map := get_world_3d().navigation_map if is_inside_tree() else RID()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		var path := NavigationServer3D.map_get_path(map, from, _target, true)
		for point in path:
			var offset := point - from
			offset.y = 0.0
			if offset.length() > 1.2:
				aim = point
				break
	var flat := aim - from
	flat.y = 0.0
	if flat.length() > 0.05:
		_wanted_yaw = atan2(flat.x, flat.z)
