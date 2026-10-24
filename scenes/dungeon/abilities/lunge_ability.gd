extends EnemyAbility

## РИВОК-ЗАМАХ (Орк-рубака). Герой ближче за trigger (4 м) — ворог на
## пів секунди присідає й замахується: тесак наливається червоним, а на
## підлозі — смуга, куди він стрибне. Далі короткий стрибок і удар там, де
## герой стояв на початку замаху: встиг відкотитись — промах.
##
## Налаштування з опису: trigger — з якої відстані (м), windup — замах (с),
## hop — політ (с), radius — зона удару після приземлення, damage — частка
## шкоди ворога, anim — жест замаху, jump_anim — стрибок з ударом.

const COLOR := Color(1.0, 0.18, 0.12, 0.9)
const GLOW_COLOR := Color(1.0, 0.2, 0.1)
## Кістка, на якій тесак — там світиться замах.
const WEAPON_BONE := &"RightHand"
## Найменша відстань: упритул б'є звичайним ударом.
const MIN_DISTANCE := 1.4
## Приземляється трохи перед героєм, а не на голову.
const LAND_SHORT := 0.7
## Підскок задає сама анімація стрибка; код лише трохи піднімає над
## підлогою, щоб ноги не чіркали.
const HOP_HEIGHT := 0.15

var _busy := false
var _from := Vector3.ZERO
var _target := Vector3.ZERO
var _line: MeshInstance3D
var _glow: Node3D

func _init() -> void:
	id = "lunge"
	cooldown = 4.0

func is_busy() -> bool:
	return _busy

func try_use(distance: float) -> bool:
	var trigger := float(config.get("trigger", 4.0))
	if distance > trigger or distance < MIN_DISTANCE or not enemy.sees_player():
		return false
	start_cooldown()
	var windup := float(config.get("windup", 0.5))
	_from = enemy.global_position
	var hero := player().global_position
	var direction := hero - _from
	direction.y = 0.0
	var length := maxf(direction.length() - LAND_SHORT, 0.4)
	direction = direction.normalized()
	length = _clear_length(direction, length)
	_target = _from + direction * length
	# Смуга до місця приземлення й червоний тесак — видно, куди й коли.
	_line = CombatVfx.make_line_telegraph(COLOR, length + 1.0, 1.4, "chevrons")
	world().add_child(_line)
	_line.global_position = Vector3(_from.x, DungeonBuilder.FLOOR_TOP + 0.05, _from.z) + direction * (length + 1.0) * 0.5
	_line.rotation.y = atan2(direction.x, direction.z)
	var tween := _line.create_tween()
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(_line):
			_line.set_instance_shader_parameter(&"progress", value), 0.0, 1.0, windup)
	_show_glow(windup)
	# Замах можуть збити сильним ударом — тоді смуга сама зникне.
	enemy.get_tree().create_timer(windup + 0.3, false).timeout.connect(_clear_line)
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	return true

## Замах дійшов кінця — стрибок.
func resolve() -> void:
	_clear_line()
	_busy = true
	var hop := float(config.get("hop", 0.45))
	enemy.play_once([String(config.get("jump_anim", "Jump")), "Weapon", "Punch"])
	var tween := enemy.create_tween()
	tween.tween_method(_fly, 0.0, 1.0, hop)
	tween.tween_callback(_land)

func _fly(t: float) -> void:
	var position := _from.lerp(_target, t)
	position.y = _from.y + HOP_HEIGHT * 4.0 * t * (1.0 - t)
	enemy.global_position = position

func _land() -> void:
	_busy = false
	enemy.global_position = _target
	var radius := float(config.get("radius", 1.6))
	CombatVfx.impact_decal(world(), _target, radius * 0.7, COLOR)
	CombatVfx.shockwave(world(), _target, radius, COLOR, 0.25)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - _target
	offset.y = 0.0
	if offset.length() <= radius:
		hero.take_damage(damage())
	enemy.hold_still(0.35)

func on_death() -> void:
	_clear_line()
	_busy = false

## Не стрибати крізь стіну чи стіл: шлях обрізається там, де перешкода.
func _clear_length(direction: Vector3, length: float) -> float:
	var space := enemy.get_world_3d().direct_space_state
	var from := _from + Vector3.UP * 0.6
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * (length + 0.5), 1)
	query.exclude = [enemy.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return length
	return maxf(from.distance_to(hit.position) - 0.6, 0.0)

## Червоне сяйво на тесаку, поки триває замах.
func _show_glow(seconds: float) -> void:
	var skeleton := enemy.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.find_bone(WEAPON_BONE) < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = WEAPON_BONE
	skeleton.add_child(attachment)
	var sparks := CombatVfx.make_trail(GLOW_COLOR, 0.35)
	sparks.amount = 16
	sparks.emission_sphere_radius = 0.25
	attachment.add_child(sparks)
	var flare := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	sphere.radial_segments = 8
	sphere.rings = 4
	flare.mesh = sphere
	flare.material_override = CombatVfx.get_glow_material(GLOW_COLOR)
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attachment.add_child(flare)
	flare.scale = Vector3.ONE * 0.3
	var tween := flare.create_tween()
	tween.tween_property(flare, "scale", Vector3.ONE, seconds).set_ease(Tween.EASE_IN)
	tween.tween_callback(attachment.queue_free)
	_glow = attachment

func _clear_line() -> void:
	if _line != null and is_instance_valid(_line):
		_line.queue_free()
	_line = null
