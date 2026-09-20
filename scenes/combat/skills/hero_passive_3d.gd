extends RefCounted
class_name HeroPassive3D

## Пасивна риса класу — те, що працює саме собою і робить героя собою.
## Саме вона має відповідати на питання "навіщо грати за цього героя".
##
## Гра сама кличе ці методи в потрібні миті бою, тож пасивка може
## накопичувати лють, вести лік ударів, рятувати від смерті чи мітити
## ворогів — не втручаючись у код бою.

var id: StringName = &""
var title := "Риса"
var description := ""
var color := Color(1.0, 0.8, 0.4)

## Заряд 0..1, якщо пасивка його накопичує (Лють). -1 — немає.
func get_charge() -> float:
	return -1.0

func consume_charge() -> void:
	pass

## Герой влучив по ворогові.
func on_hit(_player: Node, _enemy: Node, _amount: float, _heavy: bool) -> void:
	pass

## Підправити шкоду перед влучанням (мітка ворога тощо).
func modify_damage(_player: Node, _enemy: Node, amount: float) -> float:
	return amount

## Ворог загинув від руки героя.
func on_kill(_player: Node, _enemy: Node) -> void:
	pass

## Герой отримав шкоду.
func on_damage_taken(_player: Node, _amount: float) -> void:
	pass

## Смертельний удар. Поверни true — і герой виживе (Фенікс).
func on_lethal(_player: Node) -> bool:
	return false

func tick(_player: Node, _delta: float) -> void:
	pass

func talent_level(player: Node) -> int:
	var hero: HeroDef = player.hero_def
	if hero == null or hero.unique_talent_id == &"":
		return 0
	return GameState.get_meta_level(hero.id, hero.unique_talent_id)
