extends RefCounted
class_name HeroSkill3D

## Активна здібність героя — те, що висить на кнопці в бою.
##
## Кожна здібність це маленький окремий клас: свій опис, своя
## перезарядка, свій ефект. Щоб додати нову, досить написати такий клас
## і вписати його в Skills3D — бою й інтерфейсу міняти не треба.
##
## Здібності сильнішають від ОСОБИСТОГО таланту героя (HeroDef.
## unique_talent_id), який гравець качає за золото на базі: рівень
## таланту приходить сюди через talent_level().

## Заповнюються в наслідниках.
var id: StringName = &""
var title := "Здібність"
var description := ""
var color := Color(0.6, 0.85, 1.0)
## Яку фігуру малювати на кнопці: whirl, dash, nova, fire, smoke.
var icon_kind := "whirl"
var cooldown := 6.0

var _cooldown_left := 0.0

## Скільки лишилось до готовності (для кнопки).
func get_cooldown() -> Vector2:
	return Vector2(_cooldown_left, cooldown)

## Для здібностей, які заряджаються в бою (наприклад, Лють): 0..1.
## -1 означає "звичайна перезарядка, шкали заряду немає".
func get_charge(_player: Node) -> float:
	return -1.0

func is_ready(player: Node) -> bool:
	if _cooldown_left > 0.0:
		return false
	var charge := get_charge(player)
	return charge < 0.0 or charge >= 1.0

## Натиснули кнопку. Повертає true, якщо здібність спрацювала.
func try_use(player: Node) -> bool:
	if not is_ready(player) or not _use(player):
		return false
	_cooldown_left = cooldown
	return true

func tick(player: Node, delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_update(player, delta)

## Рівень особистого таланту героя — ним здібності й ростуть.
func talent_level(player: Node) -> int:
	var hero: HeroDef = player.hero_def
	if hero == null or hero.unique_talent_id == &"":
		return 0
	return GameState.get_meta_level(hero.id, hero.unique_talent_id)

# --- перевизначають наслідники ---

func _use(_player: Node) -> bool:
	return false

func _update(_player: Node, _delta: float) -> void:
	pass
