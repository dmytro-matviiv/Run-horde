extends RefCounted
class_name Balance

## Усі числові константи балансу гри зібрані тут, щоб їх можна було
## міняти й тестувати в одному місці, а не шукати магічні числа по коду.
## Звертатись з будь-якого скрипта просто як Balance.HERO_MAX_HP —
## завдяки class_name цей клас доступний глобально без preload.

# Герой
const HERO_MAX_HP := 100.0
const HERO_MOVE_SPEED := 160.0      # пікселів за секунду
const HERO_PICKUP_RADIUS := 60.0
const HERO_IFRAMES := 0.5           # невразливість після удару, сек

# Базова зброя
const WEAPON_DAMAGE := 10.0
const WEAPON_COOLDOWN := 0.8        # сек між пострілами
const WEAPON_PROJECTILE_SPEED := 400.0
const WEAPON_PIERCE := 0            # скільки ворогів пробиває наскрізь

# Вороги (базовий тип)
const ENEMY_HP_BASE := 20.0
const ENEMY_HP_PER_MINUTE := 6.0    # HP = BASE + PER_MINUTE * хвилина_рану
const ENEMY_DAMAGE := 8.0
const ENEMY_SPEED := 70.0
const ENEMY_XP_DROP := 1
const ENEMY_GOLD_DROP := 1

# Спавн ворогів
const SPAWN_RATE_START := 1.5       # ворогів/сек на старті рану
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
