extends EnemyAbility

## КРИЖАНА СТІНА (Інейна чаклунка): між собою й героєм ставить стіну
## льоду — вона виростає з підлоги й перекриває шлях (тверда). Її треба
## обійти або розбити кількома ударами; за lifetime секунд тане сама.
##
## Налаштування: hp (міцність), width, lifetime, gap (частка шляху від
## чаклунки до героя, де стане стіна).

const WALL_SCENE := "res://scenes/dungeon/hazards/ice_wall.tscn"
const COLOR := Color(0.6, 0.9, 1.0)

func _init() -> void:
	id = "ice_wall"
	cooldown = 10.0

func try_use(distance: float) -> bool:
	if distance < 4.0 or distance > 11.0 or not enemy.sees_player():
		return false
	start_cooldown()
	enemy.begin_special(id, 0.45, Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var from := enemy.global_position
	var to_hero := hero.global_position - from
	to_hero.y = 0.0
	var spot := from + to_hero * float(config.get("gap", 0.45))
	var width := float(config.get("width", 3.2))
	var definition := {
		"name": "Крижана стіна", "model": WALL_SCENE, "kind": "totem",
		"hp": float(config.get("hp", 12.0)), "damage": 0.0, "speed": 0.0, "height": 2.0, "xp": 0,
		"no_elite": true, "face_yaw": atan2(to_hero.x, to_hero.z),
		"blocker": Vector3(width, 2.2, 0.7), "lifetime": float(config.get("lifetime", 8.0)),
		"abilities": [{"id": "shatter", "radius": 0.1, "delay": 0.05, "damage": 0.0}],
	}
	CombatVfx.shockwave(world(), spot, width * 0.6, COLOR, 0.35)
	CombatVfx.impact_decal(world(), spot, 1.2, COLOR, 0.4)
	enemy.spawn_requested.emit(spot, definition, enemy)
