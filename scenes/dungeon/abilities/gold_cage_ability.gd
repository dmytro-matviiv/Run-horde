extends EnemyAbility

## ЗОЛОТА КЛІТКА (Золотий Скупар). Довкола героя з підлоги виростає
## кільце золотих прутів (тверді — не пройти). Зламай хоч один прут і
## вийди, поки не минуло time с, — бо тоді клітку чавить: хто ще всередині,
## отримує велику шкоду (damage). Прутів — bars, у кожного hp.

const COLOR := Color(1.0, 0.8, 0.25, 0.9)
const BAR_SCENE := "res://scenes/dungeon/hazards/gold_bar.tscn"

var _center := Vector3.ZERO
var _left_time := 0.0
var _marker: MeshInstance3D
## Підказка над кліткою з відліком: що робити й скільки лишилось.
var _label: Label3D

func _init() -> void:
	id = "gold_cage"
	cooldown = 16.0

func try_use(distance: float) -> bool:
	if _left_time > 0.0 or distance > float(config.get("max", 14.0)) or not enemy.sees_player():
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.7)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_center = hero.global_position
	_center.y = DungeonBuilder.FLOOR_TOP
	var radius := float(config.get("radius", 1.5))
	var bars := int(config.get("bars", 8))
	_left_time = float(config.get("time", 3.5))
	for i in bars:
		var angle := TAU * i / bars
		var spot := _center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		enemy.spawn_requested.emit(spot, {
			"name": "Золотий прут", "model": BAR_SCENE, "kind": "totem",
			"hp": float(config.get("bar_hp", 18.0)), "damage": 0.0, "speed": 0.0, "height": 2.4, "xp": 0,
			"no_elite": true, "blocker": Vector3(0.45, 2.4, 0.45), "lifetime": _left_time + 0.3,
		}, null)
	_marker = CombatVfx.make_telegraph(COLOR, radius, PI, true)
	world().add_child(_marker)
	_marker.global_position = _center + Vector3.UP * 0.05
	CombatVfx.shockwave(world(), _center, radius + 0.5, COLOR, 0.35)
	_label = Label3D.new()
	_label.font_size = 72
	_label.pixel_size = 0.005
	_label.outline_size = 16
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = Color(1.0, 0.85, 0.35)
	world().add_child(_label)
	_label.global_position = _center + Vector3.UP * 3.0

func tick(delta: float) -> void:
	super.tick(delta)
	if _left_time <= 0.0:
		return
	_left_time -= delta
	if _marker != null and is_instance_valid(_marker):
		CombatVfx.set_param(_marker, &"progress", 1.0 - _left_time / float(config.get("time", 3.5)))
	if _label != null and is_instance_valid(_label):
		var hero_in := false
		var h := player()
		if h != null and is_instance_valid(h):
			var off := h.global_position - _center
			off.y = 0.0
			hero_in = off.length() < float(config.get("radius", 1.5))
		_label.text = ("ЗЛАМАЙ ПРУТ І ВИЙДИ!  %d" % ceili(_left_time)) if hero_in else "Вибрався!"
		_label.modulate = Color(1.0, 0.85, 0.35) if hero_in else Color(0.5, 1.0, 0.5)
	if _left_time <= 0.0:
		var hero := player()
		var radius := float(config.get("radius", 1.5))
		if hero != null and is_instance_valid(hero):
			var offset := hero.global_position - _center
			offset.y = 0.0
			if offset.length() < radius:
				hero.take_damage(damage())
		CombatVfx.impact(world(), _center + Vector3.UP, COLOR, true)
		CombatVfx.shockwave(world(), _center, radius + 0.6, COLOR, 0.4)
		var rig := enemy.get_tree().get_first_node_in_group(&"camera_rig")
		if rig != null:
			rig.shake(0.2)
		_clear()

func on_death() -> void:
	_left_time = 0.0
	_clear()

func _clear() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
	if _label != null and is_instance_valid(_label):
		_label.queue_free()
	_label = null
