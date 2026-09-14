extends Resource
class_name UpgradeDef

## Опис одного апгрейду рану: що показати гравцю на екрані вибору.
## Саму логіку ефекту (що саме міняється в геймплеї) реалізує
## Hero.apply_upgrade() за id — тут лише дані для відображення й відбору.

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export_enum("weapon", "defense", "utility", "new_weapon") var category: String = "utility"
@export var max_level: int = 5
