extends Node2D

## Удар ближнього бою (сокира, коса): б'є всіх у секторі перед героєм
## один раз і одразу зникає. Нічого не малює — видиму частину бере на
## себе намальований ефект розсічення зі зброї (WeaponDef.swing_vfx).
##
## Раніше тут малювався помаранчевий сектор-заготовка; тепер, коли є
## справжня анімація удару, він лише заважав.

## damage вже з бонусами героя; aim — напрямок удару.
## Повертає, скількох ворогів зачепило.
func strike(at_position: Vector2, aim: Vector2, def: WeaponDef, damage: float) -> int:
	global_position = at_position
	var enemies := CombatQuery.enemies_in_cone(get_world_2d(), at_position, def.melee_range, aim, def.melee_arc_deg)
	var hits := CombatQuery.hit_all(enemies, damage, def.status, def.status_power, def.status_duration)
	queue_free()
	return hits
