extends EnemyAbility

## ВИР БЕЗОДНІ (лише мега-боси). Бос розкриває під героєм (а не під собою)
## розлом, що затягує (Player3D.apply_pull) і пече, поки той стоїть у
## радіусі. На відміну від кілець чи метеоритів це не миттєвий удар —
## вир лишається на кілька секунд, і сама втеча з нього забирає час,
## протягом якого бос б'є далі. У нестямі (фаза 3) розкриваються два
## вири одразу в різних місцях — тікати нема куди безпечно.

const WINDUP := 0.8
const COLOR := Color(0.55, 0.2, 0.85)

func _init() -> void:
	id = "void_rift"
	cooldown = 12.0

func try_use(_distance: float) -> bool:
	start_cooldown()
	enemy.begin_special(id, WINDUP, Color(COLOR, 0.0), 0.1)   # розлом ляже не під босом — своє коло тут зайве
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var rifts := 2 if enemy.phases != null and enemy.phases.phase >= 3 else 1
	var radius := float(config.get("radius", 4.5))
	var pull_speed := float(config.get("pull_speed", 3.2))
	var tick_damage := damage() * 0.35
	var lifetime := float(config.get("lifetime", 6.0))
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.15)
	_spawn_rift(hero.global_position, radius, pull_speed, tick_damage, lifetime)
	if rifts > 1:
		# Другий вир — не поруч із першим, інакше поля тяжіння просто
		# зіллються в одне й герой матиме той самий єдиний безпечний бік.
		var away := (hero.global_position - enemy.global_position)
		if away.length() < 0.1:
			away = Vector3.FORWARD
		away = away.normalized()
		var offset := Vector3(-away.z, 0.0, away.x) * radius * 1.6
		_spawn_rift(hero.global_position + offset, radius, pull_speed, tick_damage, lifetime)

func _spawn_rift(center: Vector3, radius: float, pull_speed: float, tick_damage: float, lifetime: float) -> void:
	HazardRift.spawn(world(), center, player(), radius, pull_speed, tick_damage, lifetime)
