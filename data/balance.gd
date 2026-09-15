extends RefCounted
class_name Balance

## Усі числові константи балансу гри зібрані тут, щоб їх можна було
## міняти й тестувати в одному місці, а не шукати магічні числа по коду.
## Звертатись з будь-якого скрипта просто як Balance.HERO_MAX_HP —
## завдяки class_name цей клас доступний глобально без preload.

# Герой
const HERO_MAX_HP := 100.0
const HERO_MOVE_SPEED := 170.0      # пікселів за секунду (170: трохи легше тікати від рою)
const HERO_PICKUP_RADIUS := 60.0
const HERO_IFRAMES := 0.6           # невразливість після удару, сек

# Базова зброя
const WEAPON_DAMAGE := 10.0
const WEAPON_COOLDOWN := 0.8        # сек між пострілами
const WEAPON_PROJECTILE_SPEED := 400.0
const WEAPON_PIERCE := 0            # скільки ворогів пробиває наскрізь

# Вороги — конкретні стати кожного типу тепер в data/enemies/*.tres
# (EnemyDef), тут лишається тільки спільне для всіх снарядів ворогів.
const ENEMY_PROJECTILE_SPEED := 250.0

# Спавн ворогів
const SPAWN_RATE_START := 1.0       # ворогів/сек на старті рану (було 1.5 — заскладно на старті)
const SPAWN_RATE_END := 8.0         # ворогів/сек на 5:00
const RUN_DURATION := 300.0         # секунд (5 хвилин)
const SPAWN_RADIUS_FACTOR := 1.2    # множник від половини діагоналі екрана

## Скільки XP треба, щоб перейти з рівня level на level+1.
static func xp_to_next(level: int) -> int:
	return 5 + 4 * (level - 1) + (level / 5) * 10

## Вартість мета-апгрейду на певному рівні (у золоті).
static func meta_upgrade_cost(level: int) -> int:
	return int(round(50 * pow(1.35, level)))

# Ідл-шар
const IDLE_GOLD_PER_HOUR_BASE := 60.0
const IDLE_GOLD_PER_LEVEL_PERCENT := 0.15   # приріст gold/год за кожен сумарний рівень мета-апгрейдів
const IDLE_MAX_HOURS := 8.0                 # ліміт накопичення офлайн-золота

## Скільки золота гривень капає за годину офлайну при сумі рівнів
## усіх мета-апгрейдів total_meta_levels.
static func idle_gold_per_hour(total_meta_levels: int) -> float:
	return IDLE_GOLD_PER_HOUR_BASE * (1.0 + IDLE_GOLD_PER_LEVEL_PERCENT * total_meta_levels)

# Скринька на головному екрані
const CHEST_COOLDOWN_HOURS := 4.0
const CHEST_GOLD_MIN := 20
const CHEST_GOLD_MAX := 80

# Реклама (розділ 8 ТЗ)
const INTERSTITIAL_EVERY_N_RUNS := 3
const INTERSTITIAL_GRACE_RUNS := 3        # у перші N ранів нового гравця — ніколи
const INTERSTITIAL_MIN_INTERVAL_SEC := 90
const REVIVE_HP_FRACTION := 0.5           # воскресіння за рекламу — з такою часткою HP
const REVIVE_IFRAMES := 2.0               # довша невразливість, щоб одразу не вбили знову
