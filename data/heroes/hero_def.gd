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

## Спрайт героя. Поки картинки немає, малюється кольорова фігура —
## так гра лишається робочою, доки арт готовий не для всіх.
@export var texture: Texture2D

## Вигляд зі спини — показується, коли герой іде вгору (від гравця).
## Якщо не заданий, лишається звичайний вигляд.
@export var texture_back: Texture2D
## Ціна в золоті (0 = стартовий герой). Преміум-герой купується не
## за золото, а за геми — тоді unlock_cost = 0, а gem_cost > 0.
@export var unlock_cost: int = 0
@export var gem_cost: int = 0
@export var bonus_max_hp: float = 0.0
@export var move_speed_percent: float = 0.0
@export_enum("none", "orbital_blades", "damage_aura") var bonus_weapon: String = "none"


@export_group("3D: модель і бій")
## Модель героя (.glb). Порожньо — гра шукає файл за назвою героя:
## res://assets/models/heroes/<id>.glb. Немає й там — герой ходить
## тимчасовою моделлю, пофарбованою в його колір (гра працює, арт
## можна додати будь-коли).
@export var model_scene: PackedScene

## Кістка правої руки, до якої кріпиться зброя, і вбудована в модель
## зброя, яку треба сховати, коли герой бере іншу.
@export var weapon_bone: StringName = &"Wrist.R"
@export var builtin_weapon_node: StringName = &"Sword"

## Якщо в новій моделі анімації звуться інакше — тут перелік
## "наша назва" -> "назва в моделі". Порожньо = стандартні назви
## Quaternius (CharacterArmature|Idle, |Run, |Sword_Slash ...).
@export var animation_names: Dictionary = {}

## Активні здібності для кнопок у бою (Skills3D) і пасивна риса класу.
@export var skill_ids: Array[StringName] = []
@export var passive_id: StringName

@export_group("Спрайт-лист (куплений набір)")
## Якщо тут лежить аркуш кадрів — персонаж анімується ПОКАДРОВО, як у
## справжніх іграх, а не лише процедурним похитуванням. Порожньо —
## лишається одна картинка й процедурна анімація.
@export var sheet: Texture2D
@export var sheet_fps: float = 12.0

## Класове вміння (AbilityPool.ABILITIES) — головна причина грати
## саме за цього героя: рунна нова, ривок люті, фенікс, тіні асасина.
@export var ability_id: StringName

## Унікальний мета-талант цього героя (id з meta_upgrades.gd::TALENTS).
## На відміну від 7 спільних статів — прокачується окремо для кожного
## героя і бачить його лише власник.
@export var unique_talent_id: StringName
