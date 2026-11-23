extends EnemyAbility

## ПОГЛЯД БОГА (Око Бога, не ходить). Око повільно обертається, і з нього
## б'є золотий промінь на length метрів, як маяк. Хто стоїть у промені —
## кам'яніє: шкала росте, поза променем спадає. Набралось stone секунд —
## герой обертається на камінь на stun секунд (і шкода). Перетинай
## промінь швидко, не стій у ньому.
## Налаштування: length, width, spin (рад/с), stone, stun, damage.

const COLOR := Color(1.0, 0.85, 0.35, 0.8)

var _beam: MeshInstance3D
var _angle := 0.0
var _stone := 0.0
var _label: Label3D

func _init() -> void:
	id = "god_gaze"
	cooldown = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var length := float(config.get("length", 9.0))
	if hero.global_position.distance_to(enemy.global_position) > length + 6.0:
		if _beam != null:
			_beam.visible = false
		return
	_angle += float(config.get("spin", 0.7)) * delta
	var dir := Vector3(sin(_angle), 0.0, cos(_angle))
	if _beam == null:
		_beam = CombatVfx.make_line_telegraph(COLOR, length, float(config.get("width", 1.2)), "chevrons", false)
		world().add_child(_beam)
		CombatVfx.set_param(_beam, &"progress", 1.0)
	_beam.visible = true
	_beam.global_position = Vector3(enemy.global_position.x, DungeonBuilder.FLOOR_TOP + 0.06, enemy.global_position.z) + dir * length * 0.5
	_beam.rotation.y = _angle
	var offset := hero.global_position - enemy.global_position
	offset.y = 0.0
	var along := offset.dot(dir)
	var across := (offset - dir * along).length()
	var inside := along > 0.0 and along <= length and across <= float(config.get("width", 1.2)) * 0.5 + 0.2
	_stone = _stone + delta if inside else maxf(_stone - delta * 1.5, 0.0)
	var limit := float(config.get("stone", 1.2))
	if _stone > 0.05:
		if _label == null:
			_label = Label3D.new()
			_label.font_size = 70
			_label.pixel_size = 0.005
			_label.outline_size = 14
			_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_label.no_depth_test = true
			world().add_child(_label)
		_label.visible = true
		_label.text = "Камінь %d%%" % int(100.0 * _stone / limit)
		_label.modulate = Color(0.9, 0.85, 0.7)
		_label.global_position = hero.global_position + Vector3.UP * 2.7
	elif _label != null:
		_label.visible = false
	if _stone >= limit:
		_stone = 0.0
		CombatVfx.flash_model(hero.get("model"), Color(0.6, 0.6, 0.55), 1.5)
		CombatVfx.impact(world(), hero.global_position + Vector3.UP, COLOR, true)
		hero.take_damage(damage())
		if hero.has_method("stun"):
			hero.stun(float(config.get("stun", 2.0)))

func on_death() -> void:
	if _beam != null and is_instance_valid(_beam):
		_beam.queue_free()
	if _label != null and is_instance_valid(_label):
		_label.queue_free()
	_beam = null
	_label = null
