extends EnemyAbility

## ШАХІВНИЦЯ (Владика Магми). Підлога довкола героя ділиться на плити
## (size), і плити через одну розжарюються. Кожні swap секунд гарячі й
## холодні міняються місцями (перед цим гарячі блимають, а холодні
## жевріють). Стій на холодній плиті й перестрибуй вчасно. rounds змін.
## Налаштування: size, cells (плит у ряду), swap, rounds, warn, every, damage.

const HOT := Color(1.0, 0.35, 0.05, 0.75)
const COLD := Color(0.25, 0.1, 0.05, 0.25)

var _center := Vector3.ZERO
var _sets: Array = []
var _mats: Array = []
var _parity := 0
var _time_left := 0.0
var _round := 0
var _active := false
var _burn_left := 0.0

func _init() -> void:
	id = "checker"
	cooldown = 20.0

func try_use(_distance: float) -> bool:
	if _active:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.8)), Color(HOT, 0.0), 0.1)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	_clear()
	var size := float(config.get("size", 2.0))
	var cells := int(config.get("cells", 7))
	_center = Vector3(hero.global_position.x, DungeonBuilder.FLOOR_TOP, hero.global_position.z)
	var quad := PlaneMesh.new()
	quad.size = Vector2(size * 0.94, size * 0.94)
	for k in 2:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = quad
		var spots: Array = []
		for i in cells:
			for j in cells:
				if (i + j) % 2 == k:
					spots.append(Vector3((i - (cells - 1) * 0.5) * size, 0.0, (j - (cells - 1) * 0.5) * size))
		multi.instance_count = spots.size()
		for n in spots.size():
			multi.set_instance_transform(n, Transform3D(Basis(), spots[n]))
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = COLD
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world().add_child(node)
		node.global_position = _center + Vector3.UP * 0.06
		_sets.append(node)
		_mats.append(mat)
	_parity = 0
	_round = 0
	# Перша зміна — з запасом warn: спершу лише видно, які плити загоряться.
	_time_left = float(config.get("swap", 2.2)) + float(config.get("warn", 0.6))
	_active = true

func _first_warning() -> bool:
	return _round == 0 and _time_left > float(config.get("swap", 2.2))

func tick(delta: float) -> void:
	super.tick(delta)
	if not _active:
		return
	_time_left -= delta
	var warn := float(config.get("warn", 0.6))
	var preview := _first_warning()
	for k in 2:
		var mat: StandardMaterial3D = _mats[k]
		if k == _parity and not preview:
			var blink := _time_left < warn and int(_time_left * 12.0) % 2 == 0
			mat.albedo_color = HOT.lerp(COLD, 0.6) if blink else HOT
		elif k == _parity and preview:
			mat.albedo_color = COLD.lerp(HOT, 0.45)
		else:
			mat.albedo_color = COLD.lerp(HOT, 0.35) if _time_left < warn else COLD
	var hero := player()
	_burn_left -= delta
	if hero != null and is_instance_valid(hero) and _burn_left <= 0.0 and not preview and _hot_under(hero.global_position):
		_burn_left = float(config.get("every", 0.5))
		if hero.take_damage(damage()):
			CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.3, HOT, false)
	if _time_left <= 0.0:
		_round += 1
		if _round >= int(config.get("rounds", 4)):
			_clear()
			return
		_parity = 1 - _parity
		_time_left = float(config.get("swap", 2.2))

func _hot_under(point: Vector3) -> bool:
	var size := float(config.get("size", 2.0))
	var cells := int(config.get("cells", 7))
	var local := point - _center
	var i := int(floor(local.x / size + cells * 0.5))
	var j := int(floor(local.z / size + cells * 0.5))
	if i < 0 or j < 0 or i >= cells or j >= cells:
		return false
	return (i + j) % 2 == _parity

func on_death() -> void:
	_clear()

func _clear() -> void:
	_active = false
	for node in _sets:
		if is_instance_valid(node):
			node.queue_free()
	_sets.clear()
	_mats.clear()
