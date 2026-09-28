extends Resource
class_name WeaponDef

## Опис однієї зброї. Зброя — це НЕ просто інші числа шкоди: archetype
## визначає, як саме вона атакує (пряма стріляниця, вибух по площі,
## конус вогнемета, замах сокири, ланцюг блискавки, вихор клинків,
## палаюча земля). За кожен архетип відповідає окрема гілка в
## WeaponModule, тож нову зброю можна зробити, не чіпаючи код героя.
##
## Поля, яких архетип не використовує, просто ігноруються — так один
## ресурс описує будь-яку зброю без ієрархії класів під кожну.

@export var id: StringName
@export var title: String
@export_multiline var description: String

## Чий це асортимент (id героя). Стартова зброя героя — cost_gold = 0.
@export var hero_id: StringName
## Ціна в золоті. Числа тимчасові — баланс зведемо, коли буде більше
## рівнів і стабільний заробіток за похід.
@export var cost_gold: int = 0
## Лишилось від старої версії, де зброя купувалась за геми. Тепер уся
## зброя купується за золото; поле тримаємо, щоб не ламати збереження.
@export var cost_gems: int = 0

@export_enum("projectile", "aoe_projectile", "cone", "melee_arc", "chain", "orbit_storm", "ground_zone")
var archetype: String = "projectile"

@export_group("Загальне")
@export var damage: float = 10.0
@export var cooldown: float = 0.8
@export var color: Color = Color(1, 0.9, 0.2)

## Картинка зброї в руках героя. Поки її немає, зброя малюється
## простою фігурою за архетипом — але видно, що вона змінилась.
@export var icon: Texture2D

@export_group("Снаряди")
@export var projectile_speed: float = 400.0
@export var projectile_scale: float = 1.0
@export var pierce: int = 0
@export var shots: int = 1
@export var spread_deg: float = 12.0

@export_group("Площа")
@export var aoe_radius: float = 0.0          # вибух снаряда / нова
@export var cone_angle_deg: float = 60.0     # вогнемет
@export var cone_range: float = 190.0
@export var cone_duration: float = 0.6
@export var melee_arc_deg: float = 120.0     # замах сокири
@export var melee_range: float = 110.0
@export var zone_radius: float = 70.0        # палаюча земля
@export var zone_duration: float = 3.0

@export_group("Ланцюг і вихор")
@export var chain_targets: int = 3
@export var chain_range: float = 220.0
@export var orbit_count: int = 3
@export var orbit_radius: float = 70.0
@export var orbit_speed: float = 3.0

@export_group("Ефекти")
## Спалах у момент удару (розсічення сокири, вибух метеора). Беруться
## з куплених/безкоштовних наборів ефектів — VfxDef описує аркуш кадрів.
@export var swing_vfx: VfxDef
@export var hit_vfx: VfxDef

@export_group("3D: вогнепальна зброя")
## Зброя стріляє, а не б'є. Тоді герой не махає, а веде вогонь:
## затримка між пострілами, магазин і перезарядка.
@export var ranged_3d := false
@export var fire_interval := 0.35        # секунд між пострілами
@export var magazine := 12               # набоїв у магазині
@export var reload_time := 1.5
@export var bullet_speed := 45.0
@export var bullet_spread_deg := 2.0
@export var bullets_per_shot := 1
## Звідки вилітає куля відносно моделі зброї (кінчик ствола).
@export var muzzle_offset := Vector3(0, 0, 0.5)

@export_group("3D: зброя в руці")
## Модель зброї (.glb). Порожньо — гра шукає
## res://assets/models/weapons/<id>.glb, а якщо немає й там, збирає
## тимчасову зі простих фігур за стилем (WeaponModels).
@export var model_scene: PackedScene

## Стиль бою в 3D: від нього залежать і тимчасова модель, і те, як
## герой б'є (широкий замах сокири, довгий випад глефи, швидка серія
## парних клинків).
@export_enum("sword", "axe", "glaive", "twin_blades", "staff", "daggers", "pistol", "rifle")
var style_3d: String = "sword"

## Чим зброя відрізняється в бою. Множники до базового удару героя.
@export var damage_mult_3d: float = 1.0
@export var speed_mult_3d: float = 1.0
@export var knockback_mult_3d: float = 1.0
## Дальність замаху в метрах і його ширина в градусах.
@export var reach_3d: float = 2.9
@export var arc_3d: float = 150.0

## Як зброя лежить у руці (підганяється під конкретну модель).
@export var grip_offset := Vector3.ZERO
@export var grip_rotation_deg := Vector3.ZERO
@export var model_scale: float = 1.0
## Парна зброя: друга така сама модель у лівій руці, дзеркально до
## правої (парні клинки, кинджали).
@export var dual_wield := false

@export_group("Статус-ефект")
## Порожній StringName = без ефекту. Решта — StatusEffects.POISON/BURN/SLOW.
@export var status: StringName
@export var status_power: float = 0.0        # отрута/горіння — шкода/сек; сповільнення — частка (0.4 = -40%)
@export var status_duration: float = 0.0
