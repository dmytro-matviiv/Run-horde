extends EnemyAbility

## ОТРУЙНА ХМАРА (Розкладена плоть): довкола неї постійно висить зелена
## хмара — хто в ній, потроху втрачає здоров'я. Бити її краще здалеку.
##
## Налаштування: radius, every (с між укусами отрути), damage (частка удару).

const COLOR := Color(0.55, 0.85, 0.3)

var _tick_left := 0.5
var _cloud: CPUParticles3D
var _marker: MeshInstance3D

func _init() -> void:
	id = "poison_cloud"
	cooldown = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	if _cloud == null:
		_build()
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = float(config.get("every", 0.5))
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var offset := hero.global_position - enemy.global_position
	offset.y = 0.0
	if offset.length() <= float(config.get("radius", 2.4)):
		hero.take_damage(damage())

func _build() -> void:
	var radius := float(config.get("radius", 2.4))
	_marker = CombatVfx.make_ground_marker(Color(COLOR, 0.3), radius)
	CombatVfx.set_param(_marker, &"progress", 1.0)
	enemy.add_child(_marker)
	_marker.position = Vector3(0, 0.05, 0)
	_cloud = CombatVfx.make_trail(Color(COLOR, 0.75), 1.8)
	_cloud.local_coords = true
	# Пара — тонка: невеликі клуби біля самої істоти, не хмара на пів зали.
	_cloud.amount = 10
	_cloud.emission_sphere_radius = radius * 0.45
	_cloud.gravity = Vector3(0, 0.3, 0)
	_cloud.scale_amount_min = 1.4
	_cloud.scale_amount_max = 2.4
	enemy.add_child(_cloud)
	_cloud.position = Vector3.UP * 0.7

func on_death() -> void:
	if _cloud != null and is_instance_valid(_cloud):
		_cloud.emitting = false
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
