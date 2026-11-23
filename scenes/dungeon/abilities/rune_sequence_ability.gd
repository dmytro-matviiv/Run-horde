extends EnemyAbility

## РУННА ПОСЛІДОВНІСТЬ (Володар Рун). Довкола героя на підлозі спалахують
## count рун — по черзі, з номерами (show с кожна). Потім герой має за
## time секунд стати на них У ТОМУ Ж ПОРЯДКУ. Правильна — гасне зеленим.
## Не та руна або час вийшов — вибух рун (damage). Усі пройшов — Володар
## на stun секунд знесилений.

const COLOR := Color(0.35, 0.9, 1.0, 0.9)
const GOOD := Color(0.45, 1.0, 0.5, 0.9)
const BAD := Color(1.0, 0.35, 0.35, 0.9)
const RUNE_RADIUS := 0.9

var _runes: Array = []
var _next := 0
var _show_left := 0.0
var _time_left := 0.0
var _active := false

func _init() -> void:
	id = "rune_sequence"
	cooldown = 20.0

func try_use(_distance: float) -> bool:
	if _active:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.8)), Color(COLOR, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_clear()
	var count := int(config.get("count", 4)) + (1 if enemy.phases != null and enemy.phases.phase >= 2 else 0)
	var center := hero.global_position
	var spots: Array = []
	for i in count:
		var angle := TAU * i / count + randf_range(-0.3, 0.3)
		spots.append(center + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(2.5, 4.0))
	spots.shuffle()
	for i in count:
		var spot: Vector3 = spots[i]
		spot.y = DungeonBuilder.FLOOR_TOP
		# Руна — світний знак, що крутиться; спершу ледь видно.
		var mark := BossFx.rune_glyph(Color(COLOR, 0.25), RUNE_RADIUS * 2.2)
		world().add_child(mark)
		mark.global_position = spot + Vector3.UP * 0.05
		var label := Label3D.new()
		label.text = str(i + 1)
		label.font_size = 110
		label.pixel_size = 0.005
		label.outline_size = 20
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color(1, 1, 1, 0.0)
		world().add_child(label)
		label.global_position = spot + Vector3.UP * 0.9
		_runes.append({"spot": spot, "mark": mark, "label": label})
	_next = 0
	_show_left = float(config.get("show", 0.6)) * count
	_time_left = float(config.get("time", 6.0))
	_active = true

func tick(delta: float) -> void:
	super.tick(delta)
	if not _active:
		return
	var show := float(config.get("show", 0.6))
	if _show_left > 0.0:
		_show_left -= delta
		var shown := int((show * _runes.size() - _show_left) / show)
		for i in _runes.size():
			(_runes[i].label as Label3D).modulate.a = 1.0 if i <= shown else 0.0
			if i <= shown:
				((_runes[i].mark as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = COLOR
		return
	_time_left -= delta
	var hero := player()
	if hero != null and is_instance_valid(hero):
		for i in range(_next, _runes.size()):
			var offset: Vector3 = hero.global_position - _runes[i].spot
			offset.y = 0.0
			if offset.length() > RUNE_RADIUS:
				continue
			if i == _next:
				((_runes[i].mark as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = GOOD
				Fx.bloom(world(), _runes[i].spot + Vector3.UP * 0.08, "magic_04", RUNE_RADIUS * 2.6, GOOD, 0.5, true, true)
				_next += 1
				if _next >= _runes.size():
					_succeed()
					return
			else:
				_fail()
				return
			break
	if _time_left <= 0.0:
		_fail()

func _succeed() -> void:
	CombatVfx.shockwave(world(), enemy.global_position, 3.0, GOOD, 0.5)
	enemy.stun_for(float(config.get("stun", 3.0)))
	_clear()

func _fail() -> void:
	var hero := player()
	for rune: Dictionary in _runes:
		Fx.bloom(world(), rune.spot + Vector3.UP * 0.08, "magic_04", 3.0, BAD, 0.45, true, true)
	if hero != null and is_instance_valid(hero):
		hero.take_damage(damage())
		CombatVfx.impact(world(), hero.global_position + Vector3.UP, BAD, true)
	_clear()

func on_death() -> void:
	_clear()

func _clear() -> void:
	_active = false
	for rune: Dictionary in _runes:
		if is_instance_valid(rune.mark):
			rune.mark.queue_free()
		if is_instance_valid(rune.label):
			rune.label.queue_free()
	_runes.clear()
