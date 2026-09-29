extends EnemyAbility

## РОЗПАД: загинувши, ворог розпадається на двох менших (удвічі слабших).
## Менші вже не розпадаються. Вибухова бочка поруч — найкращі ліки.

const PIECES := 2

func _init() -> void:
	id = "split"
	cooldown = 0.0

func on_death() -> void:
	var child := enemy.definition.duplicate(true)
	child.hp = float(child.get("hp", 30.0)) * float(config.get("hp", 0.45))
	child.height = float(child.get("height", 1.5)) * 0.72
	child.speed = float(child.get("speed", 2.8)) * 1.15
	child.xp = maxi(1, int(child.get("xp", 3)) / 3)
	child.name = "Малий %s" % String(child.get("name", "")).to_lower()
	child.no_elite = true
	child.erase("abilities")
	child.erase("group")
	for i in PIECES:
		var side := Vector3(cos(PI * i), 0.0, sin(PI * i + 0.3)) * 0.9
		enemy.spawn_requested.emit(enemy.global_position + side, child, null)
