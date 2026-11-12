extends RefCounted
class_name IceVfx

## ЛІД: заморожений ворог стоїть у кущі крижаних кристалів (вони
## виростають із підлоги й охоплюють ноги й тулуб), під ним — тріщини
## інею. Розмерз — кристали розлітаються уламками. Сповільнений —
## лише іній на підлозі.
##
## Кристали — один легкий меш (кілька загострених шестигранних призм,
## гострі грані без згладжування) і спільний крижаний шейдер: темніша
## глибина, світлі краї за кутом погляду, яскравіші кінчики. Для телефона:
## один виклик малювання на ворога, без частинок, поки лід стоїть.

const ICE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.22, 0.52, 0.82, 1.0);
uniform vec4 edge : source_color = vec4(0.86, 0.97, 1.0, 1.0);
uniform float fade = 1.0;

varying float tip;

void vertex() {
	tip = UV.y;
}

void fragment() {
	vec3 n = FRONT_FACING ? NORMAL : -NORMAL;
	float rim = pow(1.0 - abs(dot(n, VIEW)), 1.6);
	float light = clamp(rim * 0.85 + tip * 0.45, 0.0, 1.0);
	ALBEDO = mix(deep.rgb, edge.rgb, light);
	EMISSION = edge.rgb * (rim * 0.35 + tip * 0.25);
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	ALPHA = clamp((0.62 + rim * 0.35) * fade, 0.0, 1.0);
}
"""

const VARIANTS := 3
const FROST_TINT := Color(0.45, 0.72, 1.0, 0.6)

static var _material: ShaderMaterial
static var _meshes: Array[ArrayMesh] = []
static var _shard_mesh: ArrayMesh

static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = Shader.new()
		_material.shader.code = ICE_SHADER
	return _material

## Кущ кристалів під ворога заввишки height (метри). seed — щоб у
## сусідів кущі були різні.
static func make_cluster(height: float, width: float, seed: int) -> Node3D:
	var holder := Node3D.new()
	var crystals := MeshInstance3D.new()
	crystals.mesh = _cluster_mesh(seed % VARIANTS)
	crystals.material_override = material()
	crystals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Меш зроблено під ворога ~1.6 м заввишки й ~0.5 м завширшки.
	crystals.scale = Vector3(width / 0.5, height / 1.6, width / 0.5)
	holder.add_child(crystals)
	holder.add_child(make_frost(width * 1.3 + 0.45))
	# Кристали виростають із підлоги.
	crystals.scale.y *= 0.15
	var tween := crystals.create_tween()
	tween.tween_property(crystals, "scale:y", height / 1.6, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return holder

## Іній на підлозі (тріщини льоду) радіусом radius.
static func make_frost(radius: float) -> MeshInstance3D:
	var frost := Fx.make_sprite("se_crack_01", FROST_TINT, true, true)
	frost.scale = Vector3.ONE * radius * 2.0
	frost.position.y = 0.05
	frost.rotation.y = randf() * TAU
	return frost

## Розмерз: кристали розлітаються уламками, що падають і тануть.
static func shatter(parent: Node, position: Vector3, height: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var shards := CPUParticles3D.new()
	shards.one_shot = true
	shards.explosiveness = 0.95
	shards.amount = 14
	shards.lifetime = 0.55
	shards.mesh = _get_shard_mesh()
	shards.material_override = material()
	shards.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	shards.emission_box_extents = Vector3(0.35, height * 0.45, 0.35)
	shards.direction = Vector3.UP
	shards.spread = 70.0
	shards.initial_velocity_min = 2.0
	shards.initial_velocity_max = 4.5
	shards.gravity = Vector3(0, -14.0, 0)
	shards.angular_velocity_min = -540.0
	shards.angular_velocity_max = 540.0
	shards.scale_amount_min = 0.22
	shards.scale_amount_max = 0.42
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.75, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	shards.scale_amount_curve = curve
	shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shards)
	shards.global_position = position + Vector3.UP * height * 0.45
	shards.emitting = true
	parent.get_tree().create_timer(0.8, false).timeout.connect(shards.queue_free)

## Кілька уламків — влучання крижаного снаряда.
static func chips(parent: Node, position: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var chips_node := CPUParticles3D.new()
	chips_node.one_shot = true
	chips_node.explosiveness = 1.0
	chips_node.amount = 5
	chips_node.lifetime = 0.35
	chips_node.mesh = _get_shard_mesh()
	chips_node.material_override = material()
	chips_node.direction = Vector3.UP
	chips_node.spread = 80.0
	chips_node.initial_velocity_min = 1.5
	chips_node.initial_velocity_max = 3.0
	chips_node.gravity = Vector3(0, -12.0, 0)
	chips_node.angular_velocity_min = -720.0
	chips_node.angular_velocity_max = 720.0
	chips_node.scale_amount_min = 0.14
	chips_node.scale_amount_max = 0.26
	chips_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(chips_node)
	chips_node.global_position = position
	chips_node.emitting = true
	parent.get_tree().create_timer(0.5, false).timeout.connect(chips_node.queue_free)

# --- геометрія ---

## Кристал-уламок для частинок і крижаного снаряда: витягнута загострена
## призма довжиною 1 уздовж -Z (вперед у Godot), з гострими гранями.
static func shard_mesh() -> ArrayMesh:
	return _get_shard_mesh()

static func _get_shard_mesh() -> ArrayMesh:
	if _shard_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_add_crystal(st, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, 0.35)), 0.11, 1.0, 5)
		st.generate_normals()
		_shard_mesh = st.commit()
	return _shard_mesh

static func _cluster_mesh(variant: int) -> ArrayMesh:
	while _meshes.size() < VARIANTS:
		_meshes.append(null)
	if _meshes[variant] != null:
		return _meshes[variant]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (variant + 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Великі кристали по колу (нахилені назовні) і кілька в середині —
	# разом охоплюють ворога до грудей.
	var count := 7
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.3, 0.3)
		var out := Vector3(sin(angle), 0.0, cos(angle))
		var lean := rng.randf_range(0.22, 0.5)
		var length := rng.randf_range(0.75, 1.35)
		var radius := rng.randf_range(0.1, 0.17)
		var base := out * rng.randf_range(0.18, 0.34)
		var axis := Vector3.UP.rotated(out.cross(Vector3.UP).normalized(), -lean)
		_add_crystal(st, _aligned(axis, base, rng.randf() * TAU), radius, length, 6)
	for i in 3:
		var angle := rng.randf() * TAU
		var out := Vector3(sin(angle), 0.0, cos(angle))
		var axis := Vector3.UP.rotated(out.cross(Vector3.UP).normalized(), -rng.randf_range(0.05, 0.2))
		_add_crystal(st, _aligned(axis, out * 0.06, rng.randf() * TAU), rng.randf_range(0.15, 0.2),
			rng.randf_range(1.2, 1.6), 6)
	# Дрібні кристалики біля підніжжя.
	for i in 5:
		var angle := rng.randf() * TAU
		var out := Vector3(sin(angle), 0.0, cos(angle))
		var axis := Vector3.UP.rotated(out.cross(Vector3.UP).normalized(), -rng.randf_range(0.6, 0.95))
		_add_crystal(st, _aligned(axis, out * rng.randf_range(0.38, 0.55), rng.randf() * TAU),
			rng.randf_range(0.05, 0.08), rng.randf_range(0.3, 0.5), 5)
	st.generate_normals()
	_meshes[variant] = st.commit()
	return _meshes[variant]

## Базис, у якого вісь Y дивиться вздовж axis (кристал росте вздовж неї).
static func _aligned(axis: Vector3, origin: Vector3, twist: float) -> Transform3D:
	var y := axis.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z) * Basis(Vector3.UP, twist), origin)

## Загострена призма: sides граней, тіло до 72% довжини, далі — вістря.
## UV.y — висота від основи (0) до кінчика (1): кінчики світліші.
## Кожен трикутник — свої вершини: грані гострі, як у справжнього кристала.
static func _add_crystal(st: SurfaceTool, xf: Transform3D, radius: float, length: float, sides: int) -> void:
	var body := length * 0.72
	var ring_low: Array[Vector3] = []
	var ring_high: Array[Vector3] = []
	for k in sides:
		var a := TAU * k / sides
		var offset := Vector3(cos(a), 0.0, sin(a)) * radius
		ring_low.append(xf * (offset * 0.85))
		ring_high.append(xf * (offset + Vector3.UP * body))
	var top := xf * (Vector3.UP * length)
	for k in sides:
		var n := (k + 1) % sides
		var v := body / length
		_tri(st, ring_low[k], ring_high[n], ring_high[k], 0.0, v, v)
		_tri(st, ring_low[k], ring_low[n], ring_high[n], 0.0, 0.0, v)
		_tri(st, ring_high[k], top, ring_high[n], v, 1.0, v)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, va: float, vb: float, vc: float) -> void:
	st.set_smooth_group(-1)
	st.set_uv(Vector2(0, va))
	st.add_vertex(a)
	st.set_uv(Vector2(0, vb))
	st.add_vertex(b)
	st.set_uv(Vector2(0, vc))
	st.add_vertex(c)
