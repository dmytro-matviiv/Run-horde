extends RefCounted
class_name HouseKit

## ЗБИРАЧ БУДИНКІВ із модулів Medieval Village MegaKit (Quaternius).
## Сітка — 2 м: стіна 2×3 м, лицьова сторона модуля дивиться в +Z.
## Будинок W×D клітинок (по 2 м), floors поверхів; фасад — у +Z (на вулицю,
## до камери). Перший поверх — камінь, верхні — фахверк (тинк з балками).
## Дах — черепиця гребенем уздовж Z, фронтони на торцях.
##
## spec:
##   w, d        — клітинок по ширині (X) і глибині (Z): 2..4;
##   floors      — 1..3;
##   base        — "brick" | "plaster" (перший поверх);
##   upper       — "plaster" | "brick" (верхні поверхи);
##   door        — індекс клітинки фасаду з дверима (-1 — без дверей);
##   windows     — "few" | "many";
##   chimney     — true/false;
##   balcony     — true/false (балкон на 2-му поверсі фасаду);
##   seed        — для віконниць (відчинені/зачинені).

const V := "res://assets/models/haven/village/"
const STOREY := 3.0
const ROOFS := {"4x4": "Roof_RoundTiles_4x4", "4x6": "Roof_RoundTiles_4x6", "4x8": "Roof_RoundTiles_4x8",
	"6x4": "Roof_RoundTiles_6x4", "6x6": "Roof_RoundTiles_6x6", "6x8": "Roof_RoundTiles_6x8",
	"8x8": "Roof_RoundTiles_8x8"}

static func build(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = String(spec.get("name", "House"))
	var w: int = spec.get("w", 2)
	var d: int = spec.get("d", 2)
	var floors: int = spec.get("floors", 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 1))
	var half_w := w
	var half_d := d
	for floor_index in floors:
		var y := STOREY * floor_index
		var style: String = spec.get("base", "brick") if floor_index == 0 else spec.get("upper", "plaster")
		# Чотири сторони: [центр першої клітинки, крок, кількість, поворот].
		var sides := [
			[Vector3(-half_w + 1, y, half_d), Vector3(2, 0, 0), w, 0.0, "front"],
			[Vector3(half_w - 1, y, -half_d), Vector3(-2, 0, 0), w, 180.0, "back"],
			[Vector3(half_w, y, half_d - 1), Vector3(0, 0, -2), d, 90.0, "right"],
			[Vector3(-half_w, y, -half_d + 1), Vector3(0, 0, 2), d, -90.0, "left"],
		]
		for side: Array in sides:
			for i in int(side[2]):
				var pos: Vector3 = side[0] + side[1] * i
				var kind := _cell_kind(spec, String(side[4]), i, floor_index, rng)
				_wall(root, style, kind, pos, float(side[3]), rng)
		# Кути — колони на кожному розі, на всю висоту поверху.
		for corner: Array in [[Vector3(half_w, y, half_d), 0.0], [Vector3(half_w, y, -half_d), 90.0],
				[Vector3(-half_w, y, -half_d), 180.0], [Vector3(-half_w, y, half_d), 270.0]]:
			_put(root, "Corner_Exterior_Brick" if style == "brick" else "Corner_Exterior_Wood", corner[0], corner[1])
		# Перекриття між поверхами (видно крізь вікна).
		if floor_index > 0:
			for ix in w:
				for iz in d:
					_put(root, "Floor_WoodDark", Vector3(-half_w + 1 + ix * 2, y, -half_d + 1 + iz * 2), 0.0)
	# Дах і фронтони.
	var top := STOREY * floors
	if spec.get("tower", false):
		# Вежа — гострий шатровий дах замість двосхилого.
		_put(root, "Roof_Tower_RoundTiles", Vector3(0, top, 0), 0.0)
	else:
		var roof_key := "%dx%d" % [w * 2, d * 2]
		_put(root, ROOFS.get(roof_key, "Roof_RoundTiles_4x4"), Vector3(0, top, 0), 0.0)
		var gable := "Roof_Front_Brick%d" % (w * 2)
		_put(root, gable, Vector3(0, top, half_d), 0.0)
		_put(root, gable, Vector3(0, top, -half_d), 180.0)
	if spec.get("chimney", false) and not spec.get("tower", false):
		_put(root, "Prop_Chimney", Vector3(half_w - 1.2, top + 0.6, -half_d * 0.3), 0.0)
	if spec.get("balcony", false) and floors >= 2:
		_put(root, "Balcony_Simple_Straight", Vector3(0 if w % 2 == 0 else -half_w + 1 + 2 * (w / 2), STOREY, half_d - 1.0), 0.0)
	return root

## Що в клітинці стіни: "door" | "window" | "plain".
static func _cell_kind(spec: Dictionary, side: String, index: int, floor_index: int, rng: RandomNumberGenerator) -> String:
	if side == "front" and floor_index == 0 and index == int(spec.get("door", 0)):
		return "door"
	var many: bool = spec.get("windows", "many") == "many"
	if side == "front" or side == "back":
		return "window" if (many or index % 2 == 0) else "plain"
	return "window" if (many and index % 2 == 0) or (floor_index > 0 and index % 2 == 1) else "plain"

static func _wall(root: Node3D, style: String, kind: String, pos: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var prefix := "Wall_UnevenBrick_" if style == "brick" else "Wall_Plaster_"
	match kind:
		"door":
			_put(root, prefix + "Door_Round", pos, yaw)
			_put(root, "DoorFrame_Round_Brick" if style == "brick" else "DoorFrame_Round_WoodDark", pos, yaw)
			# Модель дверей має початок на завісі (0..1.07 м) — центруємо в прорізі.
			_put(root, "Door_1_Round", pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(-0.51, 0, 0), yaw)
		"window":
			var round := rng.randf() < 0.5
			_put(root, prefix + ("Window_Wide_Round" if round else "Window_Wide_Flat"), pos, yaw)
			_put(root, "Window_Wide_Round1" if round else "Window_Wide_Flat1", pos, yaw)
			if rng.randf() < 0.7:
				var open := rng.randf() < 0.6
				_put(root, "WindowShutters_Wide_%s_%s" % ["Round" if round else "Flat", "Open" if open else "Closed"], pos, yaw)
		_:
			_put(root, prefix + "Straight", pos, yaw)

static func _put(root: Node3D, name: String, pos: Vector3, yaw: float) -> Node3D:
	var path := V + name + ".gltf"
	if not ResourceLoader.exists(path):
		push_warning("HouseKit: немає " + name)
		return null
	var node: Node3D = (load(path) as PackedScene).instantiate()
	root.add_child(node)
	node.position = pos
	node.rotation_degrees.y = yaw
	return node
