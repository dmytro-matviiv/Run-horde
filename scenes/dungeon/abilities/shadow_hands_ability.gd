extends EnemyAbility

## РУКИ ТІНІ (Тіньовий Володар, фаза 2). Одна за одною count рук виростає
## з підлоги — там, куди біжить герой (на випередження), і просто під
## ним. Спершу на підлозі розпливається тінь (warn), тоді рука хапає:
## хто в ній — root секунд не зрушить і отримує шкоду. Біг по прямій
## карається — міняй напрямок.
## Налаштування: count, warn, root, damage.

const SHADOW := Color(0.4, 0.15, 0.7)
const GRAB := 1.1

var _queue := 0
var _gap := 0.0
var _hands: Array = []

func _init() -> void:
	id = "shadow_hands"
	cooldown = 10.0

func try_use(_distance: float) -> bool:
	if _queue > 0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.6)), Color(SHADOW, 0.0), 0.1)
	return true

func resolve() -> void:
	_queue = int(config.get("count", 5))
	_gap = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	var hero := player()
	if _queue > 0 and hero != null and is_instance_valid(hero):
		_gap -= delta
		if _gap <= 0.0:
			_gap = 0.45
			_queue -= 1
			# Через раз — на випередження руху, через раз — просто під героєм.
			var spot := hero.global_position
			if _queue % 2 == 0 and hero is CharacterBody3D:
				var run := (hero as CharacterBody3D).velocity
				run.y = 0.0
				spot += run * 0.9
			spot.y = DungeonBuilder.FLOOR_TOP
			var pool := BossFx.dark_effect(world(), BossFx.DARK_AREA, spot, 0.5, 0.0)
			_hands.append({"spot": spot, "left": float(config.get("warn", 0.8)), "pool": pool, "hand": null, "up": 0.0})
	for i in range(_hands.size() - 1, -1, -1):
		var h: Dictionary = _hands[i]
		if h.hand == null:
			h.left = float(h.left) - delta
			if float(h.left) <= 0.0:
				_grab(h)
		else:
			h.up = float(h.up) - delta
			if float(h.up) <= 0.0:
				var hand: Node3D = h.hand
				if is_instance_valid(hand):
					var tween := hand.create_tween()
					tween.tween_property(hand, "position:y", hand.position.y - 2.5, 0.35)
					tween.tween_callback(hand.queue_free)
				BossFx.dark_close(h.pool)
				_hands.remove_at(i)

func _grab(h: Dictionary) -> void:
	# Темна кам'яна долоня вистрибує з підлоги пальцями вгору й стискається.
	var hand := BossFx.stone_hand(0.9)
	var material := BossFx.ghost_material(Color(0.6, 0.3, 1.0), Color(0.05, 0.0, 0.1, 0.9))
	for mesh: MeshInstance3D in hand.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
	world().add_child(hand)
	hand.global_position = h.spot + Vector3.DOWN * 1.5
	hand.rotation = Vector3(-PI * 0.5, randf() * TAU, 0.0)
	var tween := hand.create_tween()
	tween.tween_property(hand, "global_position", h.spot + Vector3.UP * 0.3, 0.12).set_ease(Tween.EASE_OUT)
	h.hand = hand
	h.up = 1.0
	CombatVfx.ground_hit(world(), h.spot, 0.9)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var off: Vector3 = hero.global_position - h.spot
	off.y = 0.0
	if off.length() <= GRAB and hero.take_damage(damage()):
		if hero.has_method("root"):
			hero.root(float(config.get("root", 1.2)))
		CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.6, SHADOW, true)

func on_death() -> void:
	_queue = 0
	for h: Dictionary in _hands:
		if h.hand != null and is_instance_valid(h.hand):
			h.hand.queue_free()
		BossFx.dark_close(h.pool)
	_hands.clear()
