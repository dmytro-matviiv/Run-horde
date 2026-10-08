extends EnemyAbility

## ДЗЕРКАЛЬНИЙ РОЗКОЛ (лише мега-боси). Бос розколюється на кілька
## примар-двійників, розставлених по залі. Якщо в описі боса є
## "clone_model" (фінальний бос: справжній — білий, двійники — темні),
## двійники ЖИВІ (kind "decoy"): біжать до героя й б'ють (слабше за боса),
## але падають з одного удару. Без неї — як раніше: тьмяні нерухомі
## примари, що не б'ють (kind "totem"). У нестямі (фаза 3) двійників
## троє замість двох.

const WINDUP := 0.5
const DIM_TINT := Color(0.5, 0.5, 0.62)
## Скільки шкоди від боса б'є живий двійник.
const CLONE_DAMAGE_SHARE := 0.3

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
	decoy.hp = 1.0
	decoy.no_elite = true
	decoy.xp = 0
	if decoy.has("clone_model"):
		decoy.model = decoy.clone_model
		decoy.kind = "decoy"
		decoy.damage = float(decoy.get("damage", 10.0)) * CLONE_DAMAGE_SHARE
		decoy.speed = float(decoy.get("speed", 3.0)) * 0.9
		decoy.tint = Color.WHITE
		decoy.glow = Color.BLACK
	else:
		decoy.kind = "totem"
		decoy.damage = 0.0
		decoy.tint = DIM_TINT
		decoy.glow = Color.BLACK
	decoy.erase("aura")
	decoy.erase("transform_tints")
	decoy.erase("transform_glows")
	decoy.erase("abilities")
	decoy.erase("group")
	decoy.erase("summon")
	var base_angle := randf() * TAU
	for i in count:
		var angle := base_angle + TAU * i / count
		var spot := enemy.global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(3.0, 5.5)
		CombatVfx.impact(world(), enemy.global_position + Vector3.UP * 0.8, DIM_TINT, false)
		enemy.spawn_requested.emit(spot, decoy, enemy)
