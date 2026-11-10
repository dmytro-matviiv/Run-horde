extends EnemyAbility

## КРИЖАНИЙ НЕБОСХИЛ (Інейний Дракон, фаза 2): злітає над ареною (у
## повітрі його не дістати), а на підлозі з'являються тіні-кола — туди
## падають великі бурульки. Впала — лишається крижаною колоною, за якою
## можна сховатися від дихання. Через flight секунд приземляється з
## ударом по колу й stun секунд оглушений — його можна бити.
##
## Налаштування: flight, height, every (с між бурульками), radius
## (бурульки), land_radius, stun, damage, max_pillars.

const SHADOW := Color(0.3, 0.55, 0.9, 0.85)
const ICE := Color(0.6, 0.9, 1.0)
const FALL_TIME := 0.25
const TELL := 1.2
const PILLAR_RADIUS := 0.55
const PILLAR_HEIGHT := 2.6

enum Step {IDLE, RISE, AIR, LAND}

var _step := Step.IDLE
var _time_left := 0.0
var _drop_left := 0.0
var _home := Vector3.INF
var _base_y := 0.0
var _pillars: Array[Node3D] = []

func _init() -> void:
	id = "sky_fall"
	cooldown = 26.0

func is_busy() -> bool:
	return _step != Step.IDLE

func try_use(_distance: float) -> bool:
	start_cooldown()
	_step = Step.RISE
	_base_y = enemy.global_position.y
	enemy.invulnerable = true
	enemy.play_once(["Roar"])
	CombatVfx.shockwave(world(), enemy.global_position, 5.0, ICE, 0.5)
	var tween := enemy.create_tween()
	var top := Vector3(_home.x, _base_y + float(config.get("height", 6.0)), _home.z) if _home != Vector3.INF \
		else enemy.global_position + Vector3.UP * float(config.get("height", 6.0))
	tween.tween_property(enemy, "global_position", top, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func() -> void:
		_step = Step.AIR
		_time_left = float(config.get("flight", 10.0))
		_drop_left = 0.3)
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	if _home == Vector3.INF and enemy.is_inside_tree():
		_home = enemy.global_position
	match _step:
		Step.RISE:
			enemy.play_loop("Fly")
		Step.AIR:
			enemy.play_loop("Fly")
			enemy.face_point(player().global_position)
			_time_left -= delta
			_drop_left -= delta
			if _drop_left <= 0.0:
				_drop_left = float(config.get("every", 1.0))
				_drop_icicle()
			if _time_left <= 0.0:
				_land()

## Тінь на підлозі — за мить туди падає бурулька й лишається колоною.
func _drop_icicle() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var angle := randf() * TAU
	var spot := hero.global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.0, 2.6)
	var radius := float(config.get("radius", 1.3))
	var parent := world()
	var shadow := CombatVfx.make_telegraph(SHADOW, radius, PI, false)
	parent.add_child(shadow)
	shadow.global_position = Vector3(spot.x, DungeonBuilder.FLOOR_TOP + 0.05, spot.z)
	var icicle := _make_icicle()
	parent.add_child(icicle)
	icicle.global_position = Vector3(spot.x, DungeonBuilder.FLOOR_TOP + 9.0, spot.z)
	icicle.visible = false
	var tween := shadow.create_tween()
	tween.tween_method(func(value: float) -> void:
		CombatVfx.set_param(shadow, &"progress", value), 0.0, 1.0, TELL)
	tween.tween_callback(func() -> void: icicle.visible = true)
	tween.tween_property(icicle, "global_position:y", DungeonBuilder.FLOOR_TOP + PILLAR_HEIGHT * 0.5, FALL_TIME) \
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		shadow.queue_free()
		_impact(icicle, spot, radius))

func _impact(icicle: Node3D, spot: Vector3, radius: float) -> void:
	var parent := world()
	CombatVfx.shockwave(parent, spot, radius, ICE, 0.3)
	CombatVfx.impact(parent, spot + Vector3.UP * 0.5, ICE, true)
	CombatVfx.impact_decal(parent, spot, radius * 0.8, ICE, 0.5)
	var hero := player()
	var keep := true
	if hero != null and is_instance_valid(hero):
		var offset := hero.global_position - spot
		offset.y = 0.0
		if offset.length() <= radius:
			hero.take_damage(damage())
		# Колона не стає на героя — лише впала й розбилась.
		if offset.length() < PILLAR_RADIUS + 0.6:
			keep = false
	for pillar in _pillars:
		if is_instance_valid(pillar) and pillar.global_position.distance_to(spot) < 1.6:
			keep = false
	if not keep or _pillars.size() >= int(config.get("max_pillars", 8)):
		icicle.queue_free()
		return
	# Стоїть колоною: тверда для героя й ворогів, закриває від дихання.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = PILLAR_RADIUS
	cylinder.height = PILLAR_HEIGHT
	shape.shape = cylinder
	body.add_child(shape)
	icicle.add_child(body)
	_pillars.append(icicle)
	icicle.add_to_group(&"ice_pillars")

static func _make_icicle() -> Node3D:
	var holder := Node3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.9, 1.0, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.3, 0.6, 0.9)
	material.emission_energy_multiplier = 0.5
	material.roughness = 0.2
	material.rim_enabled = true
	for i in 3:
		var crystal := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.04
		mesh.bottom_radius = [0.5, 0.3, 0.25][i]
		mesh.height = [PILLAR_HEIGHT, 1.7, 1.3][i]
		mesh.radial_segments = 6
		mesh.rings = 1
		crystal.mesh = mesh
		crystal.material_override = material
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(crystal)
		if i > 0:
			var side := Vector3(0.35 if i == 1 else -0.3, 0.0, 0.2 if i == 1 else -0.25)
			crystal.position = side + Vector3(0, -(PILLAR_HEIGHT - mesh.height) * 0.5, 0)
			crystal.rotation = Vector3(side.z * 0.6, 0.0, -side.x * 0.6)
	return holder

## Приземлення з ударом по колу — і 3 секунди оглушений.
func _land() -> void:
	_step = Step.LAND
	var ground := Vector3(enemy.global_position.x, _base_y, enemy.global_position.z)
	var tween := enemy.create_tween()
	tween.tween_property(enemy, "global_position", ground, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		enemy.invulnerable = false
		enemy.play_once(["Land", "Weapon"])
		var radius := float(config.get("land_radius", 5.0))
		CombatVfx.shockwave(world(), ground, radius, ICE, 0.5)
		CombatVfx.impact_decal(world(), ground, radius * 0.6, ICE, 0.8)
		var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
		if rig != null:
			rig.shake(0.3)
		var hero := player()
		if hero != null and is_instance_valid(hero):
			var offset := hero.global_position - ground
			offset.y = 0.0
			if offset.length() <= radius and hero.take_damage(damage() * 1.2) and hero.has_method("knock_down"):
				hero.knock_down(offset.normalized() * 7.0, 0.4)
		_step = Step.IDLE
		enemy.stun_for(float(config.get("stun", 3.0))))

func on_death() -> void:
	enemy.invulnerable = false
	_step = Step.IDLE
	# Увесь лід в арені тріскається: колони розбиваються по черзі.
	var delay := 0.2
	for pillar in _pillars:
		if not is_instance_valid(pillar):
			continue
		var target := pillar
		enemy.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			if is_instance_valid(target):
				CombatVfx.impact(target.get_parent(), target.global_position, ICE, true)
				CombatVfx.shockwave(target.get_parent(), target.global_position - Vector3.UP * PILLAR_HEIGHT * 0.5, 1.4, ICE, 0.3)
				target.queue_free())
		delay += 0.18
	_pillars.clear()
