extends EnemyAbility

## РОЗКОЛ (Тіньовий Володар, фаза 3). Володар ділиться: поруч з'являються
## count двійників, ЗОВНІ ТАКИХ САМИХ і з таким самим здоров'ям, і всі
## перемішуються в диму. Відрізнити можна одним: тінь на підлозі відкидає
## лише справжній. Двійники б'ють і бігають, як він; поки живі — не
## зникнуть. Упаде справжній — зникнуть усі.
## Налаштування: count.

const SHADOW := Color(0.45, 0.2, 0.75)

var _shadow: MeshInstance3D
var _hint_left := 0.0
var _hint: Label3D

func _init() -> void:
	id = "shadow_split"
	cooldown = 26.0

func try_use(_distance: float) -> bool:
	if enemy.summons_alive > 0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.8)), Color(SHADOW, 0.0), 0.1)
	return true

func resolve() -> void:
	_make_shadow()
	var definition: Dictionary = enemy.definition.duplicate(true)
	definition.kind = "decoy"
	definition.hp = 1.0
	definition.no_elite = true
	definition.no_loot = true
	definition.xp = 0
	definition.damage = float(definition.get("damage", 30.0)) * 0.6
	definition.name = String(definition.get("name", "Володар"))
	for key in ["aura", "transform_tints", "transform_glows", "abilities", "group", "summon", "throne", "phase_thresholds"]:
		definition.erase(key)
	definition["abilities"] = [{"id": "shadow_dash", "cooldown": 6.0, "first": 3.0, "min": 6.0, "windup": 0.7, "damage": 0.8}]
	var spots: Array = [enemy.global_position]
	var count := int(config.get("count", 2))
	var base := randf() * TAU
	for i in count:
		var angle := base + TAU * i / count
		spots.append(enemy.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 3.5)
	spots.shuffle()
	# Справжній — на випадковому з місць, двійники — на решті.
	enemy.teleport_to(spots[0])
	for i in range(1, spots.size()):
		enemy.spawn_requested.emit(spots[i], definition, enemy)
	for spot: Vector3 in spots:
		CombatVfx.smoke_puff(world(), spot + Vector3.UP * 1.2, SHADOW, 2.2)
	# Здоров'я двійників — рівно як у Володаря зараз.
	var hp_now := enemy.current_hp
	for node in world().get_children():
		var other := node as Enemy3D
		if other != null and other != enemy and other.is_alive() and other.definition.get("kind", "") == "decoy":
			other.max_hp = enemy.max_hp
			other.current_hp = hp_now
	_hint_left = 4.0
	if _hint == null:
		_hint = Label3D.new()
		_hint.font_size = 60
		_hint.pixel_size = 0.005
		_hint.outline_size = 14
		_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hint.no_depth_test = true
		_hint.modulate = Color(0.85, 0.75, 1.0)
		_hint.text = "Справжній відкидає тінь"
		world().add_child(_hint)

## Тінь справжнього: темна пляма на підлозі, що йде за ним.
func _make_shadow() -> void:
	if _shadow != null and is_instance_valid(_shadow):
		return
	_shadow = Fx.make_sprite("smoke_10", Color(0.0, 0.0, 0.0, 0.85), true)
	enemy.add_child(_shadow)
	_shadow.position = Vector3(0.6, 0.04, 0.9)
	_shadow.scale = Vector3(3.2, 1.0, 4.2)

func tick(delta: float) -> void:
	super.tick(delta)
	if _hint != null and is_instance_valid(_hint):
		_hint_left -= delta
		_hint.visible = _hint_left > 0.0
		var hero := player()
		if hero != null and is_instance_valid(hero):
			_hint.global_position = hero.global_position + Vector3.UP * 3.0

func on_death() -> void:
	if _hint != null and is_instance_valid(_hint):
		_hint.queue_free()
