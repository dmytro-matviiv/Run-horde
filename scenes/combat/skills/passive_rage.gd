extends HeroPassive3D

## ЛЮТЬ — пасивка Клинкової Вартової.
## Шкала люті повільно наповнюється сама (повна приблизно за 45 с), а
## кожен удар по ворогу й кожен пропущений удар наповнюють її значно
## швидше. Повна шкала вмикає "Ривок Люті" (кнопка починає світитись).

const PER_SECOND := 1.0 / 45.0
const PER_HIT := 0.035
const PER_HEAVY_HIT := 0.06
const PER_DAMAGE_TAKEN := 0.008   # за кожну одиницю пропущеної шкоди

var _charge := 0.0

func _init() -> void:
	id = &"rage"
	title = "Лють"
	description = "Шкала люті повільно наповнюється сама, а удари по ворогах — набагато швидше. Повна — можна зірватися в ривок."
	color = Color(1.0, 0.5, 0.2)

func get_charge() -> float:
	return _charge

func consume_charge() -> void:
	_charge = 0.0

func on_hit(player: Node, _enemy: Node, _amount: float, heavy: bool) -> void:
	# Здібність "Невгамовна лють" із походу пришвидшує накопичення.
	_add((PER_HEAVY_HIT if heavy else PER_HIT) * player.rage_gain_factor())

func on_damage_taken(player: Node, amount: float) -> void:
	_add(PER_DAMAGE_TAKEN * amount * player.rage_gain_factor())

func tick(player: Node, delta: float) -> void:
	_add(PER_SECOND * delta * player.rage_gain_factor())

func _add(amount: float) -> void:
	_charge = clampf(_charge + amount, 0.0, 1.0)
