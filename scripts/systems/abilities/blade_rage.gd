extends HeroAbility
class_name BladeRageAbility

## Клинкова Вартова — "Лють". Вона не чекає ворогів, а сама їх шукає:
## завдана й отримана шкода наповнюють шкалу люті, а на повній шкалі
## героїня САМА робить ривок крізь найближчого ворога — з шкодою по
## дорозі, короткою невразливістю і прискореними атаками після ривка.
## Це головна причина грати за ближній бій: чим гарячіший бій, тим
## частіші ривки.

const DASH_VFX := preload("res://data/vfx/wind_slash.tres")

const RAGE_PER_DAMAGE_DEALT := 0.35
const RAGE_PER_DAMAGE_TAKEN := 2.5
const RAGE_NEEDED := 100.0
const DASH_DISTANCE := 190.0
const DASH_DAMAGE := 55.0
const DASH_BLAST_RADIUS := 70.0
const DASH_STEPS := 3
const DASH_IFRAMES := 1.2
const ATTACK_SPEED_BONUS := 0.4
const ATTACK_SPEED_DURATION := 4.0

var _rage := 0.0
# Ривок сам завдає шкоди, а шкода знову наповнює лють — без цього
# запобіжника ривок міг би викликати сам себе, поки не впаде гра.
var _dashing := false

func on_damage_dealt(amount: float) -> void:
	_add_rage(amount * RAGE_PER_DAMAGE_DEALT)

func on_hero_damaged(amount: float) -> void:
	_add_rage(amount * RAGE_PER_DAMAGE_TAKEN)

func _add_rage(amount: float) -> void:
	if _dashing:
		return
	_rage += amount
	if _rage < RAGE_NEEDED:
		return
	_rage = 0.0
	_dashing = true
	_dash()
	_dashing = false

## Ривок: героїня зміщується в бік найближчого ворога й лишає за собою
## ланцюжок вибухів — тож шкоду отримують усі на шляху, а не лише ціль.
func _dash() -> void:
	var target := CombatQuery.nearest_enemy(hero.get_tree(), hero.global_position, 600.0)
	var direction := Vector2.RIGHT if target == null else hero.global_position.direction_to(target.global_position)
	var start := hero.global_position
	var damage: float = DASH_DAMAGE * hero.get_damage_multiplier()
	for i in range(1, DASH_STEPS + 1):
		var point := start + direction * (DASH_DISTANCE * float(i) / DASH_STEPS)
		weapon.spawn_blast(point, DASH_BLAST_RADIUS, damage, Color(1.0, 0.75, 0.3))
	weapon.play_vfx(DASH_VFX, start + direction * DASH_DISTANCE * 0.5, direction.angle(), 1.5)
	hero.dash_to(start + direction * DASH_DISTANCE)
	hero.grant_iframes(DASH_IFRAMES)
	hero.add_temp_attack_speed(ATTACK_SPEED_BONUS, ATTACK_SPEED_DURATION)

func get_charge_ratio() -> float:
	return clampf(_rage / RAGE_NEEDED, 0.0, 1.0)

func get_status_text() -> String:
	return "Лють %d%%" % int(get_charge_ratio() * 100.0)
