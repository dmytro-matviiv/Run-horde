extends RefCounted
class_name CombatVfx

## Ефекти бою: слід меча, іскри влучання, цифри шкоди, кола-попередження
## на підлозі, "заморожування" кадру при сильному ударі.
##
## Попередження ворожих ударів і тріщини після них — з арту гравця
## (assets/textures/vfx), див. make_telegraph. Решта — кодом і шейдерами,
## без текстур: так ефекти однаково
## добре виглядають з будь-якого боку камери (плаский спрайт при повороті
## камери перетворився б на смужку) і майже нічого не коштують телефону —
## кілька трикутників і простий шейдер без світла.
##
## Меші й матеріали створюються один раз і діляться між усіма ефектами:
## двадцять ударів — ті самі два матеріали, а не двадцять нових.

## Слід меча: дуга, що "пробігає" від одного краю до іншого й гасне.
## progress іде від 0 до 1.4: спершу виростає голова сліду, далі хвіст
## наздоганяє її, і дуга зникає.
const SLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.75, 0.88, 1.0, 1.0);
uniform float progress = 0.0;
uniform float reverse_dir = 0.0;
uniform float intensity = 1.0;

void fragment() {
	float u = mix(UV.x, 1.0 - UV.x, reverse_dir);
	float head = progress;
	float tail = progress - 0.6;
	float along = smoothstep(tail, head, u) * (1.0 - step(head, u));
	// Яскравий тонкий край леза й прозорий "хвіст" усередину дуги.
	float radial = smoothstep(0.15, 0.85, UV.y) * (1.0 - smoothstep(0.93, 1.0, UV.y));
	float edge = 0.15 + 0.85 * pow(UV.y, 3.0);
	float fade = 1.0 - smoothstep(1.0, 1.4, progress);
	ALBEDO = mix(color.rgb, vec3(1.0), pow(UV.y, 4.0) * 0.7) * 1.25 * intensity;
	ALPHA = clamp(along * radial * edge * fade * 0.8, 0.0, 1.0);
}
"""

## Коло або сектор на підлозі. Для ворожого попередження заповнюється
## від центру до краю (progress 0..1) — видно, скільки лишилось до удару.
## Для вихору героя це хвиля, що біжить назовні (wave = 1).
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.25, 0.2, 1.0);
uniform float progress = 0.0;
uniform float half_arc = 3.1416;
uniform float wave = 0.0;
uniform float fade = 1.0;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d) * 2.0;
	float angle = abs(atan(d.x, d.y));
	float in_arc = 1.0 - step(half_arc, angle);
	float inside = 1.0 - smoothstep(0.97, 1.0, dist);
	float alpha;
	if (wave > 0.5) {
		float band = 1.0 - smoothstep(0.0, 0.18, abs(dist - progress));
		alpha = band * (1.0 - progress * 0.7);
	} else {
		float outline = smoothstep(0.88, 0.95, dist) * inside;
		float fill = (1.0 - step(progress, dist)) * inside;
		alpha = max(outline * 0.9, fill * 0.45 + 0.08 * inside);
	}
	ALBEDO = color.rgb;
	ALPHA = clamp(alpha * in_arc * fade * color.a, 0.0, 1.0);
}
"""

## Смуга на підлозі: куди зараз розженеться таран. Заповнюється від
## нього вперед — видно, скільки лишилось до ривка.
const LINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.3, 0.2, 1.0);
uniform float progress = 0.0;

void fragment() {
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float border = 1.0 - smoothstep(0.03, 0.08, edge);
	float fill = step(UV.y, progress);
	ALBEDO = color.rgb;
	ALPHA = clamp(max(border * 0.9, fill * 0.42 + 0.08), 0.0, 1.0) * color.a;
}
"""

## Попередження ворога з арту (коло, віяло, смуга) і тріщини після удару.
## Арт — статична текстура, "живим" його робить шейдер:
##   - уся зона видна одразу (тьмяно), щоб гравець встиг вийти;
##   - від ворога до краю біжить заливка з яскравою кромкою (progress 0..1);
##   - заливка пульсує, і що ближче удар — то частіше.
## Арт намальований теплим (червоно-помаранчевим). Якщо попередження
## іншого кольору (зелене, крижане), recolor = 1 перефарбовує арт у color,
## лишаючи білим лише розпечене серце.
const TELEGRAPH_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D art : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 color : source_color = vec4(1.0, 0.3, 0.2, 1.0);
// 0 — коло, 1 — віяло (арт розкладено довкола вершини), 2 — смуга
uniform int shape = 0;
uniform float recolor = 0.0;
uniform float progress = 0.0;
uniform float half_arc = 3.1416;
uniform float fade = 1.0;
// 0 — без підкладки кольором (тріщини після удару), 1 — з нею.
uniform float base = 1.0;
// 1 — розпечене серце арту лишається білим; 0 — теж фарбується (пил).
uniform float keep_hot = 1.0;

// Віяло в арті: вершина й радіус (у долях текстури) і половина кута, яку
// розтягуємо на справжній кут удару (трохи ширше за рамку — разом із рунами).
const vec2 CONE_APEX = vec2(0.4995, 0.8725);
const float CONE_RADIUS = 0.752;
const float CONE_HALF = 0.56;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d) * 2.0;
	vec2 tex_uv = UV;
	float reach = dist;
	float inside = 1.0 - smoothstep(0.96, 1.0, dist);
	if (shape == 1) {
		float angle = atan(d.x, d.y);
		inside *= 1.0 - step(half_arc, abs(angle));
		float a = angle / half_arc * CONE_HALF;
		tex_uv = CONE_APEX + vec2(sin(a), -cos(a)) * dist * CONE_RADIUS;
	} else if (shape == 2) {
		// Смуга: від ворога (UV.y = 0) уперед; стрілки арту — туди ж.
		reach = UV.y;
		inside = 1.0;
		tex_uv = vec2(UV.x, 1.0 - UV.y);
	}
	vec4 t = texture(art, tex_uv);
	float hot = smoothstep(0.55, 1.0, min(min(t.r, t.g), t.b));
	// Перефарбований арт зберігає світлотінь: темне — темніше, жилки світліші.
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = mix(color.rgb * (0.3 + 0.9 * lum), vec3(1.0), hot * keep_hot);
	vec3 art_rgb = mix(t.rgb, tinted, recolor);

	float fill = smoothstep(progress + 0.04, progress - 0.04, reach);
	float pulse = 0.8 + 0.2 * sin(TIME * (7.0 + progress * 22.0));
	float a_art = min(t.a * 1.3, 1.0) * (0.6 + 0.4 * fill * pulse);
	// Підкладка — притемнений колір зони: на темній підлозі зону видно
	// за кольором, на світлій (крига) вона темнішає, і арт на ній світиться.
	float a_base = inside * base * (0.42 + 0.25 * fill * pulse);
	float a = a_art + a_base * (1.0 - a_art);
	vec3 rgb = (art_rgb * a_art + color.rgb * 0.35 * a_base * (1.0 - a_art)) / max(a, 0.001);

	// Кромка заливки — біжить до краю, на самому ударі зникає.
	float front = (1.0 - smoothstep(0.0, 0.06, abs(reach - progress)))
		* step(0.02, progress) * (1.0 - step(0.995, progress)) * inside * base;
	rgb = mix(rgb, mix(color.rgb, vec3(1.0), 0.6), front);
	a = max(a, front * 0.8);

	ALBEDO = rgb;
	ALPHA = clamp(a * fade * color.a, 0.0, 1.0);
}
"""

const TELEGRAPH_ART := {
	"lava": preload("res://assets/textures/vfx/telegraph_circle_lava.png"),
	"rune": preload("res://assets/textures/vfx/telegraph_circle_rune.png"),
	"cone": preload("res://assets/textures/vfx/telegraph_cone.png"),
	"chevrons": preload("res://assets/textures/vfx/telegraph_line_chevrons.png"),
	"flames": preload("res://assets/textures/vfx/telegraph_line_flames.png"),
	"cracks": preload("res://assets/textures/vfx/impact_cracks.png"),
}
## Відтінок, яким намальований арт: теплий (червоно-помаранчевий) і рунне
## коло (фіолетове). Колір попередження, близький до нього, арт не
## перефарбовує.
const WARM_HUE := 0.04
const RUNE_HUE := 0.77
const PARTICLE_ART := {
	"glow": preload("res://assets/textures/vfx/particle_glow.png"),
	"rock": preload("res://assets/textures/vfx/particle_rock.png"),
	"dust": preload("res://assets/textures/vfx/particle_dust.png"),
}

## Спалах поверх моделі, коли в неї влучили.
const FLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	ALBEDO = color.rgb * 0.6;
	ALPHA = 0.55;
}
"""

## Спалах — м'яка зірка, намальована в шейдері як яскравий центр з
## променями.
const FLARE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	float r = length(d);
	float core = 1.0 - smoothstep(0.0, 0.45, r);
	float rays = max(1.0 - smoothstep(0.0, 0.08, abs(d.x)), 1.0 - smoothstep(0.0, 0.08, abs(d.y)));
	rays *= 1.0 - smoothstep(0.3, 1.0, r);
	ALBEDO = mix(color.rgb, vec3(1.0), core) * 1.5;
	ALPHA = clamp(core + rays * 0.8, 0.0, 1.0);
}
"""

const SLASH_SEGMENTS := 26

static var _slash_meshes: Dictionary = {}
## Мінімалізм: на одну подію (удар об землю, смерть, вибух) — один ефект.
## Хто перший у цьому кадрі заявив місце, той і малює; хвиля, іскри й
## тріщини в те саме місце того ж кадру вже не накладаються.
static var _claims: Array = []
## Вогники по краях попереджень. Мінімалізм: вимкнено — лише малюнок на підлозі.
const EMBERS := false
static var _claims_frame := -1
static var _sparks_frame := -1
static var _sparks_count := 0
static var _slash_materials: Dictionary = {}
static var _ring_materials: Dictionary = {}
static var _flash_materials: Dictionary = {}
static var _spark_material: StandardMaterial3D
static var _spark_mesh: QuadMesh
static var _flare_mesh: QuadMesh
static var _flare_materials: Dictionary = {}
static var _ring_mesh: PlaneMesh
static var _line_materials: Dictionary = {}
static var _thrust_mesh: BoxMesh
static var _bolt_mesh: BoxMesh
static var _beam_mesh: CylinderMesh
static var _glow_materials: Dictionary = {}
static var _telegraph_materials: Dictionary = {}
static var _particle_materials: Dictionary = {}
static var _particle_meshes: Dictionary = {}
static var _shaders: Dictionary = {}
static var _hitstop_until := 0
static var _hitstop_token := 0

# --- слід меча ---

## Дуга удару довкола героя. yaw — куди дивиться герой, arc_deg — ширина
## замаху, reverse — замах у зворотний бік (друга ланка комбо).
static func slash(parent: Node, origin: Vector3, yaw: float, radius: float, arc_deg: float,
		color: Color, reverse: bool = false, tilt: float = 0.0, duration: float = 0.26) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = _get_slash_mesh(radius, arc_deg)
	instance.material_override = _get_material(_slash_materials, SLASH_SHADER, color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	instance.global_position = origin
	instance.global_rotation = Vector3(tilt, yaw, 0.0)
	CombatVfx.set_param(instance, &"reverse_dir", 1.0 if reverse else 0.0)
	CombatVfx.set_param(instance, &"progress", 0.0)
	var tween := instance.create_tween()
	tween.tween_method(func(value: float) -> void:
		CombatVfx.set_param(instance, &"progress", value), 0.0, 1.4, duration)
	tween.tween_callback(instance.queue_free)

## Плаский сектор кільця в площині XZ, розвернутий на +Z (туди, куди
## дивиться герой). UV.x — уздовж дуги, UV.y — від внутрішнього краю до
## зовнішнього.
static func _get_slash_mesh(radius: float, arc_deg: float) -> ArrayMesh:
	var key := "%.2f|%.1f" % [radius, arc_deg]
	if _slash_meshes.has(key):
		return _slash_meshes[key]
	var inner := radius * 0.45
	var half := deg_to_rad(arc_deg) * 0.5
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in SLASH_SEGMENTS + 1:
		var t := float(i) / SLASH_SEGMENTS
		var angle := lerpf(-half, half, t)
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		vertices.append(direction * inner)
		uvs.append(Vector2(t, 0.0))
		vertices.append(direction * radius)
		uvs.append(Vector2(t, 1.0))
		if i < SLASH_SEGMENTS:
			var a := i * 2
			indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_slash_meshes[key] = mesh
	return mesh

## Укол списом чи тризубом: яскрава смуга вистрілює вперед на довжину
## удару й гасне — видно, що б'є вузько й далеко.
static func thrust(parent: Node, origin: Vector3, yaw: float, length: float, color: Color) -> void:
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.global_position = origin
	pivot.global_rotation = Vector3(0.0, yaw, 0.0)
	var beam := MeshInstance3D.new()
	beam.mesh = _get_thrust_mesh()
	beam.material_override = get_glow_material(color)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Смуга лежить від героя вперед (меш — від 0 до 1 по Z).
	beam.position = Vector3(0, 0, 0.5)
	pivot.add_child(beam)
	pivot.scale = Vector3(1.0, 1.0, 0.2)
	var tween := pivot.create_tween()
	tween.tween_property(pivot, "scale", Vector3(1.0, 1.0, length), 0.08)
	tween.tween_property(beam, "transparency", 1.0, 0.16)
	tween.tween_callback(pivot.queue_free)

## Світний матеріал без освітлення (снаряди чар, укол) — один на колір.
static func get_glow_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _glow_materials.has(key):
		return _glow_materials[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	material.disable_receive_shadows = true
	_glow_materials[key] = material
	return material

static func _get_thrust_mesh() -> BoxMesh:
	if _thrust_mesh == null:
		_thrust_mesh = BoxMesh.new()
		_thrust_mesh.size = Vector3(0.16, 0.06, 1.0)
	return _thrust_mesh

# --- чари ---

## Слід за снарядом чар: світні іскри лишаються позаду й гаснуть.
static func make_trail(color: Color, lifetime: float) -> CPUParticles3D:
	var trail := CPUParticles3D.new()
	trail.amount = 10
	trail.lifetime = lifetime
	# Іскри лишаються там, де пролетів снаряд, а не летять разом із ним.
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.06
	trail.spread = 180.0
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.4
	trail.scale_amount_min = 1.3
	trail.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	trail.scale_amount_curve = curve
	trail.mesh = _get_spark_mesh()
	trail.material_override = _get_spark_material()
	trail.color = color
	return trail

## Блискавка: ламана лінія через точки (посох -> перший ворог -> другий...),
## спалахує на мить і зникає.
static func lightning(parent: Node, points: Array[Vector3], color: Color) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	var material := get_glow_material(color)
	for i in points.size() - 1:
		var from: Vector3 = points[i]
		var to: Vector3 = points[i + 1]
		var side := (to - from).cross(Vector3.UP)
		side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
		var shake := minf(from.distance_to(to), 4.0) / 4.0
		var joints: Array[Vector3] = [from]
		for k in range(1, 5):
			joints.append(from.lerp(to, k / 5.0) + side * randf_range(-0.35, 0.35) * shake
				+ Vector3.UP * randf_range(-0.2, 0.2) * shake)
		joints.append(to)
		for k in joints.size() - 1:
			_add_segment(holder, joints[k], joints[k + 1], material)
	_free_after(holder, 0.18)

static func _add_segment(holder: Node3D, a: Vector3, b: Vector3, material: Material) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var segment := MeshInstance3D.new()
	segment.mesh = _get_bolt_mesh()
	segment.material_override = material
	segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(segment)
	segment.global_position = (a + b) * 0.5
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.FORWARD
	segment.look_at(b, up)
	segment.scale = Vector3(1.0, 1.0, length)

## Промінь із неба (Місячна буря): світний стовп падає в точку й гасне.
static func sky_beam(parent: Node, position: Vector3, color: Color) -> void:
	var beam := MeshInstance3D.new()
	beam.mesh = _get_beam_mesh()
	beam.material_override = get_glow_material(color)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(beam)
	beam.global_position = position + Vector3.UP * 3.5
	beam.scale = Vector3(0.25, 1.0, 0.25)
	var tween := beam.create_tween()
	tween.tween_property(beam, "scale", Vector3(1.1, 1.0, 1.1), 0.08)
	tween.tween_property(beam, "transparency", 1.0, 0.28)
	tween.tween_callback(beam.queue_free)
	shockwave(parent, position, 1.4, color, 0.3)
	impact(parent, position + Vector3.UP * 0.4, color, true)

## Іскра й її матеріал — для частинок, що фарбуються власним кольором
## (слід чар, бульбашки отрути).
static func spark_mesh() -> QuadMesh:
	return _get_spark_mesh()

static func spark_material() -> StandardMaterial3D:
	return _get_spark_material()

static func _get_bolt_mesh() -> BoxMesh:
	if _bolt_mesh == null:
		_bolt_mesh = BoxMesh.new()
		_bolt_mesh.size = Vector3(0.07, 0.07, 1.0)
	return _bolt_mesh

static func _get_beam_mesh() -> CylinderMesh:
	if _beam_mesh == null:
		_beam_mesh = CylinderMesh.new()
		_beam_mesh.top_radius = 0.22
		_beam_mesh.bottom_radius = 0.22
		_beam_mesh.height = 7.0
		_beam_mesh.radial_segments = 6
		_beam_mesh.rings = 1
	return _beam_mesh

# --- влучання ---

## Іскри й короткий спалах у точці влучання. big — для сильних ударів.
## true — місце вільне (і тепер зайняте цим ефектом); false — у цьому кадрі
## тут уже щось спрацювало, другий ефект не потрібен.
static func claim(position: Vector3, reach: float = 1.6) -> bool:
	var frame := Engine.get_process_frames()
	if frame != _claims_frame:
		_claims_frame = frame
		_claims.clear()
	var flat := Vector2(position.x, position.z)
	for spot: Vector2 in _claims:
		if spot.distance_to(flat) < reach:
			return false
	_claims.append(flat)
	return true

static func impact(parent: Node, position: Vector3, color: Color, big: bool = false) -> void:
	if not claim(position):
		return
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 7 if big else 4
	particles.lifetime = 0.35 if big else 0.25
	# Світні цятки, а не квадрати.
	particles.mesh = _get_particle_mesh(0.16)
	particles.material_override = _get_particle_material("glow", true)
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 3.0 if big else 2.0
	particles.initial_velocity_max = 7.5 if big else 5.0
	particles.gravity = Vector3(0, -9.0, 0)
	particles.damping_min = 2.0
	particles.damping_max = 4.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	particles.color = color
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = curve
	parent.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	_free_after(particles, particles.lifetime + 0.1)
	# Без спалаху-зірки (гравець не хоче спалахів): лише іскри.

## Іскри влучання клинка — свої для кожного удару серії (kind). Без
## спалаху: на ворогові лишається слід порізу (свій нахил для кожного
## удару) і розлітаються світні іскри.
##   slash    — косий удар: поріз навскіс, холодні іскри вздовж удару;
##   rising   — зворотний знизу вгору: поріз навскіс в інший бік, золоті іскри вгору;
##   sweep    — широкий мах: горизонтальний поріз, віяло помаранчевих іскор;
##   spin     — оберт: кільце-поріз довкола ворога, блакитні іскри колом;
##   finisher — фініш: поріз хрестом, вибух іскор, пил і хвиля.
## direction — куди йшов удар (від героя до ворога). Крит — яскравіше й більше.
const SPARK_STYLES := {
	"slash": {"color": Color(0.7, 0.88, 1.0), "amount": 10, "speed": [4.0, 8.0], "spread": 35.0, "up": 0.35,
		"flat": 0.0, "size": 0.2, "cuts": [[0.65, false]]},
	"rising": {"color": Color(1.0, 0.8, 0.3), "amount": 10, "speed": [3.5, 7.5], "spread": 28.0, "up": 1.4,
		"flat": 0.0, "size": 0.2, "cuts": [[-0.65, true]]},
	"sweep": {"color": Color(1.0, 0.55, 0.25), "amount": 14, "speed": [5.0, 9.0], "spread": 70.0, "up": 0.15,
		"flat": 0.85, "size": 0.22, "cuts": [[0.0, false]]},
	"spin": {"color": Color(0.45, 0.95, 1.0), "amount": 12, "speed": [4.0, 7.5], "spread": 180.0, "up": 0.1,
		"flat": 0.9, "size": 0.2, "cuts": []},
	"finisher": {"color": Color(1.0, 0.45, 0.15), "amount": 20, "speed": [5.0, 11.0], "spread": 75.0, "up": 1.0,
		"flat": 0.0, "size": 0.3, "cuts": [[0.75, false], [-0.75, true]]},
}

static func hit_spark(parent: Node, position: Vector3, direction: Vector3, kind: String, crit: bool = false) -> void:
	# Махом зачепило натовп — іскри лише на перших двох, решта без ефекту.
	var frame := Engine.get_process_frames()
	if frame != _sparks_frame:
		_sparks_frame = frame
		_sparks_count = 0
	_sparks_count += 1
	if _sparks_count > 2:
		return
	var style: Dictionary = SPARK_STYLES.get(kind, SPARK_STYLES.slash)
	var color: Color = style.color
	if crit:
		color = color.lerp(Color(1.0, 1.0, 0.7), 0.45)
	var flat := Vector3(direction.x, 0.0, direction.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var boost := 1.3 if crit else 1.0
	# Слід порізу: дуга, що проходить крізь ворога (центр — ближче до героя).
	var yaw := atan2(flat.x, flat.z)
	var big := kind == "finisher"
	# Слід порізу — лише на фініші і лише на першому вороґові: замах героя
	# вже малює свою дугу, другі дуги на кожному ворогові — зайве.
	if big and _sparks_count == 1:
		var cut: Array = style.cuts[0]
		slash(parent, position - flat * 0.75, yaw, 1.25 * boost, 110.0, color, bool(cut[1]), float(cut[0]), 0.2)
	# Світні іскри.
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = maxi(int(int(style.amount) * boost * 0.5), 3)
	particles.lifetime = 0.45 if big else 0.35
	particles.mesh = _get_particle_mesh(float(style.size) * boost)
	particles.material_override = _get_particle_material("glow", true)
	particles.direction = (flat + Vector3.UP * float(style.up)).normalized()
	particles.spread = float(style.spread)
	particles.flatness = float(style.flat)
	var speed: Array = style.speed
	particles.initial_velocity_min = float(speed[0])
	particles.initial_velocity_max = float(speed[1])
	particles.gravity = Vector3(0, -12.0, 0)
	particles.damping_min = 3.0
	particles.damping_max = 5.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	particles.color = color
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = curve
	parent.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	_free_after(particles, particles.lifetime + 0.1)
	var ground := Vector3(position.x, DungeonBuilder.FLOOR_TOP, position.z)
	match kind:
		"finisher":
			if _sparks_count > 1:
				return
			var dust := _make_burst("dust", Color(0.75, 0.68, 0.58, 0.6), 5, 0.6, 0.5)
			dust.direction = Vector3.UP
			dust.spread = 80.0
			dust.flatness = 0.6
			dust.initial_velocity_min = 1.5
			dust.initial_velocity_max = 3.5
			dust.gravity = Vector3(0, -2.0, 0)
			parent.add_child(dust)
			dust.global_position = ground + Vector3.UP * 0.2
			dust.emitting = true
			_free_after(dust, 0.8)

## Іскри сили, що повільно здіймаються довкола (аура посилення, тотем):
## м'які світні цятки, без кіл на підлозі. Повертає вузол — його чіпляють
## до того, хто світиться (local_coords: іскри йдуть разом із ним).
static func make_motes(color: Color, amount: int, radius: float, rise: float, size: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 1.4
	particles.local_coords = true
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_axis = Vector3.UP
	particles.emission_ring_radius = radius
	particles.emission_ring_inner_radius = radius * 0.4
	particles.emission_ring_height = 0.1
	particles.direction = Vector3.UP
	particles.spread = 12.0
	particles.gravity = Vector3(0, rise * 0.5, 0)
	particles.initial_velocity_min = rise * 0.35
	particles.initial_velocity_max = rise * 0.7
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = curve
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.lerp(Color.WHITE, 0.45), 0.9))
	gradient.set_color(1, Color(color, 0.0))
	particles.color_ramp = gradient
	particles.mesh = _get_particle_mesh(size)
	particles.material_override = _get_particle_material("glow", true)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles

## Згусток сили, що плавно летить дугою від from до цілі (target — вузол,
## за яким він доганяє; бере його точку на висоті height). Лишає легкий
## слід іскор; долетів — тихо розсіюється.
static func glow_orb(parent: Node, from: Vector3, target: Node3D, height: float, color: Color, time: float) -> void:
	var orb := Node3D.new()
	parent.add_child(orb)
	orb.global_position = from
	var core := MeshInstance3D.new()
	core.mesh = _get_particle_mesh(0.42)
	core.material_override = _get_orb_material(color)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(core)
	var trail := CPUParticles3D.new()
	trail.amount = 10
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.05
	trail.spread = 180.0
	trail.initial_velocity_min = 0.05
	trail.initial_velocity_max = 0.2
	trail.gravity = Vector3.ZERO
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	trail.scale_amount_curve = curve
	trail.color = Color(color, 0.8)
	trail.mesh = _get_particle_mesh(0.16)
	trail.material_override = _get_particle_material("glow", true)
	orb.add_child(trail)
	var start := from
	var tween := orb.create_tween()
	tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(orb):
			return
		var goal := start
		if is_instance_valid(target):
			goal = target.global_position + Vector3.UP * height
		var middle := start.lerp(goal, 0.5) + Vector3.UP * (0.6 + start.distance_to(goal) * 0.12)
		var a := start.lerp(middle, t)
		var b := middle.lerp(goal, t)
		orb.global_position = a.lerp(b, t)
		core.scale = Vector3.ONE * lerpf(0.7, 1.0, sin(t * PI)), 0.0, 1.0, time).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		trail.emitting = false)
	tween.tween_property(core, "scale", Vector3.ONE * 1.6, 0.18)
	tween.parallel().tween_property(core, "transparency", 1.0, 0.18)
	tween.tween_interval(0.3)
	tween.tween_callback(orb.queue_free)

static var _orb_materials := {}

static func _get_orb_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _orb_materials.has(key):
		var material: StandardMaterial3D = _get_particle_material("glow", true).duplicate()
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.vertex_color_use_as_albedo = false
		material.albedo_color = color
		_orb_materials[key] = material
	return _orb_materials[key]

## Спалах пострілу біля ствола: коротка яскрава зірка й кілька іскор
## уздовж напрямку. Без справжнього світла — телефон його не потягне на
## кожному пострілі, а видно однаково добре.
## flare — спалах біля дула: лише для вогнепальної зброї. Закляття
## спалаху не має — лише кілька іскор кольору чар.
static func muzzle_flash(parent: Node, position: Vector3, direction: Vector3, color: Color, flare_on: bool = true) -> void:
	if flare_on:
		_muzzle_flare(parent, position, color)
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 5 if flare_on else 4
	sparks.lifetime = 0.16
	sparks.mesh = _get_particle_mesh(0.12)
	sparks.material_override = _get_particle_material("glow", true)
	sparks.direction = direction
	sparks.spread = 14.0
	sparks.initial_velocity_min = 4.0
	sparks.initial_velocity_max = 9.0
	sparks.gravity = Vector3(0, -4.0, 0)
	sparks.color = color
	parent.add_child(sparks)
	sparks.global_position = position
	sparks.emitting = true
	_free_after(sparks, 0.3)

static func _muzzle_flare(parent: Node, position: Vector3, color: Color) -> void:
	var flare := MeshInstance3D.new()
	flare.mesh = _get_flare_mesh()
	flare.material_override = _get_flare_material(color)
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flare)
	flare.global_position = position
	flare.scale = Vector3.ONE * 0.5
	var tween := flare.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flare, "scale", Vector3.ONE * 0.9, 0.07)
	tween.tween_property(flare, "transparency", 1.0, 0.07)
	tween.chain().tween_callback(flare.queue_free)

## Цифра шкоди, що злітає над ворогом. Критичний удар — більша жовта.
static func damage_number(parent: Node, position: Vector3, amount: float, crit: bool = false) -> void:
	var label := Label3D.new()
	label.text = "%d%s" % [roundi(amount), "!" if crit else ""]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.double_sided = true
	label.font_size = 64 if crit else 46
	label.pixel_size = 0.008
	label.outline_size = 14
	label.modulate = Color(1.0, 0.85, 0.25) if crit else Color(1, 1, 1)
	label.outline_modulate = Color(0.25, 0.05, 0.02) if crit else Color(0.08, 0.08, 0.1)
	label.render_priority = 5
	label.outline_render_priority = 4
	parent.add_child(label)
	# Невеликий розкид, щоб цифри від серії ударів не злипались в одну.
	label.global_position = position + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	label.scale = Vector3.ONE * 0.6
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector3.ONE * (1.25 if crit else 1.0), 0.1)
	tween.tween_property(label, "position:y", label.position.y + 1.1, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.45)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.25).set_delay(0.45)
	tween.chain().tween_callback(label.queue_free)

## Коротко підсвічує модель білим (або іншим кольором). Накладка
## вішається лише на мить удару: постійна коштувала б зайвий прохід
## малювання для кожного ворога.
##
## Поки спалах гасне, модель може зникнути: ворог помер, або гравець
## вийшов з данжу. Тому список мешів перебираємо без типу й кожен
## перевіряємо — інакше Godot падає з "previously freed instance".
## Таймер іде й під час паузи, щоб модель не лишалась білою, поки
## відкрите вікно вибору здібності.
static func flash_model(model: Node, color: Color = Color.WHITE, duration: float = 0.1) -> void:
	if model == null or not is_instance_valid(model):
		return
	var material := _get_material(_flash_materials, FLASH_SHADER, color)
	var meshes := model.find_children("*", "GeometryInstance3D", true, false)
	for mesh: GeometryInstance3D in meshes:
		mesh.material_overlay = material
	var tree := model.get_tree()
	if tree == null:
		return
	tree.create_timer(duration, true).timeout.connect(func() -> void:
		for mesh in meshes:
			if is_instance_valid(mesh) and (mesh as GeometryInstance3D).material_overlay == material:
				(mesh as GeometryInstance3D).material_overlay = null)

# --- кола на підлозі ---

## Кільце-сектор на підлозі, яким керує той, хто його створив (ворог
## показує ним свій майбутній удар). Повертає вузол; progress задається
## через CombatVfx.set_param.
static func make_ground_marker(color: Color, radius: float, half_arc: float = PI) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _get_ring_mesh()
	instance.material_override = _get_material(_ring_materials, RING_SHADER, color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)
	CombatVfx.set_param(instance, &"half_arc", half_arc)
	CombatVfx.set_param(instance, &"progress", 0.0)
	return instance

## Смуга-попередження для тарана. length — довжина ривку, width — ширина.
static func make_line_marker(color: Color, length: float, width: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _get_ring_mesh()
	instance.material_override = _get_material(_line_materials, LINE_SHADER, color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.scale = Vector3(width, 1.0, length)
	CombatVfx.set_param(instance, &"progress", 0.0)
	return instance

## Попередження ворожого удару з арту: коло (half_arc = PI) або віяло.
## Тепле — розпечене кільце з каменю, інших кольорів — рунне коло. embers —
## іскри, що здіймаються з краю (для великих ударів; звичайним ударам
## орди не треба — їх буває багато одночасно).
## Керується так само, як make_ground_marker: progress 0..1.
static func make_telegraph(color: Color, radius: float, half_arc: float = PI, embers: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _get_ring_mesh()
	var shape := 0 if half_arc >= PI - 0.01 else 1
	var art := "cone"
	if shape == 0:
		# Арт кола — за стихією: розпечене каміння, сніжинка, руни-печатка
		# (отрута й некромантія), фіолетові руни для решти.
		match Fx.theme_of(color):
			"fire":
				art = "lava" if _hue_close(color, WARM_HUE) else "rune"
			"ice":
				art = "frost"
			"poison":
				art = "hex"
			_:
				art = "rune"
	else:
		# Віяло — теж за стихією: крижані тріщини чи рунні дуги замість лави.
		art = _themed_art(color, "cone")
	instance.material_override = _get_telegraph_material(art, shape, color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)
	CombatVfx.set_param(instance, &"half_arc", half_arc)
	CombatVfx.set_param(instance, &"progress", 0.0)
	if embers and EMBERS and radius >= 1.0 and color.a > 0.05:
		var points := PackedVector3Array()
		var steps := clampi(int(radius * 6.0), 10, 28)
		for i in steps:
			var angle := lerpf(-half_arc, half_arc, (i + 0.5) / steps)
			points.append(Vector3(sin(angle), 0.0, cos(angle)) * radius)
		if shape == 1:
			for i in 4:
				var along := radius * (i + 0.5) / 4.0
				points.append(Vector3(sin(half_arc), 0.0, cos(half_arc)) * along)
				points.append(Vector3(-sin(half_arc), 0.0, cos(half_arc)) * along)
		_attach_embers(instance, points, color, clampi(int(radius * 4.0), 6, 16))
	return instance

## Смуга-попередження з арту: "chevrons" — ривок тарана (стрілки вперед),
## "flames" — промінь боса. Смуга лежить від ворога вперед по +Z.
static func make_line_telegraph(color: Color, length: float, width: float, art: String = "chevrons",
		embers: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _get_ring_mesh()
	art = _themed_art(color, art)
	instance.material_override = _get_telegraph_material(art, 2, color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.scale = Vector3(width, 1.0, length)
	CombatVfx.set_param(instance, &"progress", 0.0)
	if embers and EMBERS and color.a > 0.05:
		var points := PackedVector3Array()
		var steps := clampi(int(length), 4, 14)
		for i in steps:
			var z := lerpf(-0.5, 0.5, (i + 0.5) / steps) * length
			points.append(Vector3(width * 0.45, 0.0, z))
			points.append(Vector3(-width * 0.45, 0.0, z))
		_attach_embers(instance, points, color, clampi(int(length * 1.2), 6, 14))
	return instance

## Тріщини на підлозі там, де вдарило, — з камінцями й пилом. Тріщини
## гаснуть за мить, тож не захаращують залу.
static func impact_decal(parent: Node, position: Vector3, radius: float, color: Color, linger: float = 0.5) -> void:
	if not claim(position, maxf(radius, 1.6)):
		return
	var decal := MeshInstance3D.new()
	decal.mesh = _get_ring_mesh()
	decal.material_override = _get_telegraph_material("cracks", 0, Color(color, 1.0))
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	CombatVfx.set_param(decal, &"progress", 1.0)
	parent.add_child(decal)
	decal.global_position = position + Vector3(0, 0.07, 0)
	decal.rotation.y = randf() * TAU
	var size := radius * 2.3
	decal.scale = Vector3(size * 0.6, 1.0, size * 0.6)
	var tween := decal.create_tween()
	tween.tween_property(decal, "scale", Vector3(size, 1.0, size), 0.09).set_ease(Tween.EASE_OUT)
	tween.tween_interval(linger)
	tween.tween_method(func(value: float) -> void:
		CombatVfx.set_param(decal, &"fade", value), 1.0, 0.0, 0.7)
	tween.tween_callback(decal.queue_free)

	# Камінці злітають і падають; пил повільно розповзається.
	var rocks := _make_burst("rock", Color.WHITE if _hue_close(color, WARM_HUE) else color.lerp(Color.WHITE, 0.5),
		clampi(int(radius * 1.5), 3, 6), 0.75, 0.2)
	rocks.direction = Vector3.UP
	rocks.spread = 55.0
	rocks.initial_velocity_min = 3.0
	rocks.initial_velocity_max = 6.5
	rocks.gravity = Vector3(0, -14.0, 0)
	rocks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	rocks.emission_sphere_radius = radius * 0.35
	parent.add_child(rocks)
	rocks.global_position = position + Vector3(0, 0.2, 0)
	rocks.emitting = true
	_free_after(rocks, 1.0)
	var dust := _make_burst("dust", Color(color.lerp(Color(0.8, 0.75, 0.7), 0.6), 0.35), 3, 0.9, radius * 0.6)
	dust.direction = Vector3.UP
	dust.spread = 80.0
	dust.initial_velocity_min = 0.6
	dust.initial_velocity_max = 1.6
	dust.gravity = Vector3.ZERO
	dust.damping_min = 1.0
	dust.damping_max = 2.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = radius * 0.4
	parent.add_child(dust)
	dust.global_position = position + Vector3(0, 0.3, 0)
	dust.emitting = true
	_free_after(dust, 1.1)

## Іскри з країв попередження. Вузол — дочірній до зони, тож рухається й
## повертається разом із нею; масштаб зони (розмір кола) йому знімаємо,
## щоб точки задавались у метрах, а іскри не роздувались.
static func _attach_embers(marker: MeshInstance3D, points: PackedVector3Array, color: Color, amount: int) -> void:
	var embers := CPUParticles3D.new()
	embers.amount = amount
	embers.lifetime = 0.9
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	embers.emission_points = points
	embers.direction = Vector3.UP
	embers.spread = 12.0
	embers.gravity = Vector3(0, 0.6, 0)
	embers.initial_velocity_min = 0.7
	embers.initial_velocity_max = 1.6
	embers.scale_amount_min = 0.7
	embers.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	embers.scale_amount_curve = curve
	var hot := Color(1.0, 0.62, 0.25) if _hue_close(color, WARM_HUE) else color.lerp(Color.WHITE, 0.35)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(hot.lerp(Color.WHITE, 0.4), 1.0))
	gradient.set_color(1, Color(hot, 0.0))
	embers.color_ramp = gradient
	embers.mesh = _get_particle_mesh(0.2)
	embers.material_override = _get_particle_material("glow", true)
	marker.add_child(embers)
	embers.scale = Vector3(1.0 / marker.scale.x, 1.0, 1.0 / marker.scale.z)

## Разовий викид частинок з арту (камінці, пил).
static func _make_burst(art: String, color: Color, amount: int, lifetime: float, size: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = lifetime
	particles.mesh = _get_particle_mesh(size)
	particles.material_override = _get_particle_material(art, art != "rock")
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	particles.color = color
	var curve := Curve.new()
	if art == "dust":
		curve.add_point(Vector2(0.0, 0.5))
		curve.add_point(Vector2(1.0, 1.4))
		var gradient := Gradient.new()
		gradient.set_color(0, color)
		gradient.set_color(1, Color(color, 0.0))
		particles.color_ramp = gradient
	else:
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(0.8, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = curve
	return particles

## Колір близький до відтінку арту (або майже сірий — тоді теж не
## перефарбовуємо в "колір", лишаємо арт).
static func _hue_close(color: Color, hue: float) -> bool:
	return absf(wrapf(color.h - hue, -0.5, 0.5)) < 0.075

## Арт віяла/смуги за стихією: крига — "cone_frost"/"line_frost",
## отрута й некромантія — "cone_hex"/"line_hex", решта — арт гравця.
static func _themed_art(color: Color, art: String) -> String:
	var kind := "cone" if art == "cone" else "line"
	match Fx.theme_of(color):
		"ice":
			return kind + "_frost"
		"poison":
			return kind + "_hex"
	return art

static func _get_telegraph_material(art: String, shape: int, color: Color) -> ShaderMaterial:
	var key := "%s|%d|%s" % [art, shape, color.to_html()]
	if _telegraph_materials.has(key):
		return _telegraph_materials[key]
	var material := ShaderMaterial.new()
	material.shader = _shared_shader(TELEGRAPH_SHADER)
	# Нові кола (frost, hex) — з набору ефектів (Fx), решта — арт гравця.
	var path := ("telegraph_" + art) if art.contains("_") else ("telegraph_circle_" + art)
	material.set_shader_parameter(&"art", TELEGRAPH_ART[art] if TELEGRAPH_ART.has(art) else Fx.tex(path))
	material.set_shader_parameter(&"color", color)
	material.set_shader_parameter(&"shape", shape)
	var native := RUNE_HUE if art == "rune" else WARM_HUE
	# Сірий арт фарбуємо завжди; тріщини від фізичного удару (пиловий
	# колір) — теж, інакше вони світились би розпеченою лавою.
	var dust := art == "cracks" and Fx.theme_of(color) == "neutral"
	var grey := art.ends_with("frost") or art.ends_with("hex") or dust
	material.set_shader_parameter(&"keep_hot", 0.0 if dust else 1.0)
	material.set_shader_parameter(&"recolor", 1.0 if grey or not _hue_close(color, native) else 0.0)
	material.set_shader_parameter(&"base", 0.0 if art == "cracks" else 1.0)
	_telegraph_materials[key] = material
	return material

## Матеріал частинки з арту. tinted — арт білий, колір дає сама частинка;
## інакше (камінь) арт кольоровий і лише трохи підфарбовується.
static func _get_particle_material(art: String, additive: bool) -> StandardMaterial3D:
	var key := "%s|%s" % [art, additive]
	if _particle_materials.has(key):
		return _particle_materials[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = PARTICLE_ART[art]
	material.disable_receive_shadows = true
	_particle_materials[key] = material
	return material

static func _get_particle_mesh(size: float) -> QuadMesh:
	var key := snappedf(size, 0.01)
	if not _particle_meshes.has(key):
		var mesh := QuadMesh.new()
		mesh.size = Vector2(key, key)
		_particle_meshes[key] = mesh
	return _particle_meshes[key]

## Удар об землю (фізичний: стрибок, гупання, ривок у землю): тріщини,
## камінці й пил — без вогню й магічних кіл.
static func ground_hit(parent: Node, position: Vector3, radius: float) -> void:
	impact_decal(parent, position, radius, Color(0.42, 0.39, 0.34))

## Клуб диму (телепорт, зникнення, поява): колір магії зберігається.
static func smoke_puff(parent: Node, position: Vector3, color: Color, size: float = 1.4) -> void:
	if claim(position):
		Fx.puff(parent, position, color, size, 0.2)

## Хвиля, що розбігається від центру (вихор героя, удар боса об землю).
## Вигляд — за стихією кольору (Fx.wave): вогняне кільце, крижане, дим...
## Мала хвиля (до 1.7 м) — лише клуб пилу, без кола.
static func shockwave(parent: Node, position: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	if not claim(position, maxf(radius * 0.8, 1.6)):
		return
	Fx.wave(parent, position, radius, color, duration)

## Старе пласке кільце (лишилось для порівняння й запасу).
static func plain_ring(parent: Node, position: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	var instance := make_ground_marker(color, radius)
	parent.add_child(instance)
	instance.global_position = position + Vector3(0, 0.06, 0)
	CombatVfx.set_param(instance, &"wave", 1.0)
	var tween := instance.create_tween()
	tween.tween_method(func(value: float) -> void:
		CombatVfx.set_param(instance, &"progress", value), 0.1, 1.0, duration)
	tween.tween_callback(instance.queue_free)

# --- відчуття удару ---

## "Заморожування" кадру на мить сильного удару — так удар відчувається
## вагомим. Час гри майже зупиняється на кілька сотих секунди.
##
## Кожне "заморожування" отримує свій номер, і швидкість повертає лише
## таймер останнього. Порівнювати час тут не можна: таймер буває
## спрацьовує на кілька мілісекунд раніше, і тоді гра застрягала б в
## уповільненні назавжди.
##
## time_scale — наскільки пригальмувати: 0.25 для удару, трохи більше
## для довгого сповільнення (вбивство боса), щоб воно не тягнулось.
static func hitstop(tree: SceneTree, duration: float, time_scale: float = 0.25) -> void:
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	if Engine.time_scale < 1.0 and until <= _hitstop_until:
		return
	_hitstop_until = until
	_hitstop_token += 1
	var token := _hitstop_token
	# Не повна зупинка, а різке пригальмування: удар відчувається, але
	# картинка не "застигає", що на телефоні сприймалось би як лаг.
	Engine.time_scale = time_scale
	tree.create_timer(duration, true, false, true).timeout.connect(func() -> void:
		if token == _hitstop_token:
			Engine.time_scale = 1.0)

# --- параметри ефекту ---

## Параметр шейдера ОДНОГО ефекту (progress кола, fade, wave...).
##
## ЧОМУ НЕ "instance uniform". На телефоні (gl_compatibility) рушій
## тримає параметри екземплярів у спільному буфері, де кожен такий
## об'єкт займає 16 комірок, а буфер обмежений розміром UBO відеочипа —
## лише кілька сотень об'єктів на весь рівень (кола під кожним ворогом,
## смужки здоров'я, калюжі...). Хто не влазив — читав чужі числа:
## попередження касту блимало й зникало, смужка здоров'я ставала
## чорною. Тепер ефект при першому ж параметрі отримує власну копію
## матеріалу (той самий Shader — нічого не перезбирається), і параметр
## пишеться в неї. Матеріал підмінили (boss_aura міняє колір) — копія
## робиться знову, і всі вже задані параметри переносяться.
static func set_param(node: Node, name: StringName, value: Variant) -> void:
	var geometry := node as GeometryInstance3D
	if geometry == null or not is_instance_valid(geometry):
		return
	var params: Dictionary = geometry.get_meta(&"vfx_params", {})
	params[name] = value
	geometry.set_meta(&"vfx_params", params)
	var material := geometry.material_override as ShaderMaterial
	if material == null:
		return
	if not geometry.has_meta(&"vfx_material") or geometry.get_meta(&"vfx_material") != material:
		material = material.duplicate() as ShaderMaterial
		geometry.material_override = material
		geometry.set_meta(&"vfx_material", material)
		for key: StringName in params:
			material.set_shader_parameter(key, params[key])
	else:
		material.set_shader_parameter(name, value)

# --- спільні ресурси ---

static func _get_material(cache: Dictionary, code: String, color: Color) -> ShaderMaterial:
	var key := "%d|%s" % [code.hash(), color.to_html()]
	if cache.has(key):
		return cache[key]
	var material := ShaderMaterial.new()
	material.shader = _shared_shader(code)
	material.set_shader_parameter(&"color", color)
	cache[key] = material
	return material

## Один Shader на кожен вид ефекту: матеріали різних кольорів ділять його,
## тож відеочип збирає програму малювання ОДИН раз (під екраном
## завантаження, див. прогрів у данжі). Раніше кожен новий колір —
## смерть ворога, портал, шипи — мав свій Shader, і перша поява кольору
## гальмувала гру на збирання: на ПК на 10-25 мс, на телефоні помітним
## ривком.
static func _shared_shader(code: String) -> Shader:
	var key := code.hash()
	if not _shaders.has(key):
		var shader := Shader.new()
		shader.code = code
		_shaders[key] = shader
	return _shaders[key]

static func _get_ring_mesh() -> PlaneMesh:
	if _ring_mesh == null:
		_ring_mesh = PlaneMesh.new()
		_ring_mesh.size = Vector2.ONE
	return _ring_mesh

static func _get_spark_mesh() -> QuadMesh:
	if _spark_mesh == null:
		_spark_mesh = QuadMesh.new()
		_spark_mesh.size = Vector2(0.15, 0.15)
	return _spark_mesh

static func _get_spark_material() -> StandardMaterial3D:
	if _spark_material == null:
		_spark_material = StandardMaterial3D.new()
		_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spark_material.vertex_color_use_as_albedo = true
		_spark_material.disable_receive_shadows = true
		# М'яка світна цятка замість голого квадрата (сліди заклять, сніг,
		# бульбашки отрути — усі частинки, що беруть цей матеріал).
		_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spark_material.albedo_texture = PARTICLE_ART["glow"]
	return _spark_material

static func _get_flare_mesh() -> QuadMesh:
	if _flare_mesh == null:
		_flare_mesh = QuadMesh.new()
		_flare_mesh.size = Vector2(1.0, 1.0)
	return _flare_mesh

## Матеріал спалаху потрібного кольору (шейдер у всіх кольорів спільний).
static func _get_flare_material(color: Color) -> ShaderMaterial:
	return _get_material(_flare_materials, FLARE_SHADER, color)

## Прибрати вузол через кілька секунд. Підписуємо сам метод вузла, а не
## лямбду: якщо вузол зникне раніше (разом із батьком), підписка
## зникне теж, і ніхто не звернеться до видаленого об'єкта.
static func _free_after(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds, false).timeout.connect(node.queue_free)
