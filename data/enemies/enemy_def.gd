extends Resource
class_name EnemyDef

## Опис одного типу ворога — стати, вигляд і поведінка в одному місці.
## min_spawn_minute визначає, з якої хвилини рану цей тип може випасти
## в спавнера; spawn_weight — наскільки він частіший за інші доступні
## типи (звичайний рандомний вибір, не для босів — тих спавнер
## викликає напряму за часом).

@export var id: StringName
@export var title: String
@export var hp_base: float
@export var hp_per_minute: float
@export var damage: float
@export var speed: float
@export var xp_drop: int = 1
@export var gold_drop: int = 1
@export var radius: float = 14.0
@export var color: Color = Color(0.9, 0.2, 0.2)
@export_enum("melee", "ranged") var attack_type: String = "melee"
@export var explodes_on_death: bool = false
@export var min_spawn_minute: float = 0.0
@export var spawn_weight: float = 1.0
