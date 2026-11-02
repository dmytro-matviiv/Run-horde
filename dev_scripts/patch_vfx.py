# -*- coding: utf-8 -*-
import os
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:70])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


# --- масштаб ефекту задається на місці виклику: вибух метеора має бути
# --- більшим за іскру від кинджала, хоча аркуш може бути той самий.
patch('scenes/run/vfx_player.gd', [
    ("""func play(def: VfxDef, at_position: Vector2, rotation_angle: float = 0.0) -> void:""",
     """func play(def: VfxDef, at_position: Vector2, rotation_angle: float = 0.0, scale_multiplier: float = 1.0) -> void:"""),
    ("""	sprite.scale = Vector2.ONE * (def.height / maxf(float(def.texture.get_height()) / float(sprite.vframes), 1.0))""",
     """	sprite.scale = Vector2.ONE * (def.height * scale_multiplier / maxf(float(def.texture.get_height()) / float(sprite.vframes), 1.0))"""),
])

patch('scenes/run/weapon_module.gd', [
    ("""func play_vfx(def: VfxDef, at_position: Vector2, rotation_angle: float = 0.0) -> void:
	if _vfx_pool == null or def == null or def.texture == null:
		return
	var vfx: Node = _vfx_pool.acquire()
	vfx.play(def, at_position, rotation_angle)""",
     """func play_vfx(def: VfxDef, at_position: Vector2, rotation_angle: float = 0.0, scale_multiplier: float = 1.0) -> void:
	if _vfx_pool == null or def == null or def.texture == null:
		return
	var vfx: Node = _vfx_pool.acquire()
	vfx.play(def, at_position, rotation_angle, scale_multiplier)"""),
    # снаряд сам не має пулів — він повідомляє модулю, куди влучив
    ("""		var projectile: Node = _projectile_pool.acquire()
		projectile.spawn(_hero.global_position, aim.rotated(angle_offset), _def, damage, pierce, ricochet, _on_projectile_explode)""",
     """		var projectile: Node = _projectile_pool.acquire()
		projectile.spawn(_hero.global_position, aim.rotated(angle_offset), _def, damage, pierce, ricochet, _on_projectile_explode, _on_projectile_hit)"""),
    ("""func _fire_cone(aim: Vector2, damage: float) -> void:
	if _flame_cone != null and is_instance_valid(_flame_cone):
		return""",
     """## Влучання звичайного снаряда: спалах у точці удару. Менший за
## вибух метеора, бо це просто попадання кулі.
func _on_projectile_hit(at_position: Vector2, direction: Vector2) -> void:
	play_vfx(_def.hit_vfx, at_position, direction.angle(), 0.5)

func _fire_cone(aim: Vector2, damage: float) -> void:
	if _flame_cone != null and is_instance_valid(_flame_cone):
		return"""),
    ("""	_flame_cone.ignite(aim, _def, damage)""",
     """	_flame_cone.ignite(aim, _def, damage)
	play_vfx(_def.swing_vfx, _hero.global_position + aim * _def.cone_range * 0.4, aim.angle())"""),
    ("""	var zone: Node = _zone_pool.acquire()
	zone.spawn(at_position, _def, damage)""",
     """	var zone: Node = _zone_pool.acquire()
	zone.spawn(at_position, _def, damage)
	play_vfx(_def.hit_vfx, at_position, 0.0, 1.2)"""),
])

patch('scenes/run/weapon_projectile.gd', [
    ("""var _aoe_radius := 0.0
var _on_explode: Callable   # виклик у WeaponModule: створити вибух з пулу""",
     """var _aoe_radius := 0.0
var _on_explode: Callable   # виклик у WeaponModule: створити вибух з пулу
var _on_hit: Callable       # виклик у WeaponModule: намальований спалах удару"""),
    ("""func spawn(from_position: Vector2, direction: Vector2, def: WeaponDef, damage: float, pierce: int, ricochet: int, on_explode: Callable) -> void:""",
     """func spawn(from_position: Vector2, direction: Vector2, def: WeaponDef, damage: float, pierce: int, ricochet: int, on_explode: Callable, on_hit: Callable = Callable()) -> void:"""),
    ("""	_on_explode = on_explode""",
     """	_on_explode = on_explode
	_on_hit = on_hit"""),
    ("""	CombatQuery.hit(body, _damage, _status, _status_power, _status_duration)""",
     """	CombatQuery.hit(body, _damage, _status, _status_power, _status_duration)
	if _on_hit.is_valid():
		_on_hit.call(global_position, _direction)"""),
])

# --- ефекти на самих зброях ---
WEAPON_VFX = {
    # зброя: (swing_vfx, hit_vfx)
    'battle_axe': (None, 'wind_slash'),          # замах сокири — подвійне розсічення
    'void_scythe': (None, 'poison_slash'),
    'flamethrower': ('fire_slash', None),
    'staff_meteor': (None, 'fire_slash'),
    'storm_scepter': (None, 'lightning_slash'),
    'shadow_chains': (None, 'poison_slash'),
    'frost_staff': (None, 'water_slash'),
    'pyre_totem': (None, 'fire_slash'),
    'rune_bolt': (None, 'lightning_slash'),
    'war_blade': (None, 'wind_slash'),
    'harpoon_glaive': (None, 'wind_slash'),
    'ember_bolt': (None, 'fire_slash'),
    'sun_lance': (None, 'fire_slash'),
    'shadow_dagger': (None, 'poison_slash'),
    'venom_daggers': (None, 'poison_slash'),
    'blade_storm': (None, 'wind_slash'),
}

# Сокира й коса б'ють у ближньому бою: там ефект саме на ЗАМАХУ.
WEAPON_VFX['battle_axe'] = ('wind_slash', None)
WEAPON_VFX['void_scythe'] = ('poison_slash', None)

for weapon, (swing, hit) in WEAPON_VFX.items():
    path = 'data/weapons/%s.tres' % weapon
    s = open(path, encoding='utf-8').read()
    if 'swing_vfx' in s or 'hit_vfx' in s:
        continue
    header, body = s.split('[resource]', 1)
    header = header.rstrip('\n')
    next_id = 2
    lines = []
    if swing:
        header += '\n[ext_resource type="Resource" path="res://data/vfx/%s.tres" id="%d"]' % (swing, next_id)
        lines.append('swing_vfx = ExtResource("%d")' % next_id)
        next_id += 1
    if hit:
        header += '\n[ext_resource type="Resource" path="res://data/vfx/%s.tres" id="%d"]' % (hit, next_id)
        lines.append('hit_vfx = ExtResource("%d")' % next_id)
        next_id += 1
    header += '\n\n'
    steps = next_id  # скільки ext_resource усього + сам ресурс
    header = header.replace('load_steps=2', 'load_steps=%d' % steps)
    body = body.rstrip('\n') + '\n' + '\n'.join(lines) + '\n'
    open(path, 'w', encoding='utf-8', newline='\n').write(header + '[resource]' + body)
    print('vfx ->', weapon, swing or '', hit or '')
