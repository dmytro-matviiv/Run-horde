extends HeroAbility
class_name ShadowKitAbility

## Асасин Порожнечі (преміум-герой за геми) — три вміння одразу, яких
## немає в жодного іншого героя:
##
## 1. МІТКА СМЕРТІ — кожна атака лишає на цілі мітку: позначений ворог
##    отримує більше шкоди від будь-чого, а коли гине — лопається
##    хмарою отрути, яка труїть сусідів.
## 2. ТІНЬОВІ КЛОНИ — за кожні кілька вбивств поруч з'являються тіні,
##    що самі б'ють ворогів кілька секунд.
## 3. ДИМОВА ЗАВІСА — коли HP падає низько, асасин автоматично зникає:
##    вороги гублять його з поля зору й біжать у порожнє місце, а він
##    у цей час невразливий і б'є вдвічі сильніше.

const SHADOW_CLONE_SCENE := preload("res://scenes/run/shadow_clone.tscn")

const MARK_POWER := 0.3
const MARK_DURATION := 4.0

const DEATH_BURST_RADIUS := 62.0
const DEATH_BURST_DAMAGE := 9.0
const DEATH_BURST_POISON := 6.0
const DEATH_BURST_POISON_DURATION := 3.0

const KILLS_PER_CLONES := 12
const CLONE_COUNT := 2
const CLONE_LIFETIME := 8.0
const CLONE_DAMAGE := 14.0

const SMOKE_HP_THRESHOLD := 0.35
const SMOKE_DURATION := 3.5
const SMOKE_COOLDOWN := 22.0
const SMOKE_DAMAGE_BONUS := 1.0   # +100% шкоди, поки герой у тіні

var _kills := 0
var _smoke_cooldown_left := 0.0
var _talent_level := 0

func _on_setup() -> void:
	# Талант "Володар Тіней" (мета-прокачка асасина): клони приходять
	# після меншої кількості вбивств і б'ють сильніше.
	_talent_level = hero.get_meta_talent_level(&"talent_shadow_clones")

func _get_kills_per_clones() -> int:
	return maxi(KILLS_PER_CLONES - 2 * _talent_level, 6)

func _process(delta: float) -> void:
	if _smoke_cooldown_left > 0.0:
		_smoke_cooldown_left -= delta

## Мітка смерті: вішається на кожну ціль, по якій б'є герой.
func on_attack(target: Node2D) -> void:
	if target != null and target.has_method("apply_status"):
		target.apply_status(StatusEffects.MARK, MARK_POWER, MARK_DURATION)

func on_enemy_killed(at_position: Vector2) -> void:
	# Позначена ціль лопається отруйною хмарою.
	weapon.spawn_blast(
		at_position,
		DEATH_BURST_RADIUS,
		DEATH_BURST_DAMAGE * hero.get_damage_multiplier(),
		Color(0.5, 1.0, 0.5),
		StatusEffects.POISON,
		DEATH_BURST_POISON,
		DEATH_BURST_POISON_DURATION,
	)
	_kills += 1
	if _kills % _get_kills_per_clones() == 0:
		_summon_clones()

func on_hero_damaged(_amount: float) -> void:
	if _smoke_cooldown_left > 0.0 or hero.is_stealthed():
		return
	if hero.current_hp / hero.max_hp > SMOKE_HP_THRESHOLD:
		return
	_smoke_cooldown_left = SMOKE_COOLDOWN
	hero.enter_stealth(SMOKE_DURATION, SMOKE_DAMAGE_BONUS)

func _summon_clones() -> void:
	for i in CLONE_COUNT:
		var clone: Node = SHADOW_CLONE_SCENE.instantiate()
		hero.get_parent().add_child(clone)
		var angle := TAU / float(CLONE_COUNT) * i
		var damage: float = CLONE_DAMAGE * hero.get_damage_multiplier() * (1.0 + 0.2 * _talent_level)
		clone.spawn(hero, Vector2(cos(angle), sin(angle)) * 60.0, damage, CLONE_LIFETIME)

func get_charge_ratio() -> float:
	return float(_kills % _get_kills_per_clones()) / float(_get_kills_per_clones())

func get_status_text() -> String:
	if hero != null and hero.is_stealthed():
		return "Димова завіса!"
	var left := _get_kills_per_clones() - (_kills % _get_kills_per_clones())
	return "Клони через %d вбивств" % left
