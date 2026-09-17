extends Node

## Інструмент розробника: друкує розміри модульних деталей данжу.
## Щоб збирати рівень із кубиків, треба знати крок сітки — наскільки
## довга стіна й наскільки велика плитка підлоги.

const MODELS := [
	"Floor_Modular", "Wall_Modular", "WallCover_Modular", "Arch", "Arch_Door",
	"Arch_bars", "Stairs_Modular", "Column", "Torch", "Chest", "Barrel", "Crate",
	"Pedestal", "Statue_Horse", "Spikes", "Banner_wall",
]

func _ready() -> void:
	for name: String in MODELS:
		var path := "res://assets/models/dungeon/%s.fbx" % name
		if not ResourceLoader.exists(path):
			print("MEASURE: %-22s НЕМАЄ" % name)
			continue
		var scene: PackedScene = load(path)
		var node: Node3D = scene.instantiate()
		add_child(node)
		await get_tree().process_frame
		var bounds := _get_bounds(node)
		print("MEASURE: %-22s розмір %.2f x %.2f x %.2f, центр %.2f %.2f %.2f" % [
			name, bounds.size.x, bounds.size.y, bounds.size.z,
			bounds.get_center().x, bounds.get_center().y, bounds.get_center().z])
		node.queue_free()
	get_tree().quit(0)

func _get_bounds(node: Node) -> AABB:
	var bounds := AABB()
	var first := true
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var instance := child as VisualInstance3D
		var child_bounds: AABB = instance.global_transform * instance.get_aabb()
		if first:
			bounds = child_bounds
			first = false
		else:
			bounds = bounds.merge(child_bounds)
	return bounds
