extends CharacterBody2D

## Ворог: по прямій переслідує героя, при контакті завдає шкоди.
## Живе в ObjectPool — замість _ready() ініціалізацію робить spawn(),
## яку викликає спавнер щоразу, коли дістає інстанс із пулу.

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var current_hp: float
var move_speed: float
var contact_damage: float
var xp_drop: int
var gold_drop: int

var _hero: Node2D
var _pool: ObjectPool
var _crystal_pool: ObjectPool
var _on_death: Callable
var _active := false

func _ready() -> void:
	add_to_group("enemies")

func set_pool(pool: ObjectPool) -> void:
	_pool = pool

func set_crystal_pool(crystal_pool: ObjectPool) -> void:
	_crystal_pool = crystal_pool

## Масштабування HP за хвилиною рану винесене сюди, а не в спавнер,
## бо це властивість конкретного ворога, а не логіка спавну.
func spawn(spawn_position: Vector2, hero: Node2D, minute_of_run: float, on_death: Callable) -> void:
	global_position = spawn_position
	_hero = hero
	_on_death = on_death
	current_hp = Balance.ENEMY_HP_BASE + Balance.ENEMY_HP_PER_MINUTE * minute_of_run
	move_speed = Balance.ENEMY_SPEED
	contact_damage = Balance.ENEMY_DAMAGE
	xp_drop = Balance.ENEMY_XP_DROP
	gold_drop = Balance.ENEMY_GOLD_DROP

## disabled міняємо через set_deferred, бо це найчастіше викликається
## з _die()/_on_body_entered() — тобто просто посеред обробки фізичних
## колізій. Пряма зміна disabled у цей момент падає з помилкою
## "flushing queries" — set_deferred відкладає її до безпечного моменту.
func pool_activate() -> void:
	_active = true
	visible = true
	collision_shape.set_deferred("disabled", false)

func pool_deactivate() -> void:
	_active = false
	visible = false
	collision_shape.set_deferred("disabled", true)
	global_position = Vector2(-10000, -10000)

func _physics_process(_delta: float) -> void:
	if not _active or _hero == null:
		return
	velocity = global_position.direction_to(_hero.global_position) * move_speed
	move_and_slide()

func get_contact_damage() -> float:
	return contact_damage

func take_damage(amount: float) -> void:
	if not _active:
		return
	current_hp -= amount
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	if _on_death.is_valid():
		_on_death.call()
	if _crystal_pool != null:
		var crystal: Node = _crystal_pool.acquire()
		crystal.spawn(global_position, xp_drop, gold_drop)
	_pool.release(self)
