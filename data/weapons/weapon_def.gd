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

## Чий це асортимент (id героя). Стартова зброя героя — cost_gems = 0.
@export var hero_id: StringName
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

@export_group("Статус-ефект")
## Порожній StringName = без ефекту. Решта — StatusEffects.POISON/BURN/SLOW.
@export var status: StringName
@export var status_power: float = 0.0        # отрута/горіння — шкода/сек; сповільнення — частка (0.4 = -40%)
@export var status_duration: float = 0.0
