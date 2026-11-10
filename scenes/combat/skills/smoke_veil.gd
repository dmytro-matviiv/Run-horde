extends HeroSkill3D

## ДИМОВА ЗАВІСА — Асасин Порожнечі.
## Асасин зникає: вороги гублять його, перестають бити й шукають
## наосліп. Поки він у тіні — б'є вдвічі сильніше й біжить швидше.
## Особистий талант "Володар Тіней" продовжує завісу.

const DURATION := 3.0
const DAMAGE_BONUS := 2.0
const SPEED_BONUS := 0.2
const SMOKE_COLOR := Color(0.6, 0.35, 0.95)

func _init() -> void:
	id = &"smoke_veil"
	title = "Димова Граната"
	description = "Дим ховає бійця: вороги гублять ціль, а він кілька секунд б'є вдвічі сильніше."
	color = SMOKE_COLOR
	icon_kind = "smoke"
	cooldown = 10.0

func _use(player: Node) -> bool:
	var duration: float = DURATION + 0.5 * talent_level(player) + player.smoke_bonus()
	player.set_concealed(duration, DAMAGE_BONUS, SPEED_BONUS)
	var parent := player.get_parent()
	# Справжня хмара диму: клуби, що розходяться довкола й повільно тануть.
	var cloud := Fx.make_particles("smoke_04", Color(0.45, 0.32, 0.6, 0.75), 14, 1.6, 2.4)
	cloud.one_shot = true
	cloud.explosiveness = 0.9
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cloud.emission_sphere_radius = 0.6
	cloud.direction = Vector3.UP
	cloud.spread = 90.0
	cloud.flatness = 0.5
	cloud.initial_velocity_min = 1.0
	cloud.initial_velocity_max = 2.6
	cloud.damping_min = 1.5
	cloud.damping_max = 2.5
	cloud.gravity = Vector3(0, 0.3, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.4))
	cloud.scale_amount_curve = curve
	parent.add_child(cloud)
	cloud.global_position = player.global_position + Vector3.UP * 0.8
	cloud.emitting = true
	cloud.get_tree().create_timer(2.0, false).timeout.connect(cloud.queue_free)
	Fx.bloom(parent, player.global_position + Vector3.UP * 0.06, "smoke_10", 5.5, Color(0.35, 0.25, 0.5, 0.7), 1.2)
	return true
