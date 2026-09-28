extends RefCounted
class_name CombatVfx

## Ефекти бою: слід меча, іскри влучання, цифри шкоди, кола-попередження
## на підлозі, "заморожування" кадру при сильному ударі.
##
## Усе зроблено кодом і шейдерами, без текстур: так ефекти однаково
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
instance uniform float progress = 0.0;
instance uniform float reverse_dir = 0.0;
instance uniform float intensity = 1.0;

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
instance uniform float progress = 0.0;
instance uniform float half_arc = 3.1416;
instance uniform float wave = 0.0;
instance uniform float fade = 1.0;

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
instance uniform float progress = 0.0;

void fragment() {
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float border = 1.0 - smoothstep(0.03, 0.08, edge);
	float fill = step(UV.y, progress);
	ALBEDO = color.rgb;
	ALPHA = clamp(max(border * 0.9, fill * 0.42 + 0.08), 0.0, 1.0) * color.a;
}
"""

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

const SLASH_SEGMENTS := 26

static var _slash_meshes: Dictionary = {}
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
	instance.set_instance_shader_parameter(&"reverse_dir", 1.0 if reverse else 0.0)
	instance.set_instance_shader_parameter(&"progress", 0.0)
	var tween := instance.create_tween()
	tween.tween_method(func(value: float) -> void:
		instance.set_instance_shader_parameter(&"progress", value), 0.0, 1.4, duration)
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
static func impact(parent: Node, position: Vector3, color: Color, big: bool = false) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 18 if big else 10
	particles.lifetime = 0.42 if big else 0.3
	particles.mesh = _get_spark_mesh()
	particles.material_override = _get_spark_material()
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

	var flare := MeshInstance3D.new()
	flare.mesh = _get_flare_mesh()
	flare.material_override = _get_flare_material(color)
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flare)
	flare.global_position = position
	flare.scale = Vector3.ONE * (0.4 if big else 0.25)
	var tween := flare.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flare, "scale", Vector3.ONE * (1.8 if big else 1.1), 0.14)
	tween.tween_property(flare, "transparency", 1.0, 0.14)
	tween.chain().tween_callback(flare.queue_free)

## Спалах пострілу біля ствола: коротка яскрава зірка й кілька іскор
## уздовж напрямку. Без справжнього світла — телефон його не потягне на
## кожному пострілі, а видно однаково добре.
static func muzzle_flash(parent: Node, position: Vector3, direction: Vector3, color: Color) -> void:
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

	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 5
	sparks.lifetime = 0.16
	sparks.mesh = _get_spark_mesh()
	sparks.material_override = _get_spark_material()
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
## через set_instance_shader_parameter.
static func make_ground_marker(color: Color, radius: float, half_arc: float = PI) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _get_ring_mesh()
	instance.material_override = _get_material(_ring_materials, RING_SHADER, color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.scale = Vector3(radius * 2.0, 1.0, radius * 2.0)
	instance.set_instance_shader_parameter(&"half_arc", half_arc)
	instance.set_instance_shader_parameter(&"progress", 0.0)
	return instance

## Смуга-попередження для тарана. length — довжина ривку, width — ширина.
static func make_line_marker(color: Color, length: float, width: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _get_ring_mesh()
	instance.material_override = _get_material(_line_materials, LINE_SHADER, color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.scale = Vector3(width, 1.0, length)
	instance.set_instance_shader_parameter(&"progress", 0.0)
	return instance

## Хвиля, що розбігається від центру (вихор героя, удар боса об землю).
static func shockwave(parent: Node, position: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	var instance := make_ground_marker(color, radius)
	parent.add_child(instance)
	instance.global_position = position + Vector3(0, 0.06, 0)
	instance.set_instance_shader_parameter(&"wave", 1.0)
	var tween := instance.create_tween()
	tween.tween_method(func(value: float) -> void:
		instance.set_instance_shader_parameter(&"progress", value), 0.1, 1.0, duration)
	tween.tween_callback(instance.queue_free)

# --- відчуття удару ---

## "Заморожування" кадру на мить сильного удару — так удар відчувається
## вагомим. Час гри майже зупиняється на кілька сотих секунди.
##
## Кожне "заморожування" отримує свій номер, і швидкість повертає лише
## таймер останнього. Порівнювати час тут не можна: таймер буває
## спрацьовує на кілька мілісекунд раніше, і тоді гра застрягала б в
## уповільненні назавжди.
static func hitstop(tree: SceneTree, duration: float) -> void:
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	if Engine.time_scale < 1.0 and until <= _hitstop_until:
		return
	_hitstop_until = until
	_hitstop_token += 1
	var token := _hitstop_token
	# Не повна зупинка, а різке пригальмування: удар відчувається, але
	# картинка не "застигає", що на телефоні сприймалось би як лаг.
	Engine.time_scale = 0.25
	tree.create_timer(duration, true, false, true).timeout.connect(func() -> void:
		if token == _hitstop_token:
			Engine.time_scale = 1.0)

# --- спільні ресурси ---

static func _get_material(cache: Dictionary, code: String, color: Color) -> ShaderMaterial:
	var key := "%d|%s" % [code.hash(), color.to_html()]
	if cache.has(key):
		return cache[key]
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"color", color)
	cache[key] = material
	return material

static func _get_ring_mesh() -> PlaneMesh:
	if _ring_mesh == null:
		_ring_mesh = PlaneMesh.new()
		_ring_mesh.size = Vector2.ONE
	return _ring_mesh

static func _get_spark_mesh() -> QuadMesh:
	if _spark_mesh == null:
		_spark_mesh = QuadMesh.new()
		_spark_mesh.size = Vector2(0.09, 0.09)
	return _spark_mesh

static func _get_spark_material() -> StandardMaterial3D:
	if _spark_material == null:
		_spark_material = StandardMaterial3D.new()
		_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spark_material.vertex_color_use_as_albedo = true
		_spark_material.disable_receive_shadows = true
	return _spark_material

static func _get_flare_mesh() -> QuadMesh:
	if _flare_mesh == null:
		_flare_mesh = QuadMesh.new()
		_flare_mesh.size = Vector2(1.0, 1.0)
	return _flare_mesh

## Спалах — м'яка зірка, намальована в шейдері як яскравий центр з
## променями.
static func _get_flare_material(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if _flare_materials.has(key):
		return _flare_materials[key]
	var shader := Shader.new()
	shader.code = """
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
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"color", color)
	_flare_materials[key] = material
	return material

## Прибрати вузол через кілька секунд. Підписуємо сам метод вузла, а не
## лямбду: якщо вузол зникне раніше (разом із батьком), підписка
## зникне теж, і ніхто не звернеться до видаленого об'єкта.
static func _free_after(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds, false).timeout.connect(node.queue_free)
