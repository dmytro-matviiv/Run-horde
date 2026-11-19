extends Node3D
class_name DroppedItem

## Річ на підлозі данжу: стовп світла кольору рідкості, іконка й назва.
## Герой підходить — річ іде в торбу (одразу зберігається).

signal picked(item: Dictionary)

const PICK_RADIUS := 1.7
const BEAM_HEIGHT := 3.2

var item: Dictionary
var _player: Node3D
var _time := 0.0
var _icon: Sprite3D

static func create(drop: Dictionary, player: Node3D) -> DroppedItem:
	var node := DroppedItem.new()
	node.item = drop
	node._player = player
	return node

func _ready() -> void:
	var color := ItemDb.color_of(item)
	var rarity_index := ItemDb.RARITIES.find(String(item.get("rarity", "common")))
	# Стовп світла: вищий і яскравіший для кращої рідкості.
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.22
	cylinder.height = BEAM_HEIGHT * (0.7 + 0.15 * rarity_index)
	cylinder.radial_segments = 10
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color, 0.55)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cylinder.material = material
	beam.mesh = cylinder
	beam.position.y = cylinder.height * 0.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var ring := CombatVfx.make_ground_marker(color, 0.7)
	ring.position.y = 0.04
	add_child(ring)
	_icon = Sprite3D.new()
	_icon.texture = ItemDb.icon_of(item)
	_icon.pixel_size = 0.0028
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.position.y = 0.9
	_icon.no_depth_test = true
	add_child(_icon)
	var label := Label3D.new()
	label.text = ItemDb.title_of(item)
	label.font_size = 44
	label.outline_size = 12
	label.pixel_size = 0.006
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = 1.75
	add_child(label)

func _process(delta: float) -> void:
	_time += delta
	_icon.position.y = 0.9 + sin(_time * 3.0) * 0.12
	if _player == null or not is_instance_valid(_player):
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() < PICK_RADIUS:
		ItemDb.give(item)
		SaveManager.save_game()
		picked.emit(item)
		Fx.puff(get_parent(), global_position + Vector3.UP * 0.6, ItemDb.color_of(item), 1.0, 0.0)
		queue_free()
