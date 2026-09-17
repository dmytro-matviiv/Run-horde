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

## Висота спрайта на екрані в пікселях. Задаємо явно, а не множником від
## radius: коло зіткнень і візуальний розмір — різні речі (дракон має
## бути велетнем, але не мусить мати велетенське коло), і так розмір
## кожного ворога видно й легко підкрутити.
@export var art_height: float = 60.0
@export var color: Color = Color(0.9, 0.2, 0.2)

## Спрайт ворога; якщо не заданий — малюється кольорова фігура.
@export var texture: Texture2D
@export var texture_back: Texture2D

@export_group("Спрайт-лист (куплений набір)")
## Якщо тут лежить аркуш кадрів — персонаж анімується ПОКАДРОВО, як у
## справжніх іграх, а не лише процедурним похитуванням. Порожньо —
## лишається одна картинка й процедурна анімація.
@export var sheet: Texture2D
@export var sheet_fps: float = 12.0


@export_enum("melee", "ranged") var attack_type: String = "melee"
@export var explodes_on_death: bool = false
@export var min_spawn_minute: float = 0.0
@export var spawn_weight: float = 1.0
