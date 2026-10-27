extends RefCounted
class_name EnemyAbility

## ЗДІБНІСТЬ ВОРОГА — окремий прийом, який можна дати будь-якому ворогові
## в описі рівня: "abilities": ["blink", {"id": "lob", "cooldown": 5}].
## Так нові вороги й боси збираються з готових прийомів, а Enemy3D не
## розростається на кожного нового монстра.
##
## Щокроку ворог (коли не спить) викликає tick(); поки він бачить героя й
## вільний, питає try_use() — здібність або береться до діла (і тоді сама
## веде ворога: замах, телепорт, стрибок), або ні, і ворог б'ється як
## звичайно. Замах із назвою здібності (Enemy3D.begin_special) по
## завершенні викликає resolve().
##
## Налаштування з опису: cooldown — перезарядка, first — через скільки
## секунд перший раз, phase — з якої фази боса діє.

var id := ""
var enemy: Enemy3D
var cooldown := 6.0
var from_phase := 1
## Реакція, що не чекає перерви між ударами (удар хвостом, щойно герой
## зайшов за спину).
var instant := false
## До якої фази боса включно діє ("until" в описі).
var until_phase := 99
## Каст, який не збиває навіть суперздібність ("uninterruptible" в описі).
## Без ключа — прийом переходу фази боса: діє з фази 2+ і спрацьовує
## одразу з її початком ("first" до 1 с).
var uninterruptible := false
var config: Dictionary = {}

var _left := 2.0

func setup(owner: Enemy3D, settings: Dictionary) -> void:
	enemy = owner
	config = settings
	cooldown = float(settings.get("cooldown", cooldown))
	from_phase = int(settings.get("phase", 1))
	until_phase = int(settings.get("until", 99))
	_left = float(settings.get("first", cooldown * 0.5))
	uninterruptible = bool(settings.get("uninterruptible",
		from_phase > 1 and float(settings.get("first", 99.0)) <= 1.0))

## Перезарядка минула й фаза боса дозволяє.
func ready_to_use() -> bool:
	return _left <= 0.0 and (enemy.phases == null
		or (enemy.phases.phase >= from_phase and enemy.phases.phase <= until_phase))

func start_cooldown() -> void:
	_left = cooldown

## Кожен крок фізики, поки ворог не спить і живий.
func tick(delta: float) -> void:
	_left -= delta

## Спробувати застосувати; true — здібність узяла хід.
func try_use(_distance: float) -> bool:
	return false

## Замах із цією здібністю (Enemy3D.begin_special) завершився.
func resolve() -> void:
	pass

func on_death() -> void:
	pass

## Ворога вдарили (і він ще живий).
func on_damaged() -> void:
	pass

## Удар мав би вбити ворога. true — здібність не дала впасти (сама
## подбала про здоров'я й про те, що далі).
func on_lethal() -> bool:
	return false

## Звичайний удар ворога щойно впав (влучив чи ні).
func on_strike() -> void:
	pass

## Здібність зараз сама веде ворога (під землею, у стрибку, у тумані) —
## звичайний рух і удари чекають.
func is_busy() -> bool:
	return false

## Шкода здібності — частка шкоди самого ворога ("damage" в описі).
func damage() -> float:
	return enemy.damage * float(config.get("damage", 1.0))

func player() -> Node3D:
	return enemy.get_player()

func world() -> Node:
	return enemy.get_parent()
