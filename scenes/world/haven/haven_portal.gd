extends Node3D
class_name HavenPortal

## ПОРТАЛ У ДАНЖ на верхній терасі Прихистку: стара кам'яна арка на
## помості, у ній клубочиться вихор (фіолетовий із блакитним серцем),
## під ногами повільно крутиться коло рун, довкола арки пливуть уламки
## рунного каменю, з боків — стовпи з вогнем, світні цятки затягує в
## прохід. Підходиш — з'являється кнопка "У данж".
##
## Усе — прості меші, частинки й два шейдери: телефон тягне.

signal player_near()
signal player_left()

const V := "res://assets/models/haven/village/"
const F := "res://assets/models/haven/forest/"
const RADIUS := 3.2
const ARCH_SCALE := 1.75
const COLOR_OUTER := Color(0.42, 0.16, 0.95)
const COLOR_CORE := Color(0.3, 0.8, 1.0)

## Вихор у проході: спіраль із шуму, що закручується до центру; краї
## арки світяться. UV — квадрат проходу (0..1), верх — UV.y = 0.
const VORTEX_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 outer : source_color = vec4(0.55, 0.3, 1.0, 1.0);
uniform vec4 core : source_color = vec4(0.45, 0.95, 1.0, 1.0);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;

void fragment() {
	// Форма арки: прямокутник із півколом угорі.
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float top = 1.0 - 0.36;
	float inside = step(abs(p.x), 0.96) * step(p.y, top);
	vec2 arc = vec2(p.x, (p.y - top) / 0.36 * 0.96);
	inside = max(inside, step(length(arc), 0.96) * step(top, p.y));
	// Спіраль: кут + відстань крутяться з часом.
	vec2 c = vec2(p.x, (p.y - 0.42) * 1.25);
	float r = length(c);
	float a = atan(c.y, c.x);
	vec2 sw = vec2(a / 6.2831 + r * 0.9 - TIME * 0.18, r * 1.4 - TIME * 0.35);
	float n = texture(noise, sw).r * 0.65 + texture(noise, sw * 2.3 + 0.37).r * 0.35;
	float swirl = smoothstep(0.35, 0.85, n);
	float centre = exp(-r * r * 3.5);
	vec3 col = mix(outer.rgb, core.rgb, clamp(swirl * 0.55 + centre * 0.6, 0.0, 1.0));
	col = mix(col, vec3(1.0), centre * 0.12);
	float edge = smoothstep(0.75, 1.0, r) * 0.35;
	ALBEDO = col;
	// Притушено: вихор світиться, але не засвічує все до білого.
	ALPHA = inside * clamp(0.14 + swirl * 0.34 + centre * 0.22 + edge, 0.0, 0.8);
}
"""

var _static: Node3D
var _vortex: MeshInstance3D
var _runes: MeshInstance3D
var _shards: Array[Node3D] = []
var _time := 0.0
var _player: Node3D
var _near := false

func _ready() -> void:
	# Нерухоме (поміст, бордюр, арка, стовпи) — пакуємо в одну команду
	# на модель (TownBatcher): для телефона дешевше.
	_static = Node3D.new()
	_static.name = "Static"
	add_child(_static)
	_build_dais()
	_build_arch()
	_build_vortex()
	_build_rune_circle()
	_build_pillars()
	_build_shards()
	_build_motes()
	TownBatcher.batch(_static, 0.0)

func set_player(player: Node3D) -> void:
	_player = player

func _process(delta: float) -> void:
	_time += delta
	_runes.rotation.y += delta * 0.25
	for i in _shards.size():
		var shard := _shards[i]
		var a := _time * 0.45 + TAU * i / _shards.size()
		shard.position = Vector3(cos(a) * 3.2, 3.0 + sin(_time * 1.3 + i) * 0.35, sin(a) * 1.1 - 0.2)
		shard.rotation.y += delta * 0.8
	if _player == null:
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	var near := offset.length() < RADIUS
	if near != _near:
		_near = near
		if near:
			player_near.emit()
		else:
			player_left.emit()

func _model(path: String, pos: Vector3, yaw: float, scale: Vector3, moving: bool = false) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate()
	(self if moving else _static).add_child(node)
	node.position = pos
	node.rotation.y = yaw
	node.scale = scale
	return node

## Поміст: квадрат бруківки 3×3 плити з кам'яним бордюром.
func _build_dais() -> void:
	for x in 3:
		for z in 3:
			_model(V + "Floor_UnevenBrick.gltf", Vector3((x - 1) * 2.0, 0.02, (z - 1) * 2.0), 0.0, Vector3.ONE)
	for k in 3:
		var t := (k - 1) * 2.0
		_model(V + "Prop_ExteriorBorder_Straight1.gltf", Vector3(t, 0.0, 3.0), PI, Vector3.ONE)
		_model(V + "Prop_ExteriorBorder_Straight1.gltf", Vector3(t, 0.0, -3.0), 0.0, Vector3.ONE)
		_model(V + "Prop_ExteriorBorder_Straight1.gltf", Vector3(3.0, 0.0, t), -PI * 0.5, Vector3.ONE)
		_model(V + "Prop_ExteriorBorder_Straight1.gltf", Vector3(-3.0, 0.0, t), PI * 0.5, Vector3.ONE)

func _build_arch() -> void:
	_model(V + "DoorFrame_Round_Brick.gltf", Vector3(0, 0.02, 0), 0.0, Vector3.ONE * ARCH_SCALE)

func _build_vortex() -> void:
	_vortex = MeshInstance3D.new()
	var quad := QuadMesh.new()
	# Прохід арки DoorFrame_Round_Brick: ~1.5 × 2.6 м, з масштабом.
	quad.size = Vector2(1.5, 2.6) * ARCH_SCALE
	_vortex.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = VORTEX_SHADER
	material.set_shader_parameter(&"noise", load("res://assets/textures/town/town_noise.png"))
	material.set_shader_parameter(&"outer", COLOR_OUTER)
	material.set_shader_parameter(&"core", COLOR_CORE)
	_vortex.material_override = material
	_vortex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_vortex)
	_vortex.position = Vector3(0, quad.size.y * 0.5 + 0.05, 0)

## Коло рун на помості — повільно крутиться.
func _build_rune_circle() -> void:
	_runes = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(5.2, 5.2)
	_runes.mesh = plane
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = load("res://assets/textures/vfx/telegraph_circle_rune.png")
	material.albedo_color = Color(COLOR_CORE.lerp(COLOR_OUTER, 0.3), 1.0)
	_runes.material_override = material
	_runes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_runes)
	_runes.position = Vector3(0, 0.06, 0)

## Стовпи з вогнем обабіч арки.
func _build_pillars() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 3.6
		_model(V + "Corner_Exterior_Brick.gltf", Vector3(x, 0.0, 0.6), PI * 0.25, Vector3(1.4, 0.55, 1.4))
		var fire := Fx.make_particles("flame_05", Color(1.0, 0.5, 0.18), 18, 0.55, 0.9, true, true)
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fire.emission_sphere_radius = 0.18
		fire.direction = Vector3.UP
		fire.spread = 10.0
		fire.initial_velocity_min = 0.6
		fire.initial_velocity_max = 1.2
		fire.gravity = Vector3(0, 1.4, 0)
		add_child(fire)
		fire.position = Vector3(x, 1.85, 0.6)
		var glow := Fx.make_sprite("circle_05", Color(1.0, 0.55, 0.2, 0.45), false, true)
		glow.scale = Vector3.ONE * 1.6
		add_child(glow)
		glow.position = Vector3(x, 2.0, 0.6)

## Рунні кристали кружляють над аркою: загострені уламки, що світяться.
func _build_shards() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLOR_OUTER.lerp(Color.WHITE, 0.25)
	for i in 3:
		var shard := Node3D.new()
		add_child(shard)
		var crystal := MeshInstance3D.new()
		crystal.mesh = IceVfx.shard_mesh()
		crystal.material_override = material
		crystal.rotation_degrees = Vector3(90, 0, 0)
		crystal.scale = Vector3.ONE * 0.7
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shard.add_child(crystal)
		var glow := Fx.make_sprite("circle_05", Color(COLOR_OUTER, 0.55), false, true)
		glow.scale = Vector3.ONE * 1.2
		shard.add_child(glow)
		_shards.append(shard)

## Світні цятки: виникають довкола й летять у прохід.
func _build_motes() -> void:
	var motes := Fx.make_particles("spark_04", COLOR_CORE.lerp(Color.WHITE, 0.3), 28, 1.6, 0.18, true, true)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 2.8
	motes.direction = Vector3.ZERO
	motes.spread = 180.0
	motes.initial_velocity_min = 0.1
	motes.initial_velocity_max = 0.3
	motes.radial_accel_min = -1.6
	motes.radial_accel_max = -0.9
	motes.gravity = Vector3.ZERO
	add_child(motes)
	motes.position = Vector3(0, 2.2, 0)
