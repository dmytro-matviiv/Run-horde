extends EnemyAbility

## ЗНИКНЕННЯ (Кладовищенський привид): розчиняється на fade секунд — видно
## лише іржавий ланцюг, що пливе до героя крізь стіни, — і виринає в нього
## за спиною, одразу замахуючись. Ланцюг — підказка, звідки чекати удару.
##
## Налаштування: fade (с), min, max (з якої відстані), behind (м за спиною).

const SMOKE := Color(0.7, 0.85, 0.95)
const STRIKE_WINDUP := 0.5
## Ланцюг підпливає до героя, але не впритул.
const KEEP_AWAY := 2.5

var _busy := false
var _fade_left := 0.0

func _init() -> void:
	id = "vanish"
	cooldown = 9.0

func is_busy() -> bool:
	return _busy

func try_use(distance: float) -> bool:
	if distance < float(config.get("min", 3.0)) or distance > float(config.get("max", 11.0)):
		return false
	start_cooldown()
	_busy = true
	_fade_left = float(config.get("fade", 2.0))
	CombatVfx.smoke_puff(world(), enemy.global_position + Vector3.UP * 0.6, SMOKE)
	enemy.set_hidden(true, "Chain")
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	if not _busy:
		return
	_fade_left -= delta
	var hero := player()
	var offset := hero.global_position - enemy.global_position
	offset.y = 0.0
	if offset.length() > KEEP_AWAY:
		enemy.global_position += offset.normalized() * minf(enemy.move_speed * 0.8 * delta, offset.length() - KEEP_AWAY)
	enemy.face_point(hero.global_position)
	enemy.play_loop("Walk")
	if _fade_left <= 0.0:
		_reappear()

func _reappear() -> void:
	_busy = false
	var hero := player()
	var facing: Vector3 = hero.get_facing() if hero.has_method("get_facing") else Vector3.FORWARD
	var spot := _free_spot(hero.global_position, -facing)
	enemy.teleport_to(Vector3(spot.x, DungeonBuilder.FLOOR_TOP, spot.z))
	enemy.set_hidden(false)
	CombatVfx.smoke_puff(world(), spot + Vector3.UP * 0.6, SMOKE)
	enemy.strike_now(STRIKE_WINDUP)

## За спиною героя, а якщо там стіна — збоку (привид пройшов би й крізь
## стіну, але звідти його не вдарити).
func _free_spot(center: Vector3, behind: Vector3) -> Vector3:
	var map_rows: Array = DungeonLevels.get_level(GameState.dungeon_level).map
	var distance := float(config.get("behind", 1.8))
	for turn: float in [0.0, PI * 0.5, -PI * 0.5, PI]:
		var spot := center + behind.rotated(Vector3.UP, turn) * distance
		var cell := DungeonBuilder.cell_of(spot)
		if DungeonBuilder.is_walkable(map_rows, cell.x, cell.y):
			return spot
	return center + behind * 0.6
