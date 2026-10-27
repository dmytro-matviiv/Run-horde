extends EnemyAbility

## ПІДЗЕМНИЙ ХРОБАК (Кістяний хробак): живе під землею — видно лише горбик
## ґрунту, що повзе до героя. Під героєм земля тріскається колом (warn с) —
## і хробак вистрибує, підкидаючи героя. Тоді surface секунд стоїть на
## поверхні: лише тепер його можна бити (і він кусає). Потім пірнає знову.
##
## Налаштування: radius, warn, surface, toss (с у повітрі), rest (с під
## землею після пірнання), damage.

const DUST := Color(0.5, 0.42, 0.32)
const CRACK := Color(0.9, 0.78, 0.55, 0.9)

enum Step {UNDER, WARN, SURFACE}

var _step := Step.UNDER
var _time := 0.0
var _target := Vector3.ZERO
var _marker: MeshInstance3D
var _mound: MeshInstance3D
var _started := false
var _dust_left := 0.0

static var _mound_material: StandardMaterial3D

func _init() -> void:
	id = "tunnel"
	cooldown = 0.0

func is_busy() -> bool:
	return _step != Step.SURFACE

func tick(delta: float) -> void:
	super.tick(delta)
	if not _started:
		_started = true
		_dive(false)
	match _step:
		Step.UNDER:
			_crawl(delta)
		Step.WARN:
			_time -= delta
			if _time <= 0.0:
				_burst()
		Step.SURFACE:
			_time -= delta
			# Дає докусати: замах не обривається пірнанням.
			if _time <= 0.0 and float(enemy.get("_windup_left")) <= 0.0:
				_dive(true)

## Під землею: помітив героя — повзе до нього горбиком і пилом.
func _crawl(delta: float) -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - enemy.global_position
	offset.y = 0.0
	var hunted: bool = not hero.has_method("is_targetable") or hero.is_targetable()
	if not enemy.is_aggro():
		if hunted and offset.length() <= enemy.aggro_range:
			enemy.alert()
		return
	if not hunted or offset.length() > enemy.leash_range:
		return
	_time -= delta
	if _time > 0.0:
		return
	if offset.length() <= 0.6:
		_warn()
		return
	enemy.global_position += offset.normalized() * minf(enemy.move_speed * delta, offset.length())
	_dust_left -= delta
	if _dust_left <= 0.0:
		_dust_left = 0.22
		CombatVfx.impact(world(), enemy.global_position + Vector3.UP * 0.15, DUST, false)

## Під героєм тріскається коло — за warn секунд хробак вистрибне.
func _warn() -> void:
	_step = Step.WARN
	_time = float(config.get("warn", 1.0))
	var hero := player()
	_target = Vector3(hero.global_position.x, DungeonBuilder.FLOOR_TOP + 0.05, hero.global_position.z)
	enemy.teleport_to(Vector3(_target.x, enemy.global_position.y, _target.z))
	var radius := float(config.get("radius", 1.6))
	_clear()
	_marker = CombatVfx.make_telegraph(CRACK, radius, PI, true)
	world().add_child(_marker)
	_marker.global_position = _target
	var marker := _marker
	marker.create_tween().tween_method(func(value: float) -> void:
		if is_instance_valid(marker):
			marker.set_instance_shader_parameter(&"progress", value), 0.0, 1.0, _time)
	CombatVfx.impact_decal(world(), _target, radius * 0.6, CRACK, _time)

func _burst() -> void:
	_clear()
	_show_mound(false)
	_step = Step.SURFACE
	_time = float(config.get("surface", 2.0))
	enemy.set_hidden(false)
	enemy.emerge(0.25)
	enemy.play_once(["Emerge"])
	var radius := float(config.get("radius", 1.6))
	CombatVfx.shockwave(world(), _target, radius, DUST, 0.35)
	CombatVfx.impact_decal(world(), _target, radius * 0.8, DUST, 0.6)
	CombatVfx.impact(world(), _target + Vector3.UP * 0.5, DUST, true)
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.12)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - _target
	offset.y = 0.0
	if offset.length() <= radius and hero.take_damage(damage()) and hero.has_method("toss"):
		hero.toss(float(config.get("toss", 0.8)))

## Пірнає під землю: не видно, не вдарити; лишається горбик.
func _dive(effects: bool) -> void:
	_step = Step.UNDER
	_time = float(config.get("rest", 0.8))
	if effects:
		CombatVfx.impact(world(), enemy.global_position + Vector3.UP * 0.3, DUST, true)
		CombatVfx.impact_decal(world(), enemy.global_position, 1.0, DUST, 0.5)
	enemy.set_hidden(true)
	_show_mound(true)

## Горбик ґрунту над хробаком — ледь "дихає", поки той повзе.
func _show_mound(shown: bool) -> void:
	if shown and _mound == null:
		if _mound_material == null:
			_mound_material = StandardMaterial3D.new()
			_mound_material.albedo_color = Color(0.32, 0.26, 0.2)
			_mound_material.roughness = 1.0
		var sphere := SphereMesh.new()
		sphere.radius = 0.55
		sphere.height = 1.1
		sphere.radial_segments = 10
		sphere.rings = 5
		sphere.is_hemisphere = true
		_mound = MeshInstance3D.new()
		_mound.mesh = sphere
		_mound.material_override = _mound_material
		_mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mound.scale = Vector3(1.0, 0.4, 1.0)
		enemy.add_child(_mound)
		var pulse := _mound.create_tween().set_loops()
		pulse.tween_property(_mound, "scale", Vector3(1.1, 0.48, 1.1), 0.3)
		pulse.tween_property(_mound, "scale", Vector3(1.0, 0.38, 1.0), 0.3)
	if _mound != null:
		_mound.visible = shown

func on_death() -> void:
	_clear()
	_show_mound(false)

func _clear() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
