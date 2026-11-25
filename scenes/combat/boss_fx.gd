extends RefCounted
class_name BossFx

## ЕФЕКТИ БОСІВ: свої матеріали й моделі для прийомів кожного боса, щоб
## замість однакових кульок, брусків і кілець було видно, ЩО саме
## відбувається: лава тече, вода брижиться, крига відблискує, з неба
## падає кам'яна долоня. Усе процедурне (без нових файлів), шейдери
## прості — для GL Compatibility і слабкого телефона. Матеріали спільні
## (кеш), сітки — теж, тож ефект не плодить ресурси щоразу.

const NOISE := """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
"""

## Лава: темна кірка з розжареними щілинами, що повільно течуть. heat —
## наскільки розжарена (0 — холодний базальт), alpha — прозорість.
const LAVA := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
uniform float heat = 1.0;
uniform float alpha = 1.0;
uniform float crust = 0.52;
uniform float scale = 0.9;
uniform vec2 flow = vec2(0.0, 0.25);
varying vec3 wpos;
%s
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// Темна кірка з тонкими розжареними жилами (де шум ~0.5) і рідкими
	// озерцями жару. heat 0 — холодний базальт.
	vec2 p = wpos.xz * scale * 1.6 + vec2(wpos.y * 0.9, 0.0);
	float warp = fbm(p * 0.8 - TIME * 0.08);
	float n = fbm(p + warp * 1.2 + flow * TIME * 0.5);
	float contour = abs(fract(n * 3.0) - 0.5);
	float vein = 1.0 - smoothstep(0.02, 0.07 + 0.05 * heat, contour);
	float pool = smoothstep(0.66, 0.72, n) * 0.8;
	float lava = clamp(vein + pool, 0.0, 1.0) * heat;
	vec3 rock = mix(vec3(0.025, 0.018, 0.016), vec3(0.09, 0.05, 0.04), fbm(p * 2.5));
	vec3 hot = mix(vec3(1.0, 0.22, 0.0), vec3(1.0, 0.62, 0.12), vein * vein) * 1.4;
	ALBEDO = rock + vec3(0.12, 0.02, 0.0) * heat + hot * lava;
	ALPHA = alpha;
}
"""

## Вода (і будь-яка "рідина", що тече): брижі й піна. flow — куди
## тече (м/с у світі), deep/shallow — кольори.
const WATER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 deep : source_color = vec4(0.04, 0.16, 0.14, 0.85);
uniform vec4 shallow : source_color = vec4(0.18, 0.42, 0.34, 0.85);
uniform vec4 foam_color : source_color = vec4(0.75, 0.9, 0.8, 0.9);
uniform vec2 flow = vec2(0.0, 0.0);
uniform float alpha = 1.0;
uniform float foam = 1.0;
varying vec3 wpos;
%s
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// Повільні м'які переливи (без плям) і тонкі лінії бриж.
	vec2 p = wpos.xz * 0.35 - flow * TIME * 0.35;
	float n = fbm(p + fbm(p * 1.3 + TIME * 0.08) * 0.6);
	vec4 col = mix(deep, shallow, smoothstep(0.3, 0.7, n));
	float ripple = sin((wpos.x + wpos.z) * 2.2 + n * 9.0 - TIME * 2.0 - dot(flow, wpos.xz) * 2.0);
	float lines = smoothstep(0.92, 1.0, ripple) * foam * 0.45;
	col.rgb = mix(col.rgb, foam_color.rgb, lines);
	ALBEDO = col.rgb;
	ALPHA = col.a * alpha;
}
"""

## Крига: напівпрозора, з білим відблиском по краях і тріщинами.
const ICE := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, blend_mix;
uniform vec4 tint : source_color = vec4(0.55, 0.8, 1.0, 0.82);
uniform sampler2D cracks : source_color, filter_linear_mipmap, repeat_enable;
uniform float alpha = 1.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float crack = texture(cracks, wpos.xy * 0.35 + wpos.zy * 0.35).a;
	vec3 col = mix(tint.rgb * 0.75, vec3(0.95, 0.99, 1.0), rim * 0.9 + crack * 0.35);
	ALBEDO = col;
	ALPHA = clamp(tint.a + rim * 0.3, 0.0, 1.0) * alpha;
}
"""

## Порожнеча / привид: темна напівпрозора постать із барвистим обідком і
## мерехтінням.
const GHOST := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, blend_mix;
uniform vec4 rim_color : source_color = vec4(0.65, 0.3, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.05, 0.0, 0.1, 0.55);
uniform float alpha = 1.0;
varying vec3 wpos;
%s
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	float flick = fbm(wpos.xy * 3.0 + vec2(0.0, -TIME * 1.5));
	vec3 col = mix(core_color.rgb, rim_color.rgb, rim);
	ALBEDO = col;
	ALPHA = clamp(core_color.a + rim * 0.8, 0.0, 1.0) * (0.75 + 0.25 * flick) * alpha;
}
"""

static var _shaders := {}
static var _materials := {}
static var _meshes := {}

static func _shader(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var shader := Shader.new()
		shader.code = code % NOISE if code.contains("%s") else code
		_shaders[key] = shader
	return _shaders[key]

## Новий екземпляр матеріалу (параметри — свої для кожного ефекту).
static func lava_material(heat: float = 1.0, alpha: float = 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader("lava", LAVA)
	material.set_shader_parameter(&"heat", heat)
	material.set_shader_parameter(&"alpha", alpha)
	if alpha < 0.999:
		material.render_priority = 1
	return material

static func water_material(deep: Color, shallow: Color, flow: Vector2 = Vector2.ZERO, foam := 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader("water", WATER)
	material.set_shader_parameter(&"deep", deep)
	material.set_shader_parameter(&"shallow", shallow)
	material.set_shader_parameter(&"flow", flow)
	material.set_shader_parameter(&"foam", foam)
	return material

static func ice_material(tint: Color = Color(0.55, 0.8, 1.0, 0.82)) -> ShaderMaterial:
	var key := "ice|" + tint.to_html()
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = _shader("ice", ICE)
		material.set_shader_parameter(&"tint", tint)
		material.set_shader_parameter(&"cracks", Fx.art("se_crack_01"))
		_materials[key] = material
	return _materials[key]

static func ghost_material(rim: Color, core: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader("ghost", GHOST)
	material.set_shader_parameter(&"rim_color", rim)
	material.set_shader_parameter(&"core_color", core)
	return material

static func _lit(color: Color, metallic := 0.0, roughness := 0.8, glow := Color.BLACK) -> StandardMaterial3D:
	var key := "lit|%s|%.2f|%.2f|%s" % [color.to_html(), metallic, roughness, glow.to_html()]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = metallic
		material.roughness = roughness
		if glow != Color.BLACK:
			material.emission_enabled = true
			material.emission = glow
		_materials[key] = material
	return _materials[key]

static func _part(parent: Node3D, mesh: Mesh, material: Material, position: Vector3, rotation := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.rotation = rotation
	node.scale = scale
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func _cone(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var key := "cone|%.2f|%.2f|%.2f|%d" % [top, bottom, height, sides]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = top
		mesh.bottom_radius = bottom
		mesh.height = height
		mesh.radial_segments = sides
		mesh.rings = 1
		_meshes[key] = mesh
	return _meshes[key]

static func _box(size: Vector3) -> BoxMesh:
	var key := "box|%s" % size
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _meshes[key]

static func _sphere(radius: float, segments := 10) -> SphereMesh:
	var key := "sphere|%.2f|%d" % [radius, segments]
	if not _meshes.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = segments
		mesh.rings = maxi(segments / 2, 3)
		_meshes[key] = mesh
	return _meshes[key]

## Плоска смуга/диск на підлогу (PlaneMesh 1×1, масштаб — розмір).
static func floor_plane(material: Material, size: Vector2) -> MeshInstance3D:
	if not _meshes.has("plane"):
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		plane.subdivide_width = 0
		plane.subdivide_depth = 0
		_meshes["plane"] = plane
	var node := MeshInstance3D.new()
	node.mesh = _meshes["plane"]
	node.material_override = material
	node.scale = Vector3(size.x, 1.0, size.y)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static func floor_disc(material: Material, radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _cone(1.0, 1.0, 0.01, 32)
	node.material_override = material
	node.scale = Vector3(radius, 1.0, radius)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

# --- Володар Горна ---

## Розжарений клинок: плаский ромбовидний клинок із лави, гарда й руків'я.
## Вістря — уздовж -Z (як у снарядів).
static func forge_blade() -> Node3D:
	var root := Node3D.new()
	var steel := _lit(Color(0.3, 0.28, 0.27), 0.8, 0.35)
	var blade := _part(root, _cone(0.0, 0.14, 1.1, 4), lava_material(0.85), Vector3(0, 0, -0.45), Vector3(-PI * 0.5, 0, 0), Vector3(1.0, 1.0, 0.28))
	blade.name = "Blade"
	_part(root, _box(Vector3(0.42, 0.06, 0.08)), steel, Vector3(0, 0, 0.12))
	_part(root, _cone(0.035, 0.035, 0.3, 6), _lit(Color(0.25, 0.15, 0.08)), Vector3(0, 0, 0.3), Vector3(PI * 0.5, 0, 0))
	_part(root, _sphere(0.055, 6), steel, Vector3(0, 0, 0.47))
	return root

## Жолоб розплаву на підлозі: смуга лави, що розгоряється (set_heat).
static func lava_strip(length: float, width: float) -> MeshInstance3D:
	var strip := floor_plane(lava_material(0.0, 0.0), Vector2(width, length))
	return strip

static func set_heat(node: MeshInstance3D, heat: float, alpha: float) -> void:
	var material := node.material_override as ShaderMaterial
	material.set_shader_parameter(&"heat", heat)
	material.set_shader_parameter(&"alpha", alpha)

# --- Скупар / Ватажок ---

## Болас: три камені на мотузках, що крутяться навколо центру.
static func bola() -> Node3D:
	var root := Node3D.new()
	var spin := Node3D.new()
	spin.name = "Spin"
	root.add_child(spin)
	var stone := _lit(Color(0.42, 0.38, 0.33))
	var rope := _lit(Color(0.55, 0.42, 0.25))
	for i in 3:
		var angle := TAU * i / 3.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		_part(spin, _sphere(0.11, 6), stone, dir * 0.42)
		var cord := _part(spin, _box(Vector3(0.025, 0.025, 0.42)), rope, dir * 0.21)
		cord.rotation.y = atan2(dir.x, dir.z)
	var tween := spin.create_tween().set_loops()
	tween.tween_property(spin, "rotation:y", TAU, 0.3).from(0.0)
	return root

## Зблиск клинка (контрудар): зірочка, що спалахує й крутиться.
static func glint(color: Color) -> MeshInstance3D:
	var star := Fx.make_sprite("star_04", color, false, true)
	star.scale = Vector3.ONE * 0.9
	var tween := star.create_tween().set_loops()
	tween.tween_property(star, "scale", Vector3.ONE * 1.3, 0.25)
	tween.tween_property(star, "scale", Vector3.ONE * 0.7, 0.25)
	return star

# --- Володар Рун ---

## Руна на підлозі: світний знак (магічне коло з набору), що крутиться.
static func rune_glyph(color: Color, size: float) -> MeshInstance3D:
	var glyph := Fx.make_sprite("magic_03", color, true, true)
	glyph.scale = Vector3.ONE * size
	var tween := glyph.create_tween().set_loops()
	tween.tween_property(glyph, "rotation:y", TAU, 6.0).from(0.0)
	return glyph

static func void_material() -> ShaderMaterial:
	return water_material(Color(0.02, 0.0, 0.05, 0.9), Color(0.35, 0.12, 0.6, 0.85), Vector2(0.0, 0.3), 0.6)

const DARK_AREA := "res://assets/BinbunVFX_Vol2/DarkMagicFX/effects/area/vfx_evil_area_01.tscn"
const DARK_BALL := "res://assets/BinbunVFX_Vol2/DarkMagicFX/effects/ball/vfx_ball_evil_01.tscn"

## Ефект із набору Dark Magic (Binbun): вихор порожнечі на підлозі чи
## темна куля. Лампу з набору прибираємо (на телефоні світло дороге).
## seconds > 0 — сам згасне й зникне; 0 — живе, доки викликач не
## прибере (dark_close).
static func dark_effect(parent: Node, path: String, position: Vector3, size: float, seconds: float) -> Node3D:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	for light in node.find_children("*", "Light3D", true, false):
		light.queue_free()
	for sound in node.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.queue_free()
	parent.add_child(node)
	node.global_position = position
	node.scale = Vector3.ONE * size
	if seconds > 0.0:
		var tween := node.create_tween()
		tween.tween_interval(seconds)
		tween.tween_callback(dark_close.bind(node))
	return node

static func dark_close(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	if "emitting" in node:
		node.set("emitting", false)
	var tween := node.create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(node.queue_free)

## Тінь героя: копія його моделі з темним світним матеріалом, що біжить.
static func hero_shadow(hero: Node3D, rim: Color) -> Node3D:
	var source: Node3D = hero.get("model")
	var root := Node3D.new()
	if source == null:
		return root
	var copy := source.duplicate() as Node3D
	root.add_child(copy)
	copy.transform = Transform3D.IDENTITY
	copy.scale = source.scale
	var material := ghost_material(rim, Color(0.04, 0.0, 0.08, 0.6))
	for node in copy.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).material_override = material
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for player in copy.find_children("*", "AnimationPlayer", true, false):
		var animation := player as AnimationPlayer
		for name in animation.get_animation_list():
			if String(name).to_lower().contains("run"):
				animation.get_animation(name).loop_mode = Animation.LOOP_LINEAR
				animation.play(name)
				break
	return root

# --- Королева Трясовини ---

## Латаття: лист-коло з вирізом і квіткою (через одне).
static func lily_pad(radius: float, flower: bool) -> Node3D:
	var root := Node3D.new()
	if not _meshes.has("lily"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var steps := 22
		var gap := 0.55
		for i in steps:
			var a0 := gap * 0.5 + (TAU - gap) * i / steps
			var a1 := gap * 0.5 + (TAU - gap) * (i + 1) / steps
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(Vector3(sin(a1), 0.0, cos(a1)))
			st.add_vertex(Vector3(sin(a0), 0.0, cos(a0)))
		_meshes["lily"] = st.commit()
	_part(root, _meshes["lily"], _lit(Color(0.24, 0.52, 0.2), 0.0, 0.6, Color(0.02, 0.07, 0.01)), Vector3.ZERO, Vector3.ZERO, Vector3(radius, 1.0, radius))
	_part(root, _cone(radius * 0.08, radius * 0.08, 0.02, 6), _lit(Color(0.16, 0.36, 0.12)), Vector3(0, 0.012, 0))
	if flower:
		var petal := _lit(Color(1.0, 0.62, 0.8), 0.0, 0.5, Color(0.15, 0.04, 0.08))
		for i in 6:
			var a := TAU * i / 6.0
			_part(root, _cone(0.0, 0.09, 0.3, 4), petal, Vector3(sin(a) * 0.12, 0.12, cos(a) * 0.12) + Vector3(radius * 0.35, 0, 0), Vector3(cos(a) * 0.7, 0, -sin(a) * 0.7))
		_part(root, _sphere(0.07, 6), _lit(Color(1.0, 0.85, 0.3), 0.0, 0.5, Color(0.3, 0.2, 0.0)), Vector3(radius * 0.35, 0.12, 0))
	return root

static func swamp_water() -> ShaderMaterial:
	return water_material(Color(0.03, 0.12, 0.09, 0.82), Color(0.16, 0.36, 0.26, 0.82), Vector2.ZERO, 0.8)

## Щелепи Королеви: два ряди кістяних зубів по краю сектора пащі, що
## виростають із підлоги (set_jaws 0..1) і змикаються.
static func jaws(radius: float, half_arc: float) -> Node3D:
	var root := Node3D.new()
	var bone := _lit(Color(0.92, 0.88, 0.75), 0.0, 0.5)
	var gum := _lit(Color(0.45, 0.06, 0.1), 0.0, 0.7, Color(0.15, 0.0, 0.02))
	var count := 9
	for row in 2:
		var side := -1.0 if row == 0 else 1.0
		var jaw := Node3D.new()
		jaw.name = "Jaw%d" % row
		root.add_child(jaw)
		for i in count:
			var t := float(i) / (count - 1)
			var dist := lerpf(0.8, radius, t)
			var a := side * half_arc
			var spot := Vector3(sin(a) * dist, 0.0, cos(a) * dist)
			_part(jaw, _cone(0.0, 0.13, 0.55, 4), bone, spot + Vector3.UP * 0.27)
			_part(jaw, _sphere(0.12, 5), gum, spot + Vector3.UP * 0.02, Vector3.ZERO, Vector3(1.4, 0.4, 1.4))
	return root

## 0 — зуби під землею, 1 — стирчать. close 0..1 — щелепи сходяться до осі.
static func set_jaws(root: Node3D, rise: float, close: float, half_arc: float) -> void:
	for row in 2:
		var jaw := root.get_node_or_null("Jaw%d" % row) as Node3D
		if jaw == null:
			continue
		jaw.position.y = lerpf(-0.6, 0.0, rise)
		var side := -1.0 if row == 0 else 1.0
		jaw.rotation.y = -side * half_arc * close

# --- Ярл Вічної Зими ---

## Крижана стіна: ряд гострих призм різної висоти (довжина — уздовж Z).
static func ice_wall(length: float, height: float) -> Node3D:
	var root := Node3D.new()
	var material := ice_material()
	var count := maxi(int(length / 0.7), 2)
	for i in count:
		var z := lerpf(-length * 0.5 + 0.35, length * 0.5 - 0.35, float(i) / maxf(count - 1, 1))
		var h := height * randf_range(0.7, 1.05)
		var shard := _part(root, _cone(0.05, 0.42, 1.0, 5), material, Vector3(randf_range(-0.12, 0.12), h * 0.5, z),
			Vector3(randf_range(-0.12, 0.12), randf() * TAU, randf_range(-0.12, 0.12)), Vector3(1.0, h, 1.0))
		shard.name = "Shard%d" % i
	var mist := Fx.make_particles("smoke_07", Color(0.85, 0.95, 1.0, 0.35), 10, 1.6, 1.4)
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(0.4, 0.1, length * 0.5)
	mist.gravity = Vector3.ZERO
	mist.initial_velocity_min = 0.1
	mist.initial_velocity_max = 0.3
	root.add_child(mist)
	mist.position.y = 0.2
	return root

## Жаровня: залізна чаша на трьох ніжках, жар і вогонь.
static func brazier(warm_radius: float) -> Node3D:
	var root := Node3D.new()
	var iron := _lit(Color(0.2, 0.18, 0.17), 0.7, 0.45)
	_part(root, _cone(0.46, 0.22, 0.32, 10), iron, Vector3(0, 0.78, 0))
	for i in 3:
		var a := TAU * i / 3.0
		_part(root, _box(Vector3(0.06, 0.7, 0.06)), iron, Vector3(sin(a) * 0.22, 0.33, cos(a) * 0.22), Vector3(cos(a) * 0.25, 0, -sin(a) * 0.25))
	_part(root, _cone(0.4, 0.4, 0.06, 10), lava_material(1.0), Vector3(0, 0.93, 0))
	var flame := Fx.make_particles("flame_05", Color(1.0, 0.6, 0.2), 14, 0.7, 0.55, true)
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.22
	flame.direction = Vector3.UP
	flame.spread = 12.0
	flame.initial_velocity_min = 0.8
	flame.initial_velocity_max = 1.4
	flame.gravity = Vector3(0, 1.0, 0)
	root.add_child(flame)
	flame.position.y = 1.0
	var warmth := Fx.make_sprite("circle_05", Color(1.0, 0.55, 0.2, 0.35), true, true)
	warmth.scale = Vector3.ONE * warm_radius * 2.0
	root.add_child(warmth)
	warmth.position.y = 0.04
	return root

## Снігопад довкола героя (вітер збоку).
static func snowfall() -> CPUParticles3D:
	var snow := Fx.make_particles("circle_05", Color(0.95, 0.98, 1.0, 0.9), 70, 1.6, 0.12)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(7.0, 0.5, 7.0)
	snow.direction = Vector3(0.6, -1.0, 0.2)
	snow.spread = 10.0
	snow.initial_velocity_min = 2.5
	snow.initial_velocity_max = 4.0
	snow.gravity = Vector3(1.0, -2.0, 0.0)
	snow.local_coords = false
	return snow

## Ополонка: чорна вода з крижаними уламками по краю.
static func ice_hole(size: float) -> Node3D:
	var root := Node3D.new()
	var water := floor_plane(water_material(Color(0.0, 0.02, 0.05, 0.97), Color(0.04, 0.12, 0.2, 0.97), Vector2.ZERO, 0.4), Vector2(size, size))
	root.add_child(water)
	water.position.y = 0.03
	var material := ice_material(Color(0.75, 0.9, 1.0, 0.9))
	for i in 10:
		var a := TAU * i / 10.0 + randf_range(-0.2, 0.2)
		var r := size * 0.5 * randf_range(0.9, 1.05)
		var spot := Vector3(cos(a) * r, 0.05, sin(a) * r)
		_part(root, _cone(0.02, 0.18, 0.28, 4), material, spot, Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.6, 0.6)))
	return root

## Тріщини в кризі, що розповзаються (масштаб 0..size).
static func crack_decal(color: Color) -> MeshInstance3D:
	return Fx.make_sprite("se_crack_01", color, true, false)

# --- Владика Магми ---

## Вогняна куля: розжарене ядро з лави + полум'яний ореол і слід.
static func fireball(size: float) -> Node3D:
	var root := Fx.make_projectile(Color(1.0, 0.5, 0.12), size)
	_part(root, _sphere(0.22 * size, 8), lava_material(1.2), Vector3.ZERO)
	return root

## Розплавлена шкіра: накладка лави на всю модель (alpha — сила).
static func molten_overlay() -> ShaderMaterial:
	# Розжарене тіло: помаранчевий жар по краях (обідок) і мерехтіння —
	# не візерунок лави в світових координатах (той збігався з плитами
	# шахівниці, й здавалось, що текстура підлоги "налазить" на боса).
	var material := ghost_material(Color(1.0, 0.45, 0.05, 1.0), Color(1.0, 0.3, 0.0, 0.25))
	material.set_shader_parameter(&"alpha", 0.0)
	return material

# --- Безликий Бог ---

## Кам'яна долоня бога: долоня, чотири пальці, великий, золотий браслет.
## Долонею донизу; пальці — уздовж -Z. size — ширина долоні в метрах.
static func stone_hand(size: float) -> Node3D:
	var root := Node3D.new()
	var stone := _lit(Color(0.86, 0.82, 0.72), 0.0, 0.85, Color(0.28, 0.25, 0.2))
	var gold := _lit(Color(0.95, 0.75, 0.3), 0.8, 0.3, Color(0.45, 0.32, 0.06))
	var hand := Node3D.new()
	root.add_child(hand)
	hand.scale = Vector3.ONE * size
	_part(hand, _box(Vector3(0.95, 0.26, 0.9)), stone, Vector3(0, 0.14, 0))
	for i in 4:
		var x := lerpf(-0.36, 0.36, i / 3.0)
		var length: float = [0.9, 1.1, 1.0, 0.8][i]
		var finger := CapsuleMesh.new()
		finger.radius = 0.12
		finger.height = length
		finger.radial_segments = 6
		finger.rings = 1
		_part(hand, finger, stone, Vector3(x, 0.14, -0.5 - length * 0.42), Vector3(PI * 0.5, 0, 0))
	var thumb := CapsuleMesh.new()
	thumb.radius = 0.12
	thumb.height = 0.6
	thumb.radial_segments = 6
	thumb.rings = 1
	_part(hand, thumb, stone, Vector3(0.62, 0.14, -0.1), Vector3(PI * 0.5, -0.7, 0))
	_part(hand, _cone(0.42, 0.42, 0.7, 8), stone, Vector3(0, 0.2, 0.72), Vector3(PI * 0.5, 0, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.52
	ring.rings = 12
	ring.ring_segments = 4
	_part(hand, ring, gold, Vector3(0, 0.2, 0.62), Vector3(PI * 0.5, 0, 0))
	return root

## Сфера вірності: золоте ядро, промениста корона й кільце, що кружляє.
static func holy_orb() -> Node3D:
	var root := Node3D.new()
	_part(root, _sphere(0.22, 10), _lit(Color(1.0, 0.85, 0.4), 0.6, 0.2, Color(0.9, 0.6, 0.15)), Vector3.ZERO)
	var rays := Fx.make_sprite("light_02", Color(1.0, 0.85, 0.45, 0.85), false, true)
	rays.scale = Vector3.ONE * 1.3
	root.add_child(rays)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.36
	ring_mesh.outer_radius = 0.4
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 4
	var ring := _part(root, ring_mesh, _lit(Color(1.0, 0.85, 0.4), 0.8, 0.2, Color(0.6, 0.4, 0.1)), Vector3.ZERO, Vector3(0.6, 0, 0))
	var tween := ring.create_tween().set_loops()
	tween.tween_property(ring, "rotation:y", TAU, 1.6).from(0.0)
	return root

## Циферблат зворотного часу: золоте коло, що крутиться ПРОТИ годинникової.
static func clock_dial(radius: float) -> MeshInstance3D:
	var dial := Fx.make_sprite("magic_04", Color(1.0, 0.85, 0.4, 0.75), true, true)
	dial.scale = Vector3.ONE * radius * 2.0
	var tween := dial.create_tween().set_loops()
	tween.tween_property(dial, "rotation:y", -TAU, 2.5).from(0.0)
	return dial

## Пісок, що сиплеться в годиннику.
static func falling_sand() -> CPUParticles3D:
	var sand := Fx.make_particles("circle_05", Color(1.0, 0.8, 0.4), 18, 0.5, 0.07, true)
	sand.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sand.emission_sphere_radius = 0.03
	sand.direction = Vector3.DOWN
	sand.spread = 4.0
	sand.initial_velocity_min = 0.4
	sand.initial_velocity_max = 0.6
	sand.gravity = Vector3(0, -1.0, 0)
	return sand
