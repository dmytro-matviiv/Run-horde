extends Node3D
class_name Gatherable

## Ресурс Прихистку: дерево (рубати), камінь (добувати), трава (зібрати).
## Герой підходить — з'являється кнопка дії; кожне натискання — удар
## (дерево хитається, з каменю летять скалки). Останній удар — дерево
## падає й тане, камінь розсипається, трава зникає; ресурс іде в торбу,
## квести рахують. За хвилину все відростає.

signal player_near(node: Gatherable)
signal player_left(node: Gatherable)

const KINDS := {
	"wood": {"verb": "Рубати", "hits": 3, "label": "Дерево"},
	"stone": {"verb": "Добувати", "hits": 3, "label": "Камінь"},
	"herb": {"verb": "Зібрати", "hits": 1, "label": "Трави"},
}
const RADIUS := 2.6
const REGROW := 60.0

var kind := "wood"
var _model: Node3D
var _hits_left := 0
var _player: Node3D
var _near := false
var _gone := false

## Обгортає модель, яку будівник поставив у групу Resources.
static func wrap(model: Node3D, resource_kind: String) -> Gatherable:
	var node := Gatherable.new()
	node.kind = resource_kind
	var parent := model.get_parent()
	var xf := model.global_transform
	parent.add_child(node)
	node.global_position = xf.origin
	model.reparent(node)
	model.global_transform = xf
	node._model = model
	return node

func _ready() -> void:
	_hits_left = int(KINDS[kind].hits)

func set_player(player: Node3D) -> void:
	_player = player

func verb() -> String:
	return String(KINDS[kind].verb)

func _process(_delta: float) -> void:
	if _player == null or _gone:
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	var near := offset.length() < RADIUS + (0.6 if kind == "wood" else 0.0)
	if near != _near:
		_near = near
		if near:
			player_near.emit(self)
		else:
			player_left.emit(self)

## Удар/збір. Повертає true, коли ресурс добуто.
func work() -> bool:
	if _gone:
		return false
	_hits_left -= 1
	if _hits_left > 0:
		_shake()
		return false
	_finish()
	return true

func _shake() -> void:
	var tween := create_tween()
	var base := _model.rotation
	tween.tween_property(_model, "rotation:z", base.z + 0.06, 0.06)
	tween.tween_property(_model, "rotation:z", base.z - 0.05, 0.08)
	tween.tween_property(_model, "rotation:z", base.z, 0.08)
	if kind == "stone":
		Fx.puff(get_parent(), global_position + Vector3.UP * 0.6, Color(0.6, 0.58, 0.54), 0.6, 0.9)
	elif kind == "wood":
		Fx.puff(get_parent(), global_position + Vector3.UP * 1.0, Color(0.55, 0.42, 0.3), 0.5, 0.8)

func _finish() -> void:
	_gone = true
	if _near:
		_near = false
		player_left.emit(self)
	var tween := create_tween()
	match kind:
		"wood":
			# Дерево падає від героя й тане.
			var away := Vector3.FORWARD
			if _player != null:
				away = (global_position - _player.global_position)
				away.y = 0.0
				away = away.normalized()
			var axis := away.cross(Vector3.UP).normalized()
			var fallen := Basis(axis, -PI * 0.47) * _model.basis
			tween.tween_property(_model, "basis", fallen, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tween.tween_callback(func() -> void:
				Fx.puff(get_parent(), global_position + away * 3.0, Color(0.5, 0.45, 0.35), 1.4, 0.9))
			tween.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.5).set_delay(0.6)
		"stone":
			Fx.puff(get_parent(), global_position + Vector3.UP * 0.5, Color(0.62, 0.6, 0.56), 1.1, 0.9)
			tween.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.25)
		_:
			tween.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func() -> void: _model.visible = false)
	get_tree().create_timer(REGROW, false).timeout.connect(_regrow)

## Відростає: модель знову стоїть і плавно виростає.
func _regrow() -> void:
	if not is_inside_tree():
		return
	var scale_target: Vector3 = _model.get_meta(&"scale", Vector3.ONE)
	var basis_target: Basis = _model.get_meta(&"basis", Basis())
	_model.basis = basis_target.orthonormalized()
	_model.scale = Vector3.ONE * 0.05
	_model.visible = true
	var tween := create_tween()
	tween.tween_property(_model, "scale", scale_target, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hits_left = int(KINDS[kind].hits)
	_gone = false

func remember_pose() -> void:
	_model.set_meta(&"scale", _model.scale)
	_model.set_meta(&"basis", _model.basis.orthonormalized())
