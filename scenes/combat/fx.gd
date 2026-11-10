extends RefCounted
class_name Fx

## ЕФЕКТИ З НАБОРІВ (assets/textures/vfx/pack): мальовані покадрові
## анімації (Brackeys VFX Bundle, CC0) і текстури частинок (Kenney Particle
## Pack, CC0; Pixel Dreamer VFX Textures). Усе — пласкі або розвернуті до
## камери чотирикутники й кілька CPU-частинок: без світіння (Glow) і без
## GPU-частинок, тож телефон це тягне.
##
## Ефект добирається за СТИХІЄЮ кольору (theme_of): вогонь, крига, отрута,
## чари, золото, нейтральний пил — тому хвиля вогняного боса й хвиля
## крижаного голема виглядають по-різному, хоч викликаються однаково.

const DIR := "res://assets/textures/vfx/pack/"
## Покадрові анімації: [стовпців, рядків, кадрів].
const FLIPBOOKS := {
	"fire_ring": [6, 5, 30],
	"electric_ring": [6, 5, 30],
	"big_hit": [6, 5, 11],
	"explosion": [6, 5, 27],
}

const FLIPBOOK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D art : source_color, filter_linear, repeat_disable;
uniform vec4 color : source_color = vec4(1.0);
uniform vec2 grid = vec2(6.0, 5.0);
uniform float count = 30.0;
uniform float progress = 0.0;
uniform float fade = 1.0;
// 1 — перефарбувати в color (світлотінь лишається, найяскравіше — біле).
uniform float recolor = 0.0;
uniform float billboard = 0.0;

void vertex() {
	if (billboard > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	float f = min(floor(progress * count), count - 1.0);
	vec2 cell = vec2(mod(f, grid.x), floor(f / grid.x));
	vec4 t = texture(art, (cell + clamp(UV, 0.012, 0.988)) / grid);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	vec3 tinted = mix(color.rgb * (0.35 + lum), vec3(1.0), smoothstep(0.78, 1.0, lum));
	ALBEDO = mix(t.rgb * color.rgb, tinted, recolor);
	ALPHA = clamp(t.a * color.a * fade, 0.0, 1.0);
}
"""

static var _textures := {}
static var _shader: Shader
static var _plane: PlaneMesh
static var _quad: QuadMesh
static var _particle_materials := {}
static var _particle_meshes := {}

static func tex(name: String) -> Texture2D:
	if not _textures.has(name):
		var path := DIR + name + ".png"
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name]

## Стихія за кольором: "fire", "gold", "poison", "ice", "arcane" або "neutral".
static func theme_of(color: Color) -> String:
	# Тьмяні кольори (пил, земля, кістка) — не стихія: інакше бурий пил
	# "горів" вогняним кільцем, а сіро-жовтий — світився золотом.
	if color.s < 0.22 or color.v < 0.7:
		return "neutral"
	var hue := color.h
	if hue < 0.09 or hue > 0.95:
		return "fire"
	if hue < 0.19:
		return "gold"
	if hue < 0.45:
		return "poison"
	if hue < 0.64:
		return "ice"
	return "arcane"

# --- цеглинки ---

static func _mesh(flat: bool) -> Mesh:
	if flat:
		if _plane == null:
			_plane = PlaneMesh.new()
			_plane.size = Vector2.ONE
		return _plane
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad

## Чотирикутник з покадровою анімацією; кадром керує параметр progress
## (0..1). flat — лежить на підлозі, інакше дивиться в камеру.
static func make_flipbook(name: String, color: Color, flat: bool, recolor: bool = false, additive: bool = false) -> MeshInstance3D:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLIPBOOK_SHADER
	var info: Array = FLIPBOOKS[name]
	var material := ShaderMaterial.new()
	material.shader = _shader if not additive else _additive_shader()
	material.set_shader_parameter(&"art", tex("fb_%s_%dx%d" % [name, info[0], info[1]]))
	material.set_shader_parameter(&"color", color)
	material.set_shader_parameter(&"grid", Vector2(info[0], info[1]))
	material.set_shader_parameter(&"count", float(info[2]))
	material.set_shader_parameter(&"recolor", 1.0 if recolor else 0.0)
	material.set_shader_parameter(&"billboard", 0.0 if flat else 1.0)
	var node := MeshInstance3D.new()
	node.mesh = _mesh(flat)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static var _add_shader: Shader

static func _additive_shader() -> Shader:
	if _add_shader == null:
		_add_shader = Shader.new()
		_add_shader.code = FLIPBOOK_SHADER.replace("render_mode unshaded,", "render_mode unshaded, blend_add,")
	return _add_shader

static func set_progress(node: MeshInstance3D, progress: float, fade: float = 1.0) -> void:
	if not is_instance_valid(node):
		return
	var material := node.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"progress", progress)
		material.set_shader_parameter(&"fade", fade)

## Разова покадрова анімація: програлась за time секунд і зникла.
## grow_from — з якої частки розміру виростає (1 — не росте).
static func flipbook(parent: Node, position: Vector3, name: String, size: float, color: Color, time: float,
		flat: bool = false, recolor: bool = false, additive: bool = false, grow_from: float = 1.0) -> MeshInstance3D:
	var node := make_flipbook(name, color, flat, recolor, additive)
	parent.add_child(node)
	node.global_position = position
	node.scale = Vector3.ONE * size * grow_from
	if flat:
		node.rotation.y = randf() * TAU
	var tween := node.create_tween().set_parallel(true)
	tween.tween_method(func(value: float) -> void:
		set_progress(node, value, 1.0 - smoothstep(0.75, 1.0, value)), 0.0, 1.0, time)
	if grow_from != 1.0:
		tween.tween_property(node, "scale", Vector3.ONE * size, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_callback(node.queue_free)
	return node

## Одна текстура на чотирикутнику (зі своїм матеріалом — колір і
## прозорість можна анімувати через material_override.albedo_color).
static func make_sprite(name: String, color: Color, flat: bool, additive: bool = false) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = tex("k_" + name)
	material.albedo_color = color
	material.disable_receive_shadows = true
	material.no_depth_test = false
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if not flat:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true
	var node := MeshInstance3D.new()
	node.mesh = _mesh(flat)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

## Текстура, що виростає, обертається й тане (хвиля диму, магічне кільце).
static func bloom(parent: Node, position: Vector3, name: String, size: float, color: Color, time: float,
		flat: bool = true, additive: bool = false, grow_from: float = 0.3, turn: float = 0.6) -> MeshInstance3D:
	var node := make_sprite(name, color, flat, additive)
	parent.add_child(node)
	node.global_position = position
	node.scale = Vector3.ONE * size * grow_from
	node.rotation.y = randf() * TAU
	var material := node.material_override as StandardMaterial3D
	var tween := node.create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector3.ONE * size, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if flat and turn != 0.0:
		tween.tween_property(node, "rotation:y", node.rotation.y + turn, time)
	tween.tween_property(material, "albedo_color:a", 0.0, time * 0.55).set_delay(time * 0.45)
	tween.chain().tween_callback(node.queue_free)
	return node

static func _particle_material(name: String, additive: bool) -> StandardMaterial3D:
	var key := "%s|%s" % [name, additive]
	if not _particle_materials.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if additive:
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = tex("k_" + name)
		material.disable_receive_shadows = true
		_particle_materials[key] = material
	return _particle_materials[key]

static func _particle_mesh(size: float) -> QuadMesh:
	var key := snappedf(size, 0.02)
	if not _particle_meshes.has(key):
		var mesh := QuadMesh.new()
		mesh.size = Vector2(key, key)
		_particle_meshes[key] = mesh
	return _particle_meshes[key]

## Частинки з текстури набору. Викликач сам задає форму викиду й додає в сцену.
static func make_particles(name: String, color: Color, amount: int, lifetime: float, size: float,
		additive: bool = false, fade_in: bool = false) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.mesh = _particle_mesh(size)
	particles.material_override = _particle_material(name, additive)
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.3
	var gradient := Gradient.new()
	if fade_in:
		gradient.set_color(0, Color(color, 0.0))
		gradient.add_point(0.25, color)
	else:
		gradient.set_color(0, color)
	gradient.set_color(gradient.get_point_count() - 1, Color(color, 0.0))
	particles.color_ramp = gradient
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles

static func _free_later(node: Node, seconds: float) -> void:
	# Метод вузла, а не лямбда: якщо вузол зник раніше, Godot сам розірве
	# зв'язок (лямбда зі знищеним вузлом сипала помилку в лог).
	node.get_tree().create_timer(seconds, false).timeout.connect(node.queue_free)

# --- готові ефекти ---

## Клуб диму чи пилу (малий удар об землю, смерть ворога): кілька м'яких
## клубків, що розходяться й тануть. Без кіл.
static func puff(parent: Node, position: Vector3, color: Color, size: float = 1.0, earthy: float = 0.55) -> void:
	var tint := color.lerp(Color(0.82, 0.78, 0.72), earthy)
	var smoke := make_particles("smoke_04", Color(tint, 0.4), 3, 0.5, 0.8 * size)
	smoke.one_shot = true
	smoke.explosiveness = 1.0
	smoke.direction = Vector3.UP
	smoke.spread = 85.0
	smoke.flatness = 0.7
	smoke.initial_velocity_min = 0.8 * size
	smoke.initial_velocity_max = 2.0 * size
	smoke.damping_min = 2.0
	smoke.damping_max = 3.0
	smoke.gravity = Vector3(0, 0.6, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.3))
	smoke.scale_amount_curve = curve
	parent.add_child(smoke)
	smoke.global_position = position
	smoke.emitting = true
	_free_later(smoke, 0.8)

## ХВИЛЯ по підлозі (замість плаского кільця): за стихією кольору —
## вогняне кільце, крижано-електричне, отруйний дим, магічний круг, пил.
## Мала (радіус < 1.7 м) — лише клуб пилу: кіл від кожного удару немає.
static func wave(parent: Node, position: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	if radius < 1.7:
		puff(parent, position + Vector3.UP * 0.25, color, clampf(radius, 0.6, 1.2))
		return
	var ground := Vector3(position.x, position.y + 0.08, position.z)
	var time := maxf(duration, 0.3) + 0.15
	# Мінімалізм: один шар, напівпрозорий; без розльоту частинок.
	var a := 0.55 * color.a
	match theme_of(color):
		"fire":
			# Анімоване вогняне кільце — лише мале (вибух поруч): велике
			# розсипається на пікселі. Велика хвиля — м'яке кільце диму й жару.
			if radius <= 3.0:
				flipbook(parent, ground, "fire_ring", radius * 2.1, Color(1, 1, 1, 0.7 * color.a), time, true, false, false, 0.3)
			else:
				bloom(parent, ground, "smoke_10", radius * 2.2, Color(color.lerp(Color(1.0, 0.8, 0.5), 0.3), a), time)
		"ice":
			bloom(parent, ground, "smoke_10", radius * 2.2, Color(color.lerp(Color.WHITE, 0.4), a), time)
		"poison":
			bloom(parent, ground, "smoke_10", radius * 1.6, Color(color.darkened(0.15), a * 0.8), time + 0.1)
		"arcane":
			bloom(parent, ground, "light_02", radius * 2.1, Color(color.lerp(Color.WHITE, 0.2), a), time, true, true)
		"gold":
			bloom(parent, ground, "circle_03", radius * 2.0, Color(color.lerp(Color.WHITE, 0.2), a), time, true, true)
		_:
			bloom(parent, ground, "smoke_10", radius * 2.2, Color(color.lerp(Color(0.8, 0.76, 0.7), 0.5), 0.45 * color.a), time)

## Кілька частинок, що розлітаються колом від центру хвилі.
static func _ring_burst(parent: Node, position: Vector3, radius: float, name: String, color: Color, additive: bool) -> void:
	var particles := make_particles(name, color, clampi(int(radius * 3.0), 6, 14), 0.5, 0.4, additive)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_axis = Vector3.UP
	particles.emission_ring_radius = radius * 0.35
	particles.emission_ring_inner_radius = radius * 0.25
	particles.emission_ring_height = 0.05
	particles.direction = Vector3.UP
	particles.spread = 80.0
	particles.flatness = 0.8
	particles.initial_velocity_min = radius * 1.2
	particles.initial_velocity_max = radius * 2.0
	particles.damping_min = radius * 2.0
	particles.damping_max = radius * 3.0
	particles.gravity = Vector3(0, 1.5, 0)
	parent.add_child(particles)
	particles.global_position = position + Vector3.UP * 0.15
	particles.emitting = true
	_free_later(particles, 0.8)

## КІЛЬЦЕ, що біжить по підлозі (удар боса об землю, HazardRing): вузол і
## частинки на фронті хвилі. Радіус щокадру задає update_ring.
static func make_ring(color: Color) -> Node3D:
	var holder := Node3D.new()
	var theme := theme_of(color)
	# Мінімалізм: одне м'яке кільце (без анімованих "вирів" — розтягнуті
	# на десятки метрів, вони розсипались на пікселі й мерехтіли).
	var tint := color.lerp(Color.WHITE, 0.45) if theme == "ice" else color.lerp(Color(0.8, 0.8, 0.8), 0.2)
	var band := make_sprite("smoke_10", Color(tint, 0.8), true)
	holder.set_meta(&"fit", 2.5)
	band.name = "Band"
	holder.add_child(band)
	var art := {"fire": "flame_05", "ice": "star_04", "poison": "smoke_04"}
	var trail := make_particles(art.get(theme, "spark_04"), color.lerp(Color.WHITE, 0.35), 10, 0.45, 0.4, theme != "poison")
	trail.name = "Trail"
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	trail.emission_ring_axis = Vector3.UP
	trail.emission_ring_height = 0.05
	trail.direction = Vector3.UP
	trail.spread = 20.0
	trail.initial_velocity_min = 0.6
	trail.initial_velocity_max = 1.6
	trail.gravity = Vector3(0, 1.0, 0)
	trail.position.y = 0.1
	holder.add_child(trail)
	return holder

static func update_ring(holder: Node3D, radius: float, age: float, fade: float = 1.0) -> void:
	var band := holder.get_node("Band") as MeshInstance3D
	var size := maxf(radius, 0.05) * float(holder.get_meta(&"fit", 2.4))
	band.scale = Vector3(size, 1.0, size)
	if band.material_override is ShaderMaterial:
		set_progress(band, fposmod(age * 1.1, 1.0), fade)
	else:
		band.rotation.y = age * 0.8
		(band.material_override as StandardMaterial3D).albedo_color.a = 0.85 * fade
	var trail := holder.get_node("Trail") as CPUParticles3D
	trail.emission_ring_radius = radius
	trail.emission_ring_inner_radius = maxf(radius - 0.25, 0.0)

## КАЛЮЖА на підлозі (вогонь після глечика, отрута після Розкладеної
## плоті): темна пляма, по краю — дим, усередині — язики полум'я або
## отруйні бульбашки. Без обведеного кола: край видно за плямою й димом.
static func make_pool(color: Color, radius: float) -> Node3D:
	var holder := Node3D.new()
	var fire := theme_of(color) in ["fire", "gold"]
	# Темна пляма з нерівним краєм: два клуби диму, що повільно обертаються.
	for k in 2:
		var stain := make_sprite("smoke_07" if k == 0 else "smoke_04",
			Color(0.1, 0.05, 0.03, 0.85) if fire else Color(color.darkened(0.62 - 0.2 * k), 0.8 - 0.25 * k), true)
		stain.scale = Vector3.ONE * radius * (2.5 - 0.5 * k)
		stain.position.y = 0.02 + 0.02 * k
		holder.add_child(stain)
		var spin := stain.create_tween().set_loops()
		spin.tween_property(stain, "rotation:y", TAU * (1.0 if k == 0 else -1.0), 12.0 - 4.0 * k).from(0.0)
	var amount := clampi(int(radius * radius * 3.0), 6, 16)
	var rise: CPUParticles3D
	if fire:
		# Жар у серці плями й язики полум'я по всій калюжі.
		var glow := make_sprite("circle_05", Color(1.0, 0.45, 0.1, 0.55), true, true)
		glow.scale = Vector3.ONE * radius * 2.0
		glow.position.y = 0.06
		holder.add_child(glow)
		var pulse := glow.create_tween().set_loops()
		pulse.tween_property(glow, "scale", Vector3.ONE * radius * 2.3, 0.35)
		pulse.tween_property(glow, "scale", Vector3.ONE * radius * 1.9, 0.35)
		rise = make_particles("flame_05", Color(1.0, 0.7, 0.25), amount, 0.6, 1.6, true, true)
		rise.initial_velocity_min = 0.5
		rise.initial_velocity_max = 1.4
		rise.gravity = Vector3(0, 2.5, 0)
		rise.angle_max = 0.0
	else:
		rise = make_particles("smoke_04", Color(color.lightened(0.15), 0.35), maxi(amount / 2, 4), 1.1, 0.7, false, true)
		rise.initial_velocity_min = 0.2
		rise.initial_velocity_max = 0.6
		rise.gravity = Vector3(0, 0.5, 0)
		var bubbles := make_particles("circle_03", Color(color.lightened(0.45), 0.95), 7, 0.7, 0.3, true, true)
		bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		bubbles.emission_ring_axis = Vector3.UP
		bubbles.emission_ring_radius = radius * 0.8
		bubbles.emission_ring_inner_radius = 0.0
		bubbles.emission_ring_height = 0.02
		bubbles.direction = Vector3.UP
		bubbles.spread = 5.0
		bubbles.initial_velocity_min = 0.3
		bubbles.initial_velocity_max = 0.8
		bubbles.gravity = Vector3.ZERO
		bubbles.position.y = 0.12
		holder.add_child(bubbles)
	rise.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	rise.emission_ring_axis = Vector3.UP
	rise.emission_ring_radius = radius * 0.85
	rise.emission_ring_inner_radius = 0.0
	rise.emission_ring_height = 0.02
	rise.direction = Vector3.UP
	rise.spread = 12.0
	rise.position.y = 0.2
	holder.add_child(rise)
	return holder

## ВИХОР клинків довкола героя: три шари завитків, що обертаються на різній
## висоті, смуги вітру по колу й пил із-під ніг. Чіпляється до host і
## рухається разом із ним; сам зникає за time секунд.
static func whirl(host: Node3D, radius: float, color: Color, time: float) -> void:
	var holder := Node3D.new()
	host.add_child(holder)
	holder.position = Vector3.ZERO
	var layers := [["twirl_03", 0.8, 2.0, 0.0, 0.8]]
	var total := time + 0.2
	for layer: Array in layers:
		var tint := color.lerp(Color.WHITE, 0.35)
		var node := make_sprite(String(layer[0]), Color(tint, 0.0), true, true)
		holder.add_child(node)
		node.position.y = float(layer[1])
		node.rotation.y = float(layer[3])
		node.scale = Vector3.ONE * radius * float(layer[2]) * 0.45
		var material := node.material_override as StandardMaterial3D
		var tween := node.create_tween().set_parallel(true)
		tween.tween_property(node, "scale", Vector3.ONE * radius * float(layer[2]), total).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(material, "albedo_color:a", float(layer[4]), total * 0.2)
		tween.tween_property(material, "albedo_color:a", 0.0, total * 0.45).set_delay(total * 0.55)
	# Увесь вихор крутиться (а з ним — і смуги вітру в його системі координат).
	var spin := holder.create_tween()
	spin.tween_property(holder, "rotation:y", -TAU * 2.2, total).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	spin.tween_callback(holder.queue_free)
	var streaks := make_particles("trace_01", color.lerp(Color.WHITE, 0.6), 16, total * 0.7, 0.9, true, true)
	streaks.local_coords = true
	streaks.one_shot = true
	streaks.explosiveness = 0.6
	streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	streaks.emission_ring_axis = Vector3.UP
	streaks.emission_ring_radius = radius * 0.85
	streaks.emission_ring_inner_radius = radius * 0.45
	streaks.emission_ring_height = 1.4
	streaks.direction = Vector3.UP
	streaks.spread = 10.0
	streaks.initial_velocity_min = 0.2
	streaks.initial_velocity_max = 0.8
	streaks.gravity = Vector3.ZERO
	streaks.angle_max = 0.0
	streaks.position.y = 0.9
	holder.add_child(streaks)
	streaks.emitting = false
	streaks.queue_free()


# --- снаряди й промені ---

const TRAIL_ART := {"fire": "flame_05", "ice": "star_04", "poison": "smoke_04", "arcane": "circle_05",
	"gold": "spark_04", "neutral": "smoke_04"}

## Вигляд снаряда (чіпляється до вузла снаряда): м'який ореол, що дихає, і
## слід за стихією — язики полум'я, сніжинки-іскри, зелений дим, світні
## цятки. Слід лишається в повітрі (не летить разом зі снарядом).
static func make_projectile(color: Color, size: float = 1.0) -> Node3D:
	var holder := Node3D.new()
	holder.name = "ShotFx"
	var theme := theme_of(color)
	var halo := make_sprite("circle_05", Color(color.lerp(Color.WHITE, 0.2), 0.95), false, true)
	halo.scale = Vector3.ONE * 0.9 * size
	holder.add_child(halo)
	var pulse := halo.create_tween().set_loops()
	pulse.tween_property(halo, "scale", Vector3.ONE * 1.1 * size, 0.18)
	pulse.tween_property(halo, "scale", Vector3.ONE * 0.85 * size, 0.18)
	var additive := theme != "poison" and theme != "neutral"
	var tint := color.lerp(Color.WHITE, 0.25) if additive else Color(color.lightened(0.1), 0.6)
	var trail := make_particles(TRAIL_ART[theme], tint, 16, 0.4, 0.5 * size, additive)
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.08 * size
	trail.direction = Vector3.UP
	trail.spread = 180.0
	trail.initial_velocity_min = 0.05
	trail.initial_velocity_max = 0.35
	trail.gravity = Vector3(0, 0.8 if theme == "fire" else 0.0, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.1))
	trail.scale_amount_curve = curve
	holder.add_child(trail)
	return holder

## Снаряд розбився (об стіну чи героя): без спалаху — розліт частинок своєї
## стихії й малий клуб диму, а вогонь — мальований вибух.
static func projectile_hit(parent: Node, position: Vector3, color: Color, big: bool = false) -> void:
	var theme := theme_of(color)
	var size := 1.5 if big else 1.0
	if theme == "fire":
		flipbook(parent, position, "explosion", 1.3 * size, Color.WHITE, 0.3)
		return
	var additive := theme != "poison" and theme != "neutral"
	var particles := make_particles(TRAIL_ART[theme], color.lerp(Color.WHITE, 0.3), int(9 * size), 0.35, 0.4 * size, additive)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 3.5 * size
	particles.damping_min = 4.0
	particles.damping_max = 6.0
	particles.gravity = Vector3(0, -3.0, 0)
	parent.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	_free_later(particles, 0.6)
	if theme in ["poison", "neutral"]:
		puff(parent, position, color, 0.7 * size)

## Шейдер енергетичного променя: яскраве біле серце, кольорові краї й
## хвилі енергії, що біжать від основи до кінця.
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.4, 0.2, 1.0);
uniform float power = 1.0;
uniform float span = 10.0;
void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.0, 0.35, across);
	float edge = 1.0 - smoothstep(0.3, 1.0, across);
	float flow = 0.65 + 0.35 * sin(UV.y * span * 3.0 - TIME * 18.0);
	float flicker = 0.85 + 0.15 * sin(TIME * 41.0 + UV.y * 7.0);
	float tip = smoothstep(0.0, 0.04, UV.y) * (1.0 - smoothstep(0.92, 1.0, UV.y));
	vec3 rgb = mix(color.rgb, vec3(1.0), core * 0.85);
	ALBEDO = rgb * (0.7 + 0.6 * flow);
	ALPHA = clamp(edge * flow * flicker * tip * power, 0.0, 1.0);
}
"""
static var _beam_shader: Shader

## Енергетичний промінь уздовж +Z вузла: дві схрещені стрічки зі світним
## серцем і хвилями енергії, по ньому сиплються іскри. Розмір — set_beam.
static func make_beam(color: Color) -> Node3D:
	if _beam_shader == null:
		_beam_shader = Shader.new()
		_beam_shader.code = BEAM_SHADER
	var holder := Node3D.new()
	var material := ShaderMaterial.new()
	material.shader = _beam_shader
	material.set_shader_parameter(&"color", color)
	holder.set_meta(&"material", material)
	for k in 2:
		var strip := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		quad.center_offset = Vector3(0, 0.5, 0)
		strip.mesh = quad
		strip.material_override = material
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strip.name = "Strip%d" % k
		holder.add_child(strip)
	var sparks := make_particles("spark_04", color.lerp(Color.WHITE, 0.4), 14, 0.35, 0.35, true)
	sparks.name = "Sparks"
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 0.5
	sparks.initial_velocity_max = 2.0
	sparks.gravity = Vector3.ZERO
	holder.add_child(sparks)
	return holder

## Довжина й товщина променя (метри) уздовж +Z, power — яскравість (0..1).
static func set_beam(holder: Node3D, length: float, width: float, power: float) -> void:
	var material: ShaderMaterial = holder.get_meta(&"material")
	material.set_shader_parameter(&"power", power)
	material.set_shader_parameter(&"span", length)
	for k in 2:
		var strip := holder.get_node("Strip%d" % k) as MeshInstance3D
		# Стрічка лежить уздовж +Z: перша пласко, друга — сторч.
		strip.basis = Basis(Vector3.FORWARD, PI * 0.5 * k) * Basis(Vector3.RIGHT, PI * 0.5) \
			* Basis.from_scale(Vector3(width * 1.8, length, 1.0))
	var sparks := holder.get_node("Sparks") as CPUParticles3D
	sparks.emission_box_extents = Vector3(width * 0.3, width * 0.3, length * 0.5)
	sparks.position = Vector3(0, 0, length * 0.5)
	sparks.emitting = power > 0.6


# --- прийоми бос (набір Obssidian Free Combat VFX) ---

## Сцени набору: вогняний цвіт, водяна корона, темні стрічки, золотий серп,
## блискавичний гарпун.
const SIGNATURES := {
	"inferno_bloom": ["res://addons/obssidian_free_vfx/scenes/inferno_bloom.tscn", 0.94],
	"tidal_crown": ["res://addons/obssidian_free_vfx/scenes/tidal_crown.tscn", 0.91],
	"abyssal_tether": ["res://addons/obssidian_free_vfx/scenes/abyssal_tether.tscn", 1.05],
	"helios_recall": ["res://addons/obssidian_free_vfx/scenes/helios_recall.tscn", 0.88],
	"storm_piercer": ["res://addons/obssidian_free_vfx/scenes/storm_piercer.tscn", 0.73],
}

## Прийом із набору: летить від from до target (світові точки), удар —
## через contact_in секунд (під нього підганяється швидкість). size —
## множник розміру (набір зроблений під героя ~2 м). tint — свій колір
## (прозорий — рідний колір ефекту). Без спалаху й лампи. Сам зникає.
static func signature(parent: Node, kind: String, from: Vector3, target: Vector3, contact_in: float,
		size: float = 1.0, tint: Color = Color(0, 0, 0, 0)) -> Node3D:
	var info: Array = SIGNATURES[kind]
	var fx: Node3D = load(String(info[0])).instantiate()
	fx.set("auto_play", false)
	fx.set("contact_flash", false)
	if tint.a > 0.0:
		fx.set("use_custom_color", true)
		fx.set("custom_color", tint)
	parent.add_child(fx)
	fx.global_position = target
	fx.scale = Vector3.ONE * size
	fx.set("source_position", fx.to_local(from))
	fx.set("target_position", fx.to_local(target) + Vector3.UP * 0.05)
	fx.set("playback_speed", clampf(float(info[1]) / maxf(contact_in, 0.05), 0.4, 2.0))
	fx.call("play")
	fx.connect("finished", fx.queue_free)
	return fx
