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

func try_use(distance: float) -> bool:
	if distance < MIN_DISTANCE or distance > MAX_DISTANCE or not enemy.sees_player():
		return false
	start_cooldown()
	enemy.begin_special(id, WINDUP, Color(_color(), 0.85), 1.2)
	return true

func resolve() -> void:
	var hero := player()
	var target := hero.global_position
	# Біжить — цілимось трохи вперед по його руху.
	if hero is CharacterBody3D:
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
		LobShell.launch(world(), from, spot, hero, float(config.get("radius", 1.6)), damage(), _color(),
			float(config.get("pool", 0.0)), shell)

func _color() -> Color:
	return config.get("color", Color(1.0, 0.45, 0.12))
