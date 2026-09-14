extends Resource
class_name HeroDef

## Опис одного героя: вигляд, ціна розблокування (0 = стартовий,
## безкоштовний) і стартовий бонус поверх базового магічного болта
## (який є в усіх героїв однаково) — це і робить кожного героя іншим
## за стилем гри, не дублюючи бойову систему.

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var color: Color = Color(0.2, 0.8, 1)
@export var unlock_cost: int = 0
@export var bonus_max_hp: float = 0.0
@export var move_speed_percent: float = 0.0
@export_enum("none", "orbital_blades", "damage_aura") var bonus_weapon: String = "none"

## Унікальний мета-талант цього героя (id з meta_upgrades.gd::TALENTS).
## На відміну від 7 спільних статів — прокачується окремо для кожного
## героя і бачить його лише власник.
@export var unique_talent_id: StringName
