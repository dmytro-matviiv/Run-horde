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


# --- описи: картинка спини для героя й ворога, іконка зброї ---
# --- герой: анімація ходи, замаху, удару + плавний розгін ---
patch('scenes/run/hero.gd', [
    ("""const WEAPON_MODULE_SCRIPT := preload("res://scenes/run/weapon_module.gd")""",
     """const WEAPON_MODULE_SCRIPT := preload("res://scenes/run/weapon_module.gd")
const WEAPON_VISUAL_SCENE := preload("res://scenes/run/weapon_visual.tscn")

## Розгін і гальмування: без них герой "телепортується" в напрямку
## руху й виглядає так, наче ковзає по підлозі, а не йде.
const ACCELERATION := 1400.0"""),
    ("""var _weapon: WeaponModule
var _ability: HeroAbility""",
     """var _weapon: WeaponModule
var _ability: HeroAbility
var _animator: SpriteAnimator
var _weapon_visual: Node2D"""),
    ("""func _ready() -> void:
	pickup_area.area_entered.connect(_on_pickup_area_entered)""",
     """func _ready() -> void:
	pickup_area.area_entered.connect(_on_pickup_area_entered)
	_animator = SpriteAnimator.new()
	add_child(_animator)
	_weapon_visual = WEAPON_VISUAL_SCENE.instantiate()
	add_child(_weapon_visual)"""),
    ("""func equip_weapon(def: WeaponDef) -> void:
	if _weapon == null or def == null:
		return
	_weapon.equip(def)""",
     """func equip_weapon(def: WeaponDef) -> void:
	if _weapon == null or def == null:
		return
	_weapon.equip(def)
	# Зброю видно в руках: інша зброя — інший вигляд і інший замах.
	_weapon_visual.show_weapon(def)"""),
    ("""func _apply_art(texture: Texture2D) -> void:
	if texture == null:
		return
	art.texture = texture
	art.scale = Vector2.ONE * (ART_HEIGHT / float(texture.get_height()))
	art.visible = true
	sprite.visible = false""",
     """func _apply_art(def: HeroDef) -> void:
	if def.texture == null:
		return
	art.texture = def.texture
	art.scale = Vector2.ONE * (ART_HEIGHT / float(def.texture.get_height()))
	art.visible = true
	sprite.visible = false
	_animator.setup(art, def.texture, def.texture_back)"""),
    ("""	sprite.color = def.color
	_apply_art(def.texture)""",
     """	sprite.color = def.color
	_apply_art(def)"""),
    ("""func _physics_process(delta: float) -> void:
	velocity = _get_move_direction() * Balance.HERO_MOVE_SPEED * _move_speed_multiplier
	move_and_slide()""",
     """func _physics_process(delta: float) -> void:
	var direction := _get_move_direction()
	var target_velocity := direction * Balance.HERO_MOVE_SPEED * _move_speed_multiplier
	velocity = velocity.move_toward(target_velocity, ACCELERATION * delta)
	move_and_slide()
	_animator.set_move_direction(direction)"""),
    ("""func _on_weapon_attacked(target: Node2D) -> void:
	if _ability != null:
		_ability.on_attack(target)""",
     """func _on_weapon_attacked(target: Node2D) -> void:
	if target != null:
		var aim := global_position.direction_to(target.global_position)
		_animator.play_attack(aim)
		_weapon_visual.swing(aim)
	if _ability != null:
		_ability.on_attack(target)"""),
    ("""	if _ability != null:
		_ability.on_hero_damaged(actual_damage)""",
     """	_animator.play_hit_flash()
	if _ability != null:
		_ability.on_hero_damaged(actual_damage)"""),
])

# --- ворог: хода, замах перед ударом, здригання, смерть ---
patch('scenes/run/enemy.gd', [
    ("""var _statuses: Dictionary = {}
var _dot_tick_left := 0.0""",
     """var _statuses: Dictionary = {}
var _dot_tick_left := 0.0

## Анімація: хода, замах, здригання від удару й згасання при смерті.
## Ворог не зникає миттєво — спершу дограє смерть, аж потім
## повертається в пул.
var _animator: SpriteAnimator
var _dying := false
var _melee_swing_left := 0.0"""),
    ("""func _ready() -> void:
	add_to_group("enemies")""",
     """const MELEE_SWING_INTERVAL := 0.9   # як часто ворог замахується впритул
const MELEE_SWING_RANGE := 46.0

func _ready() -> void:
	add_to_group("enemies")
	_animator = SpriteAnimator.new()
	add_child(_animator)"""),
    ("""	_statuses.clear()
	_dot_tick_left = 0.0
	modulate = Color.WHITE""",
     """	_statuses.clear()
	_dot_tick_left = 0.0
	_dying = false
	_melee_swing_left = 0.0
	modulate = Color.WHITE"""),
    ("""	art.texture = def.texture
	art.scale = Vector2.ONE * (def.radius * ART_SIZE_FACTOR / float(def.texture.get_height()))
	art.visible = true
	sprite.visible = false""",
     """	art.texture = def.texture
	art.scale = Vector2.ONE * (def.radius * ART_SIZE_FACTOR / float(def.texture.get_height()))
	art.visible = true
	sprite.visible = false
	_animator.setup(art, def.texture, def.texture_back)
	_animator.reset()"""),
    ("""func _physics_process(delta: float) -> void:
	if not _active or _hero == null:
		return
	_process_statuses(delta)""",
     """func _physics_process(delta: float) -> void:
	if _dying:
		# Дограємо смерть і лише тоді віддаємо вузол у пул.
		if _animator.is_death_finished():
			_dying = false
			_pool.release(self)
		return
	if not _active or _hero == null:
		return
	_process_statuses(delta)"""),
    ("""func _process_melee() -> void:
	velocity = global_position.direction_to(_get_chase_position()) * get_move_speed()
	move_and_slide()""",
     """func _process_melee() -> void:
	var direction := global_position.direction_to(_get_chase_position())
	velocity = direction * get_move_speed()
	move_and_slide()
	_animator.set_move_direction(direction)
	_process_melee_swing(direction)

## Замах перед ударом: гравець бачить, що ворог його зараз дістане,
## а не просто "втикається" в героя.
func _process_melee_swing(direction: Vector2) -> void:
	_melee_swing_left -= get_physics_process_delta_time()
	if _melee_swing_left > 0.0:
		return
	if global_position.distance_to(_hero.global_position) > MELEE_SWING_RANGE:
		return
	_melee_swing_left = MELEE_SWING_INTERVAL
	_animator.play_attack(direction)"""),
    ("""	_ranged_cooldown_left -= delta
	if _ranged_cooldown_left <= 0.0 and distance <= RANGED_ATTACK_RANGE * 1.3:
		_fire_at_hero()""",
     """	_animator.set_move_direction(velocity.normalized() if velocity.length() > 1.0 else Vector2.ZERO)
	_ranged_cooldown_left -= delta
	if _ranged_cooldown_left <= 0.0 and distance <= RANGED_ATTACK_RANGE * 1.3:
		_animator.play_attack(global_position.direction_to(_hero.global_position))
		_fire_at_hero()"""),
    ("""	if play_sound:
		AudioManager.play(&"hit")""",
     """	if play_sound:
		AudioManager.play(&"hit")
	_animator.play_hit_flash()"""),
    ("""func _update_status_tint() -> void:
	modulate = StatusEffects.get_tint(_statuses.keys())""",
     """func _update_status_tint() -> void:
	# Колір статусу тримає аніматор: інакше здригання від удару
	# затирало б підсвітку отрути чи горіння.
	_animator.set_base_tint(StatusEffects.get_tint(_statuses.keys()))"""),
    ("""func _die() -> void:
	AudioManager.play(&"enemy_death")
	if _on_death.is_valid():
		_on_death.call(global_position)""",
     """func _die() -> void:
	AudioManager.play(&"enemy_death")
	# Вбивство зараховуємо одразу, а зникає ворог після анімації —
	# інакше лічильник і нагороди чекали б на картинку.
	_dying = true
	_active = false
	collision_shape.set_deferred("disabled", true)
	_animator.play_death()
	if _on_death.is_valid():
		_on_death.call(global_position)"""),
    ("""	if _crystal_pool != null:
		var crystal: Node = _crystal_pool.acquire()
		crystal.spawn(global_position, xp_drop, gold_drop)
	_pool.release(self)""",
     """	if _crystal_pool != null:
		var crystal: Node = _crystal_pool.acquire()
		crystal.spawn(global_position, xp_drop, gold_drop)"""),
])
print('all patched')
