extends HeroAbility
class_name RuneChargeAbility

## Руновод — "Рунний Заряд". Кожен постріл накопичує заряд; на повному
## заряді наступна атака додатково викликає Рунну Нову — великий вибух
## навколо героя, який підпалює всіх довкола. Тобто маг грає ритмом:
## кілька звичайних пострілів → потужний вибух, і це видно на екрані.

const CHARGE_PER_ATTACK := 1.0
const CHARGE_NEEDED := 7.0
const NOVA_RADIUS := 190.0
const NOVA_DAMAGE := 48.0
const NOVA_BURN_DPS := 6.0
const NOVA_BURN_DURATION := 3.0

var _charge := 0.0

func on_attack(_target: Node2D) -> void:
	_charge += CHARGE_PER_ATTACK
	if _charge < CHARGE_NEEDED:
		return
	_charge = 0.0
	_cast_nova()

func _cast_nova() -> void:
	if weapon == null:
		return
	weapon.spawn_blast(
		hero.global_position,
		NOVA_RADIUS,
		NOVA_DAMAGE * hero.get_damage_multiplier(),
		Color(0.7, 0.5, 1.0),
		StatusEffects.BURN,
		NOVA_BURN_DPS,
		NOVA_BURN_DURATION,
	)

func get_charge_ratio() -> float:
	return clampf(_charge / CHARGE_NEEDED, 0.0, 1.0)

func get_status_text() -> String:
	if _charge >= CHARGE_NEEDED - 0.01:
		return "Рунна Нова готова!"
	return "Рунний Заряд %d/%d" % [int(_charge), int(CHARGE_NEEDED)]
