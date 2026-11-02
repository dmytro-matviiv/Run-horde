# -*- coding: utf-8 -*-
# Герой 3D: модель і зброя з вибраного персонажа, таланти, здібності.
import os
os.chdir(r'D:\Claude code\idle survivor_like')
path = 'scenes/world/player_3d.gd'
s = open(path, encoding='utf-8').read()


def rep(a, b):
    global s
    assert a in s, a[:90]
    s = s.replace(a, b, 1)


# --- шапка файлу ---
rep('''##  - ВИХІР: удар по колу з відкиданням, раз на кілька секунд.
##  - Відчуття удару: слід меча, іскри, цифри шкоди, коротке
##    "заморожування" кадру й тряска камери на сильних ударах.''',
    '''##  - ЗДІБНОСТІ: у кожного героя свої (Skills3D) — вихор вартової,
##    рунна нова, вогняне коло, димова завіса. Плюс пасивна риса класу,
##    яка працює сама (лють, заряд, фенікс, мітка).
##  - Відчуття удару: слід меча, іскри, цифри шкоди, коротке
##    "заморожування" кадру й тряска камери на сильних ударах.
##
## ГЕРОЙ, ЗБРОЯ, ТАЛАНТИ. Модель, зброя в руці, здібності й числа беруться
## з того, кого гравець обрав на базі: HeroDef (data/heroes), WeaponDef
## (data/weapons) і прокачані таланти з GameState. Немає моделі — герой
## ходить тимчасовою, пофарбованою в його колір; немає моделі зброї —
## вона збирається з простих фігур (WeaponModels). Гра грається вже
## зараз, а справжній арт під'єднається сам, щойно з'явиться.''')

# --- константи ---
rep('''## --- Вихор ---
const SKILL_RADIUS := 3.6
const SKILL_DAMAGE := 2.4
const SKILL_KNOCKBACK := 4.0
const SKILL_COOLDOWN := 6.0
const SKILL_TIME := 0.45
const SKILL_HIT_DELAY := 0.12

''', '''## Скільки дає один рівень спільних талантів (екран "Таланти").
const TALENT_HP_PER_LEVEL := 10.0
const TALENT_DAMAGE_PER_LEVEL := 0.05
const TALENT_SPEED_PER_LEVEL := 0.03

''')

# --- поля ---
rep('''## Острів вимикає бойове керування з клавіатури: там пробіл — це "зайти
## в будівлю".
var combat_input_enabled := true''',
    '''## Острів вимикає бойове керування з клавіатури: там пробіл — це "зайти
## в будівлю".
var combat_input_enabled := true

## Хто саме зараз у грі і з чим. Задається з GameState у _ready.
var hero_def: HeroDef
var weapon_def: WeaponDef
var passive: HeroPassive3D''')

rep('''var _skill_cooldown_left := 0.0
var _spin_left := 0.0
var _skill_hit_left := -1.0''',
    '''var _skills: Array[HeroSkill3D] = []
var _spin_left := 0.0
var _spin_total := 0.45

## Тимчасові підсилення: прискорення ударів після ривка люті та
## "невидимість" асасина.
var _attack_speed_buff := 1.0
var _attack_speed_left := 0.0
var _concealed_left := 0.0
var _concealed_damage := 1.0
var _concealed_speed := 0.0

var _weapon_holder: Node3D''')

# --- _ready ---
rep('''func _ready() -> void:
	_ensure_input_actions()
	_build_animation_tree()''',
    '''func _ready() -> void:
	_ensure_input_actions()
	_load_hero()
	_build_animation_tree()''')

rep('''	_health_bar.setup(ALLY_BAR_COLOR, BAR_HEIGHT, true)
	_add_torch_light()''',
    '''	_health_bar.setup(ALLY_BAR_COLOR, BAR_HEIGHT, true)
	_add_torch_light()

# --- хто в грі: герой, зброя, таланти ---

## Збирає героя: модель, зброю в руці, здібності й числа з талантів.
func _load_hero() -> void:
	hero_def = HeroPool.get_def(GameState.selected_hero_id)
	weapon_def = WeaponPool.get_def(GameState.get_equipped_weapon_id(hero_def.id))
	_build_model()
	_equip_weapon()
	_apply_loadout()

	passive = Skills3D.create_passive(hero_def.passive_id)
	_skills = Skills3D.create_for_hero(hero_def)

## Модель героя. Своєї ще немає — беремо тимчасову й фарбуємо в колір
## героя, щоб різні герої бодай відрізнялись на екрані.
func _build_model() -> void:
	for child in model.get_children():
		child.queue_free()
	var scene := ArtSlots.hero_model(hero_def.id, hero_def.model_scene)
	var placeholder := scene == null
	if placeholder:
		scene = ArtSlots.hero_model(&"blade_warden", HeroPool.get_def(&"blade_warden").model_scene)
	if scene == null:
		push_warning("Немає жодної моделі героя")
		return
	var instance: Node3D = scene.instantiate()
	model.add_child(instance)
	if placeholder:
		_tint_model(instance, hero_def.color)

## Фарбує тимчасову модель у колір героя: копіюємо матеріали (щоб не
## перефарбувати всіх одразу) і підмішуємо колір.
func _tint_model(instance: Node3D, tint: Color) -> void:
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material: StandardMaterial3D = source.duplicate()
			material.albedo_color = source.albedo_color.lerp(tint, 0.55)
			mesh_instance.set_surface_override_material(surface, material)

## Зброя кріпиться до кістки руки. Вбудований у модель меч ховаємо:
## інакше герой тримав би дві зброї одразу.
func _equip_weapon() -> void:
	var skeleton: Skeleton3D = _find_skeleton()
	if skeleton == null:
		return
	var builtin := model.find_child(String(hero_def.builtin_weapon_node), true, false)
	if builtin != null and builtin is Node3D:
		(builtin as Node3D).visible = weapon_def == null or weapon_def.style_3d != "sword"

	if weapon_def == null:
		return
	var bone := skeleton.find_bone(String(hero_def.weapon_bone))
	if bone < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_idx = bone
	skeleton.add_child(attachment)
	_weapon_holder = attachment

	var scene := ArtSlots.weapon_model(weapon_def.id, weapon_def.model_scene)
	var weapon_node: Node3D
	if scene != null:
		weapon_node = scene.instantiate()
	elif weapon_def.style_3d == "sword":
		return   # у моделі вже є меч — лишаємо його
	else:
		weapon_node = WeaponModels.build(weapon_def.style_3d, weapon_def.color)
	attachment.add_child(weapon_node)
	weapon_node.position = weapon_def.grip_offset
	weapon_node.rotation_degrees = weapon_def.grip_rotation_deg
	# Кістки моделі мають власний масштаб, тож зброю зводимо до метрів.
	var bone_scale: float = skeleton.global_transform.basis.get_scale().x
	weapon_node.scale = Vector3.ONE * weapon_def.model_scale / maxf(bone_scale, 0.0001)

func _find_skeleton() -> Skeleton3D:
	var found := model.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null

## Числа героя: база + бонуси героя + прокачані таланти + зброя.
func _apply_loadout() -> void:
	var levels := GameState.get_hero_meta_levels(hero_def.id)
	var hp_levels: int = levels.get(&"meta_max_hp", 0)
	var damage_levels: int = levels.get(&"meta_damage", 0)
	var speed_levels: int = levels.get(&"meta_move_speed", 0)

	max_hp = BASE_MAX_HP + hero_def.bonus_max_hp + TALENT_HP_PER_LEVEL * hp_levels
	current_hp = max_hp
	_damage = BASE_DAMAGE * (1.0 + TALENT_DAMAGE_PER_LEVEL * damage_levels)
	_speed_bonus = hero_def.move_speed_percent + TALENT_SPEED_PER_LEVEL * speed_levels
	if weapon_def != null:
		_damage *= weapon_def.damage_mult_3d
		_attack_speed = weapon_def.speed_mult_3d''')

# --- анімації: назви з героя + запасні варіанти ---
rep('''## Повна назва анімації в моделі ("CharacterArmature|Run").
func _anim(short_name: String) -> String:
	return "CharacterArmature|" + short_name

func _animation_node(short_name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = _anim(short_name)
	return node''',
    '''## Повна назва анімації в моделі. Стандарт — набори Quaternius
## ("CharacterArmature|Run"), але в HeroDef.animation_names можна задати
## свої назви для моделі з іншого набору.
func _anim(short_name: String) -> String:
	if hero_def != null and hero_def.animation_names.has(short_name):
		return hero_def.animation_names[short_name]
	return "CharacterArmature|" + short_name

## Якщо в моделі немає потрібної анімації (скажімо, бігу назад), беремо
## запасну — краще менш точний рух, ніж застигла поза.
func _animation_node(short_name: String, fallbacks: Array = []) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = _anim(short_name)
	var player: AnimationPlayer = animation_tree.get_node(animation_tree.anim_player)
	if player != null and not player.has_animation(node.animation):
		for name: String in fallbacks:
			if player.has_animation(_anim(name)):
				node.animation = _anim(name)
				break
	return node''')

rep('''	move.add_blend_point(_animation_node("Run_Back"), Vector2(0, -1), -1, &"back")
	move.add_blend_point(_animation_node("Run_Left"), Vector2(-1, 0), -1, &"left")
	move.add_blend_point(_animation_node("Run_Right"), Vector2(1, 0), -1, &"right")''',
    '''	move.add_blend_point(_animation_node("Run_Back", ["Walk", "Run"]), Vector2(0, -1), -1, &"back")
	move.add_blend_point(_animation_node("Run_Left", ["Walk", "Run"]), Vector2(-1, 0), -1, &"left")
	move.add_blend_point(_animation_node("Run_Right", ["Walk", "Run"]), Vector2(1, 0), -1, &"right")''')

rep('''	tree.add_node(&"KickAnim", _animation_node("Kick_Right"), Vector2(0, 600))''',
    '''	tree.add_node(&"KickAnim", _animation_node("Kick_Right", ["Punch_Right", "Sword_Slash"]), Vector2(0, 600))''')
rep('''	tree.add_node(&"RollAnim", _animation_node("Roll"), Vector2(0, 800))''',
    '''	tree.add_node(&"RollAnim", _animation_node("Roll", ["Run", "Walk"]), Vector2(0, 800))''')
rep('''	tree.add_node(&"HitAnim", _animation_node("HitRecieve"), Vector2(0, 1000))''',
    '''	tree.add_node(&"HitAnim", _animation_node("HitRecieve", ["HitReact", "Idle"]), Vector2(0, 1000))''')
rep('''	tree.add_node(&"DeathAnim", _animation_node("Death"), Vector2(0, 1200))''',
    '''	tree.add_node(&"DeathAnim", _animation_node("Death", ["HitRecieve", "Idle"]), Vector2(0, 1200))''')

rep('''	var roll_length := player.get_animation(_anim("Roll")).length''',
    '''	var roll_name := (tree.get_node(&"RollAnim") as AnimationNodeAnimation).animation
	var roll_length := player.get_animation(roll_name).length''')

rep('''	_upper_body_filter = _collect_upper_body_tracks(player.get_animation(_anim("Sword_Slash")))''',
    '''	var slash_name := _anim("Sword_Slash")
	if not player.has_animation(slash_name):
		slash_name = player.get_animation_list()[0]
	_upper_body_filter = _collect_upper_body_tracks(player.get_animation(slash_name))''')

# --- швидкість ударів з урахуванням тимчасових підсилень ---
rep('''func _apply_attack_speed() -> void:
	animation_tree.set("parameters/SlashScale/scale", 1.15 * _attack_speed)
	animation_tree.set("parameters/SlashFastScale/scale", 1.45 * _attack_speed)
	animation_tree.set("parameters/KickScale/scale", 1.1 * _attack_speed)''',
    '''func _apply_attack_speed() -> void:
	var speed := attack_speed()
	animation_tree.set("parameters/SlashScale/scale", 1.15 * speed)
	animation_tree.set("parameters/SlashFastScale/scale", 1.45 * speed)
	animation_tree.set("parameters/KickScale/scale", 1.1 * speed)

## Швидкість ударів разом із тимчасовим прискоренням (ривок люті).
func amp_attack_speed() -> float:
	return attack_speed()

func attack_speed() -> float:
	return _attack_speed * (_attack_speed_buff if _attack_speed_left > 0.0 else 1.0)''')

# --- здібності замість одного "вихору" ---
rep('''func use_skill() -> void:
	if _dead or _skill_cooldown_left > 0.0 or _roll_left > 0.0:
		return
	_skill_cooldown_left = SKILL_COOLDOWN
	_spin_left = SKILL_TIME
	_skill_hit_left = SKILL_HIT_DELAY
	_attack_step = -1
	_lunge_left = 0.0
	_combat_left = COMBAT_MEMORY
	_abort_attacks()
	_fire("SlashFastShot")
	var parent := get_parent()
	var chest := global_position + Vector3.UP * 1.0
	CombatVfx.slash(parent, chest, _facing_angle, SKILL_RADIUS, 359.0, SKILL_COLOR, false, 0.0, SKILL_TIME)
	CombatVfx.slash(parent, chest + Vector3.UP * 0.25, _facing_angle + PI, SKILL_RADIUS * 0.85, 359.0, SKILL_COLOR, true, 0.1, SKILL_TIME)
	CombatVfx.shockwave(parent, global_position, SKILL_RADIUS, SKILL_COLOR, 0.4)

## Частка кулдауну, що лишилась (0 — готово). Для кнопок на екрані.
func get_skill_cooldown() -> Vector2:
	return Vector2(_skill_cooldown_left, SKILL_COOLDOWN)

func get_dodge_cooldown() -> Vector2:
	return Vector2(_dodge_cooldown_left, DODGE_COOLDOWN)''',
    '''## Здібності героя — для кнопок на екрані.
func get_skills() -> Array[HeroSkill3D]:
	return _skills

## Натиснули кнопку здібності (0 — перша, 1 — друга).
func use_skill(index: int = 0) -> void:
	if _dead or _roll_left > 0.0 or index < 0 or index >= _skills.size():
		return
	var skill := _skills[index]
	if not skill.try_use(self):
		return
	_attack_step = -1
	_lunge_left = 0.0
	_combat_left = COMBAT_MEMORY
	_abort_attacks()
	_fire("SlashFastShot")

func get_dodge_cooldown() -> Vector2:
	return Vector2(_dodge_cooldown_left, DODGE_COOLDOWN)

# --- те, чим користуються здібності ---

## Оберт моделі навколо себе (вихор, каст нови).
func spin_model(time: float) -> void:
	_spin_left = time
	_spin_total = maxf(time, 0.01)

## Ривок у заданий бік — ним користується "Ривок Люті".
func dash(direction: Vector3, speed: float, time: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.01:
		flat = _facing_vector()
	_lunge_velocity = flat.normalized() * speed
	_lunge_left = time

func grant_invulnerable(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)

func add_attack_speed(multiplier: float, seconds: float) -> void:
	_attack_speed_buff = multiplier
	_attack_speed_left = seconds
	_apply_attack_speed()

func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)

## Зникнути з очей ворогів (димова завіса асасина).
func set_concealed(seconds: float, damage_bonus: float, speed_bonus: float) -> void:
	_concealed_left = seconds
	_concealed_damage = damage_bonus
	_concealed_speed = speed_bonus
	_set_model_transparency(0.55)

## Чи бачать героя вороги. Поки він у димовій завісі — ні.
func is_targetable() -> bool:
	return _concealed_left <= 0.0 and not _dead

func _set_model_transparency(value: float) -> void:
	for node in model.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).transparency = value

## Усі живі вороги в радіусі. require_sight — не бити крізь стіни.
func enemies_in_radius(radius: float, require_sight: bool = true) -> Array[Enemy3D]:
	var result: Array[Enemy3D] = []
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if not enemy.is_alive():
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() > radius + 0.5:
			continue
		if require_sight and not _can_see(enemy):
			continue
		result.append(enemy)
	return result

func facing_vector() -> Vector3:
	return _facing_vector()

func facing_angle() -> float:
	return _facing_angle''')

# --- клавіші другої здібності ---
rep('''		"skill": [KEY_E, KEY_L],''', '''		"skill": [KEY_E, KEY_L],
		"skill_2": [KEY_Q, KEY_U],''')
rep('''	elif event.is_action_pressed("skill"):
		use_skill()''',
    '''	elif event.is_action_pressed("skill"):
		use_skill(0)
	elif event.is_action_pressed("skill_2"):
		use_skill(1)''')

open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('player part 1 ok')
