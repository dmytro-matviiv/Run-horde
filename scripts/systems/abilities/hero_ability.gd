extends Node
class_name HeroAbility

## Базовий клас класової механіки героя — того, що робить героя
## впізнаваним, а не просто "інші цифри". Уміння живе весь ран як
## вузол-дитина героя й отримує від нього події бою: атака, вбивство,
## отримана шкода, смертельний удар.
##
## Кожен нащадок перевизначає лише потрібні йому методи. Герой не знає
## про конкретні вміння — лише про цей інтерфейс (HeroPool → HeroDef
## .ability_id → AbilityPool.create).

var hero: Node2D
var weapon: WeaponModule

func setup(hero_node: Node2D, weapon_module: WeaponModule) -> void:
	hero = hero_node
	weapon = weapon_module
	_on_setup()

## Виклик після setup() — нащадок готує свій стан.
func _on_setup() -> void:
	pass

## Герой атакував ціль (сигнал WeaponModule.attacked).
func on_attack(_target: Node2D) -> void:
	pass

func on_damage_dealt(_amount: float) -> void:
	pass

func on_enemy_killed(_at_position: Vector2) -> void:
	pass

func on_hero_damaged(_amount: float) -> void:
	pass

## Останній шанс скасувати смерть (Фенікс жриці). true — герой вижив,
## уміння само відновило йому HP.
func try_prevent_death() -> bool:
	return false

## 0..1 для смужки в HUD.
func get_charge_ratio() -> float:
	return 0.0

## Короткий рядок у HUD: назва вміння і його стан.
func get_status_text() -> String:
	return ""
