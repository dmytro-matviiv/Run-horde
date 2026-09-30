extends EnemyAbility

## ДЗЕРКАЛЬНИЙ РОЗКОЛ (лише мега-боси). Бос розколюється на кілька
## примар-двійників — той самий вигляд, та сама поза, розставлені по
## залі. Двійники не б'ють і падають з одного удару (kind "totem":
## не рухаються, attack_range 0) — і тьмяніші, без сяйва, тож зблизька
## видно різницю, а на бігу від справжнього боса не відрізниш. У
## нестямі (фаза 3) двійників троє замість двох — гадати важче.

const WINDUP := 0.5
const DIM_TINT := Color(0.5, 0.5, 0.62)

func _init() -> void:
	id = "mirror_split"
	cooldown = 16.0

func try_use(_distance: float) -> bool:
	start_cooldown()
	enemy.begin_special(id, WINDUP, Color(DIM_TINT, 0.6), 1.6)
	return true

func resolve() -> void:
	var count := 3 if enemy.phases != null and enemy.phases.phase >= 3 else 2
	var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.15)
	var decoy := enemy.definition.duplicate(true)
	decoy.kind = "totem"
	decoy.hp = 1.0
	decoy.damage = 0.0
	decoy.no_elite = true
	decoy.xp = 0
	decoy.tint = DIM_TINT
	decoy.glow = Color.BLACK
	decoy.erase("abilities")
	decoy.erase("group")
	decoy.erase("summon")
	var base_angle := randf() * TAU
	for i in count:
		var angle := base_angle + TAU * i / count
		var spot := enemy.global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(3.0, 5.5)
		CombatVfx.impact(world(), enemy.global_position + Vector3.UP * 0.8, DIM_TINT, false)
		enemy.spawn_requested.emit(spot, decoy, enemy)
