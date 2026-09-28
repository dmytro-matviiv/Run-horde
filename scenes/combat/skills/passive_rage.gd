extends HeroPassive3D

## ЛЮТЬ — пасивка Клинкової Вартової.
## Кожен свій удар і кожен пропущений наповнюють шкалу люті. Повна
## шкала вмикає "Ривок Люті" (кнопка починає світитись). Поза боєм
## лють поволі стихає — накопичити її можна тільки в бійці.

const PER_HIT := 0.05
const PER_HEAVY_HIT := 0.09
const PER_DAMAGE_TAKEN := 0.012   # за кожну одиницю пропущеної шкоди
const DECAY_PER_SECOND := 0.04
const DECAY_DELAY := 2.5

var _charge := 0.0
var _idle_time := 0.0

func _init() -> void:
	id = &"rage"
	title = "Лють"
	description = "Удари наповнюють шкалу люті. Повна — можна зірватися в ривок."
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

func tick(_player: Node, delta: float) -> void:
	_idle_time += delta
	if _idle_time > DECAY_DELAY:
		_charge = maxf(_charge - DECAY_PER_SECOND * delta, 0.0)

func _add(amount: float) -> void:
	_charge = clampf(_charge + amount, 0.0, 1.0)
	_idle_time = 0.0
