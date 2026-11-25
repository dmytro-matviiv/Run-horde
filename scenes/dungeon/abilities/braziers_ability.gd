extends EnemyAbility

## ЖАРОВНІ (Тіньовий Володар). На початку бою Володар гасить світло: зала
## темна, по колу стоять count жаровень (усі запалені). Поки Володар у
## темряві (поза колом світла запаленої жаровні), удари по ньому слабкі
## (dark_factor), і він потроху лікується (regen від здоров'я за секунду).
## У колі світла — вразливий. Щоcooldown секунд він гасить жаровню, біля
## якої стоїть герой чи найближчу до нього. Герой запалює погаслу, якщо
## постоїть біля неї light_time секунд. Тож бій — заманити Володаря у
## світло й тримати жаровні запаленими.
## Налаштування: count, ring (м від центру зали), warm (радіус світла),
## dark_factor, regen, light_time.

const FIRE := Color(1.0, 0.6, 0.2)
const SHADOW := Color(0.45, 0.2, 0.75)

var _braziers: Array = []
var _started := false
var _in_light := false
var _regen_left := 0.0
var _mark: Label3D

func _init() -> void:
	id = "braziers"
	cooldown = 13.0

func tick(delta: float) -> void:
	super.tick(delta)
	if not enemy.is_alive():
		return
	if not _started:
		_start()
	var hero := player()
	var warm := float(config.get("warm", 2.6))
	_in_light = false
	for b: Dictionary in _braziers:
		var node: Node3D = b.node
		if not is_instance_valid(node):
			continue
		var to_boss := enemy.global_position - node.global_position
		to_boss.y = 0.0
		if b.lit and to_boss.length() <= warm:
			_in_light = true
		# Герой поруч із погаслою — запалює (кільце заповнюється).
		if not b.lit and hero != null and is_instance_valid(hero):
			var to_hero := hero.global_position - node.global_position
			to_hero.y = 0.0
			if to_hero.length() <= 1.7:
				b.progress = float(b.progress) + delta
				if float(b.progress) >= float(config.get("light_time", 1.2)):
					_set_lit(b, true)
			else:
				b.progress = maxf(float(b.progress) - delta, 0.0)
			if is_instance_valid(b.ring):
				CombatVfx.set_param(b.ring, &"progress", clampf(float(b.progress) / float(config.get("light_time", 1.2)), 0.0, 1.0))
	# У темряві — лікується й видно знак «у тіні».
	if not _in_light:
		_regen_left -= delta
		if _regen_left <= 0.0:
			_regen_left = 1.0
			if enemy.current_hp < enemy.max_hp:
				enemy.heal(enemy.max_hp * float(config.get("regen", 0.004)))
	if _mark != null and is_instance_valid(_mark):
		_mark.text = "У СВІТЛІ — ВРАЗЛИВИЙ" if _in_light else "У ТІНІ — заведи у світло"
		_mark.modulate = FIRE if _in_light else SHADOW.lerp(Color.WHITE, 0.3)

func _start() -> void:
	_started = true
	var hero := player()
	if hero != null and is_instance_valid(hero):
		var dungeon := hero.get_parent()
		if dungeon != null and dungeon.has_method("_set_darkness"):
			dungeon.call("_set_darkness")
	# Жаровні — по колу довкола місця, де бос починає бій (середина зали).
	var center := enemy.global_position + Vector3(0, 0, 4.0)
	center.y = DungeonBuilder.FLOOR_TOP
	var count := int(config.get("count", 6))
	var ring := float(config.get("ring", 7.5))
	for i in count:
		var angle := TAU * i / count + PI / count
		var spot := center + Vector3(cos(angle) * ring * 1.2, 0.0, sin(angle) * ring * 0.75)
		var cell := DungeonBuilder.cell_of(spot)
		var node := BossFx.brazier(float(config.get("warm", 2.6)))
		world().add_child(node)
		node.global_position = spot
		var ring_mark := CombatVfx.make_ground_marker(Color(FIRE, 0.7), 1.7)
		node.add_child(ring_mark)
		ring_mark.position.y = 0.05
		ring_mark.visible = false
		var b := {"node": node, "lit": true, "progress": 0.0, "ring": ring_mark, "cell": cell}
		_braziers.append(b)
	_mark = Label3D.new()
	_mark.font_size = 56
	_mark.pixel_size = 0.005
	_mark.outline_size = 14
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.no_depth_test = true
	enemy.add_child(_mark)
	_mark.position = Vector3.UP * (enemy.target_height + 0.9)

func _set_lit(b: Dictionary, lit: bool) -> void:
	b.lit = lit
	b.progress = 0.0
	var node: Node3D = b.node
	if not is_instance_valid(node):
		return
	for child in node.get_children():
		if child is CPUParticles3D:
			(child as CPUParticles3D).emitting = lit
		elif child is MeshInstance3D and child != b.ring:
			# Сяйво під жаровнею (спрайт) і жар у чаші.
			var mesh := child as MeshInstance3D
			if mesh.material_override is StandardMaterial3D and (mesh.material_override as StandardMaterial3D).blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
				mesh.visible = lit
	(b.ring as Node3D).visible = not lit
	if lit:
		CombatVfx.shockwave(world(), node.global_position, 2.6, FIRE, 0.4)
	else:
		CombatVfx.smoke_puff(world(), node.global_position + Vector3.UP * 1.0, Color(0.15, 0.1, 0.2), 1.4)

## Удар по Володарю: у тіні — слабкий.
func filter_damage(amount: float, _heavy: bool) -> float:
	return amount if _in_light or not _started else amount * float(config.get("dark_factor", 0.25))

## Гасить жаровню: ту, біля якої герой, або найближчу до героя запалену.
func try_use(_distance: float) -> bool:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return false
	var best: Dictionary = {}
	var best_d := INF
	for b: Dictionary in _braziers:
		if not b.lit or not is_instance_valid(b.node):
			continue
		var d := (b.node as Node3D).global_position.distance_to(hero.global_position)
		if d < best_d:
			best_d = d
			best = b
	if best.is_empty():
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.6)), Color(SHADOW, 0.0), 0.1)
	CombatVfx.lightning(world(), [enemy.global_position + Vector3.UP * enemy.target_height * 0.8,
		(best.node as Node3D).global_position + Vector3.UP * 1.0], SHADOW, 0.18)
	_set_lit(best, false)
	return true

func on_death() -> void:
	for b: Dictionary in _braziers:
		if is_instance_valid(b.node):
			_set_lit(b, true)
	if _mark != null and is_instance_valid(_mark):
		_mark.queue_free()

## Чи стоїть точка в колі світла якоїсь запаленої жаровні (для затемнення).
func lit_at(point: Vector3) -> bool:
	var warm := float(config.get("warm", 2.6))
	for b: Dictionary in _braziers:
		if b.lit and is_instance_valid(b.node):
			var off: Vector3 = point - (b.node as Node3D).global_position
			off.y = 0.0
			if off.length() <= warm:
				return true
	return false
