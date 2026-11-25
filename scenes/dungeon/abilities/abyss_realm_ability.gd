extends EnemyAbility

## БЕЗОДНЯ (Володар Рун, фаза 3, раз за бій). Володар довго чаклує —
## на героєві розгорається руна. Тоді світ темніє, і герой опиняється в
## Безодні: підлога зали стає вирною порожнечею, з неї здіймаються іскри.
## По різні боки — Володар і його копія, однакові й з однаковим
## здоров'ям. Убив обох — перемога; убив справжнього — копія розсипається.
## Копія чаклує клеймо й хвилі, як і він.
## Налаштування: windup, copy_damage.

const COLOR := Color(0.55, 0.3, 1.0)

var _done := false
var _layer: CanvasLayer
var _veil: ColorRect
var _tint: ColorRect
var _floor: MeshInstance3D
var _motes: CPUParticles3D
var _hint: Label3D
var _hint_left := 0.0

func _init() -> void:
	id = "abyss_realm"
	cooldown = 999.0

func try_use(_distance: float) -> bool:
	if _done:
		return false
	_done = true
	start_cooldown()
	var windup := float(config.get("windup", 1.8))
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	BossFx.hero_rune_mark(player(), COLOR, windup)
	BossFx.dark_effect(world(), BossFx.DARK_AREA, enemy.global_position, 1.6, windup + 0.4)
	return true

func resolve() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4
	world().add_child(_layer)
	_tint = ColorRect.new()
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = Color(0.25, 0.05, 0.45, 0.0)
	_layer.add_child(_tint)
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = Color(0.02, 0.0, 0.05, 0.0)
	_layer.add_child(_veil)
	var tween := _veil.create_tween()
	tween.tween_property(_veil, "color:a", 1.0, 0.35)
	tween.tween_callback(_enter)
	tween.tween_interval(0.25)
	tween.tween_property(_veil, "color:a", 0.0, 0.6)

## Середина зали боса (з опису рівня), або місце Володаря.
func _arena() -> Rect2:
	var hero := player()
	var dungeon: Node = hero.get_parent() if hero != null and is_instance_valid(hero) else null
	var level: Variant = dungeon.get("_level") if dungeon != null else null
	if level is Dictionary and (level as Dictionary).has("boss_arena"):
		var rect: Rect2i = level.boss_arena
		var a := DungeonBuilder.cell_center(rect.position)
		var b := DungeonBuilder.cell_center(rect.position + rect.size - Vector2i.ONE)
		return Rect2(Vector2(a.x, a.z), Vector2(b.x - a.x, b.z - a.z))
	return Rect2(Vector2(enemy.global_position.x - 8.0, enemy.global_position.z - 6.0), Vector2(16.0, 12.0))

func _enter() -> void:
	if not enemy.is_alive():
		return
	var area := _arena()
	var center := Vector3(area.get_center().x, DungeonBuilder.FLOOR_TOP, area.get_center().y)
	# Підлога-порожнеча на всю залу, іскри знизу, фіолетова пелена.
	_floor = BossFx.floor_plane(BossFx.void_material(), area.size + Vector2(2.0, 2.0))
	world().add_child(_floor)
	_floor.global_position = center + Vector3.UP * 0.03
	_motes = CombatVfx.make_motes(Color(0.7, 0.45, 1.0), 40, minf(area.size.x, area.size.y) * 0.5, 3.0, 0.12)
	world().add_child(_motes)
	_motes.global_position = center
	_tint.color.a = 0.16
	# Герой — у середині ближче до входу, Володар і копія — по боках.
	var side := minf(area.size.x * 0.3, 7.0)
	var hero := player()
	if hero != null and is_instance_valid(hero):
		hero.global_position = center + Vector3(0.0, 0.2, area.size.y * 0.25)
	var spots: Array = [center + Vector3(-side, 0.0, -area.size.y * 0.15), center + Vector3(side, 0.0, -area.size.y * 0.15)]
	spots.shuffle()
	enemy.teleport_to(spots[0])
	enemy.emit_signal("spawn_requested", spots[1], _copy_definition(), enemy)
	var hp_now := enemy.current_hp
	for node in world().get_children():
		if not is_instance_valid(node) or not node is Enemy3D:
			continue
		var other := node as Enemy3D
		if other != enemy and other.is_alive() and String(other.definition.get("kind", "")) == "decoy":
			other.max_hp = enemy.max_hp
			other.current_hp = hp_now
	for spot: Vector3 in spots:
		BossFx.dark_effect(world(), BossFx.DARK_AREA, spot, 1.2, 1.2)
		CombatVfx.shockwave(world(), spot, 3.0, COLOR, 0.4)
	_hint = Label3D.new()
	_hint.font_size = 64
	_hint.pixel_size = 0.005
	_hint.outline_size = 16
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.no_depth_test = true
	_hint.modulate = Color(0.85, 0.7, 1.0)
	_hint.text = "БЕЗОДНЯ — один із них справжній"
	world().add_child(_hint)
	_hint_left = 4.0

func _copy_definition() -> Dictionary:
	var definition: Dictionary = enemy.definition.duplicate(true)
	for key in ["abilities", "group", "summon", "phase_thresholds", "aura"]:
		definition.erase(key)
	definition.kind = "decoy"
	definition.hp = 1.0
	definition.no_elite = true
	definition.no_loot = true
	definition.xp = 0
	definition.damage = float(definition.get("damage", 30.0)) * float(config.get("copy_damage", 0.7))
	definition["abilities"] = [
		{"id": "rune_brand", "cooldown": 12.0, "first": 4.0, "windup": 1.2, "warn": 1.2, "radius": 2.2, "damage": 1.0},
		{"id": "rune_waves", "cooldown": 16.0, "first": 9.0, "count": 2, "interval": 1.3, "speed": 6.0, "gap": 60.0, "damage": 0.7},
	]
	return definition

func tick(delta: float) -> void:
	super.tick(delta)
	if _hint != null and is_instance_valid(_hint):
		_hint_left -= delta
		var hero := player()
		if hero != null and is_instance_valid(hero):
			_hint.global_position = hero.global_position + Vector3.UP * 3.0
		if _hint_left <= 0.0:
			_hint.queue_free()
			_hint = null

func on_death() -> void:
	# Безодня розсіюється — зала повертається.
	if _floor != null and is_instance_valid(_floor):
		var tween := _floor.create_tween()
		tween.tween_property(_floor, "scale", Vector3(0.01, 1.0, 0.01), 1.2)
		tween.tween_callback(_floor.queue_free)
	if _motes != null and is_instance_valid(_motes):
		_motes.emitting = false
		_motes.get_tree().create_timer(1.6).timeout.connect(_motes.queue_free)
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	if _hint != null and is_instance_valid(_hint):
		_hint.queue_free()
