extends EnemyAbility

## КИДОК ПО ДУЗІ: ворог замахується й кидає бомбу (гарбуз, розпечену
## кулю, склянку кислоти) туди, де стоїть герой, — з невеликим
## упередженням, якщо той біжить. На підлозі одразу коло, що
## заповнюється до вибуху. "pool" — скільки секунд горить калюжа,
## "shell" — чим кидає, "color" — колір, "count" — скільки бомб розом
## (бос кидає кілька, довкола героя).

const WINDUP := 0.6
const MIN_DISTANCE := 3.0
const MAX_DISTANCE := 15.0
const LEAD := 0.45

func _init() -> void:
	id = "lob"
	cooldown = 4.5

## "aim_first": куди впаде, видно ще під час замаху — коло на місці
## падіння (а не під кидальником), і кидок летить туди ж.
var _aim := Vector3.INF
var _aim_marker: MeshInstance3D

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", MIN_DISTANCE)) or distance > MAX_DISTANCE or not enemy.sees_player():
		return false
	start_cooldown()
	if config.get("aim_first", false):
		_aim = player().global_position
		_clear_aim()
		_aim_marker = CombatVfx.make_telegraph(Color(_color(), 0.9), float(config.get("radius", 1.6)), PI, true)
		world().add_child(_aim_marker)
		_aim_marker.global_position = Vector3(_aim.x, DungeonBuilder.FLOOR_TOP + 0.05, _aim.z)
		var marker := _aim_marker
		var tween := marker.create_tween()
		tween.tween_method(func(value: float) -> void:
			marker.set_instance_shader_parameter(&"progress", value), 0.0, 0.4, WINDUP)
		enemy.get_tree().create_timer(WINDUP + 0.4, false).timeout.connect(_clear_aim)
		enemy.begin_special(id, WINDUP, Color(_color(), 0.0), 0.1)
	else:
		enemy.begin_special(id, WINDUP, Color(_color(), 0.85), 1.2)
	return true

func _clear_aim() -> void:
	if _aim_marker != null and is_instance_valid(_aim_marker):
		_aim_marker.queue_free()
	_aim_marker = null

func on_death() -> void:
	_clear_aim()

func resolve() -> void:
	var hero := player()
	var target := hero.global_position
	if _aim != Vector3.INF:
		target = _aim
		_aim = Vector3.INF
		_clear_aim()
	# Біжить — цілимось трохи вперед по його руху.
	if hero is CharacterBody3D and not config.get("aim_first", false):
		var run := (hero as CharacterBody3D).velocity
		run.y = 0.0
		target += run.limit_length(6.0) * LEAD
	var from := enemy.global_position + Vector3.UP * enemy.target_height
	var shell: PackedScene = load(config.shell) if config.has("shell") else null
	var count := int(config.get("count", 1))
	for i in count:
		var spot := target
		if i > 0:
			var angle := TAU * i / (count - 1) + randf() * 0.5
			spot += Vector3(cos(angle), 0.0, sin(angle)) * 2.6
		var lob := LobShell.launch(world(), from, spot, hero, float(config.get("radius", 1.6)), damage(), _color(),
			float(config.get("pool", 0.0)), shell, enemy)
		lob.arc_height = float(config.get("arc", LobShell.ARC_HEIGHT))

func _color() -> Color:
	return config.get("color", Color(1.0, 0.45, 0.12))
