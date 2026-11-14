extends Node3D
class_name HavenSpot

## Місце в Прихистку, де можна щось зробити: багаття (повечеряти),
## точило (нагострити зброю), казан (зварити зілля), загублена скриня
## (відкрити). Герой підходить — на кнопці дії з'являється напис label;
## що саме відбувається — вирішує Прихисток (haven.gd) за id.

signal player_near(spot: HavenSpot)
signal player_left(spot: HavenSpot)

var id := ""
## Вид місця: "boon" (багаття, точило, казан) або "cache" (скриня).
var kind := ""
var label := ""
var radius := 2.4
## Вимкнене місце кнопки не показує (ще не відкрите квестом, уже забране).
var enabled := true:
	set(value):
		enabled = value
		if not enabled and _near:
			_near = false
			player_left.emit(self)

var _player: Node3D
var _near := false

func set_player(player: Node3D) -> void:
	_player = player

func _process(_delta: float) -> void:
	if _player == null or not enabled:
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	var near := offset.length() < radius
	if near != _near:
		_near = near
		if near:
			player_near.emit(self)
		else:
			player_left.emit(self)
