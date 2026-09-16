extends HeroAbility
class_name PhoenixAbility

## Жриця Багаття — "Слід Полум'я" і "Фенікс". Поки вона біжить, під
## ногами лишається доріжка вогню, яка сама добиває тих, хто женеться
## слідом. А раз за ран вона не вмирає: замість смерті — спалах
## відродження, який відкидає вибухом усе довкола й повертає частину
## HP. Тому за неї грають ті, хто любить "тримати юрбу".

const REBIRTH_VFX := preload("res://data/vfx/fire_slash.tres")

const TRAIL_INTERVAL := 0.7
const TRAIL_RADIUS := 42.0
const TRAIL_DAMAGE := 5.0
const TRAIL_BURN_DPS := 4.0
const TRAIL_BURN_DURATION := 2.0

const REBIRTH_HP_FRACTION := 0.45
const REBIRTH_RADIUS := 230.0
const REBIRTH_DAMAGE := 70.0
const REBIRTH_IFRAMES := 2.0

var _trail_left := 0.0
var _rebirth_used := false

func _process(delta: float) -> void:
	if weapon == null or hero == null:
		return
	_trail_left -= delta
	if _trail_left > 0.0:
		return
	_trail_left = TRAIL_INTERVAL
	weapon.spawn_blast(
		hero.global_position,
		TRAIL_RADIUS,
		TRAIL_DAMAGE * hero.get_damage_multiplier(),
		Color(1.0, 0.45, 0.15),
		StatusEffects.BURN,
		TRAIL_BURN_DPS,
		TRAIL_BURN_DURATION,
	)

## Спрацьовує замість смерті — один раз за ран.
func try_prevent_death() -> bool:
	if _rebirth_used:
		return false
	_rebirth_used = true
	hero.restore_hp_fraction(REBIRTH_HP_FRACTION)
	hero.grant_iframes(REBIRTH_IFRAMES)
	weapon.play_vfx(REBIRTH_VFX, hero.global_position, 0.0, 2.2)
	weapon.spawn_blast(
		hero.global_position,
		REBIRTH_RADIUS,
		REBIRTH_DAMAGE * hero.get_damage_multiplier(),
		Color(1.0, 0.8, 0.3),
		StatusEffects.BURN,
		TRAIL_BURN_DPS * 2.0,
		TRAIL_BURN_DURATION,
	)
	return true

func get_charge_ratio() -> float:
	return 0.0 if _rebirth_used else 1.0

func get_status_text() -> String:
	return "Фенікс витрачено" if _rebirth_used else "Фенікс готовий"
