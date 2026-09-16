extends RefCounted
class_name StatusEffects

## Статус-ефекти, які зброя й уміння вішають на ворогів. Сам ефект
## живе на ворогові (enemy.gd::apply_status), тут — лише спільні
## ідентифікатори й кольори підсвітки, щоб гравець бачив, що з ворогом
## щось відбувається, а не лише падаючі цифри HP.

const POISON := &"poison"   # шкода/сек, зелений
const BURN := &"burn"       # шкода/сек, помаранчевий
const SLOW := &"slow"       # -X% швидкості, блакитний
const MARK := &"mark"       # +X% отриманої шкоди, фіолетовий (мітка асасина)

const TINTS := {
	POISON: Color(0.55, 1.0, 0.45),
	BURN: Color(1.0, 0.6, 0.25),
	SLOW: Color(0.5, 0.8, 1.0),
	MARK: Color(0.85, 0.45, 1.0),
}

## Колір підсвітки для найсильнішого активного ефекту (порядок —
## як у TINTS: отрута, горіння, сповільнення, мітка).
static func get_tint(active_ids: Array) -> Color:
	for id in TINTS:
		if active_ids.has(id):
			return TINTS[id]
	return Color.WHITE
