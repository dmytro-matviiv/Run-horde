extends CharacterBody3D

## Герой у 3D-світі: рух, камеро-відносне керування й бій.
##
## РУХ. Персонаж ходить у будь-якому напрямку (360°) і плавно
## довертається; анімації переливаються одна в одну через AnimationTree.
##
## БІЙ — так, щоб на телефоні не треба було цілитись:
##  - АВТОНАВЕДЕННЯ. Герой сам обирає найближчого ворога попереду (під
##    ним червоне кільце). Удар іде в нього, навіть якщо гравець стоїть
##    трохи боком, а якщо ворог за крок-два — герой підскакує до нього.
##  - БІЙ НА ВІДХОДІ. Поки ворог близько й іде бій, герой тримається до
##    нього обличчям: відступаєш — він позадкує й далі б'є (біг назад і
##    вбік мають власні анімації). Відбіг далі — розвертається й біжить.
##  - КОМБО з трьох ударів (для ближнього бою): два помахи мечем у різні
##    боки й удар ногою, що відкидає ворога. Натискання під час удару
##    запам'ятовується, а утримання кнопки б'є серією, поки є ціль.
##  - СТРІЛЬБА (для вогнепальної зброї): свій темп вогню, магазин і
##    перезарядка. Утримуєш кнопку — герой веде вогонь, поки є набої;
##    скінчились — сам перезаряджається. Кулі летять видимо й
##    розбиваються об стіни.
##  - ПЕРЕКАТ: ривок з короткою невразливістю — щоб вийти з-під удару,
##    який ворог показав червоною зоною на підлозі.
##  - ЗДІБНОСТІ: у кожного героя свої (Skills3D) — вихор вартової,
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
## зараз, а справжній арт під'єднається сам, щойно з'явиться.

signal died
signal health_changed(current: float, maximum: float)
## Удар героя влучив (для лічильника серії в данжі).
signal hit_landed(amount: float, crit: bool)
## Ворожий удар прилетів у перші миті перекату — ухилився в останню мить.
signal perfect_dodge
## Почалась ланка комбо (index від 0) — для позначок серії на екрані.
signal combo_step(index: int, total: int)

const WALK_SPEED := 2.6
const RUN_SPEED := 4.6
const ACCELERATION := 14.0      # як швидко набирає швидкість
const DECELERATION := 18.0      # як швидко спиняється
## Найсильніше тягнення вирів разом — 60% бігу: тікаючи, герой вибирається.
const MAX_PULL_SPEED := 3.2
const ROTATION_SPEED := 12.0    # як швидко довертається в бік руху
const COMBAT_TURN_SPEED := 22.0 # як швидко довертається до цілі в бою
const GRAVITY := 22.0

const BASE_DAMAGE := 14.0
const BASE_MAX_HP := 100.0

## --- Автонаведення ---
## Ціль береться в цьому радіусі й тримається, поки не відбіжить далі
## за LOCK_BREAK_RANGE (різні радіуси — щоб ціль не "блимала" на межі).
const LOCK_RANGE := 7.0
const LOCK_BREAK_RANGE := 9.0
const RETARGET_INTERVAL := 0.2
## Ближче за це й під час бою герой стоїть до ворога обличчям і відходить
## задки. Далі — розвертається й біжить.
const ENGAGE_RANGE := 4.5
## Скільки секунд після останнього удару (свого чи по собі) герой
## вважається "у бою".
const COMBAT_MEMORY := 2.5
## Швидкість задки й убік відносно звичайного бігу.
const BACKPEDAL_FACTOR := 0.72
## Скільки секунд після останнього удару герой ще відступає обличчям до
## ворога. Перестав бити й тікаєш — розвертається й біжить, навіть якщо
## ворог женеться слідом.
const RETREAT_GUARD_TIME := 0.8

## --- Удари ---
## Крок до цілі, якщо та трохи далі за замах. Раніше це був ривок до
## 3.5 м за десяту частку секунди — герой "пролітав" до ворога. Тепер це
## спокійний крок, не далі за метр і не швидше за звичайний біг.
const LUNGE_REACH_EXTRA := 1.2
const LUNGE_MAX_DISTANCE := 0.9
const LUNGE_SPEED := 5.0
## Під час удару герой рухається повільніше — удар має вагу.
const ATTACK_MOVE_FACTOR := 0.35
## Скільки часу після удару можна продовжити комбо.
const COMBO_WINDOW := 0.7
const CRIT_CHANCE := 0.12
const CRIT_MULTIPLIER := 1.8

const SLASH_COLOR := Color(0.72, 0.87, 1.0)
const HEAVY_COLOR := Color(1.0, 0.72, 0.3)
const SKILL_COLOR := Color(0.35, 0.95, 1.0)

## Ланки комбо — свої для кожного стилю зброї: сокира б'є не так, як
## кинджали. Кожна ланка:
##   shot — слот анімації (їх три, див. SLOTS), anim / anim_speed — яка
##     анімація в ньому грає і як швидко;
##   damage — множник шкоди, reach — дальність, arc — ширина замаху;
##   hit_time — коли удар доходить, recover — коли закінчився;
##   pause — перепочинок ПІСЛЯ удару: без нього утримання кнопки било
##     без упину "удар-удар-удар";
##   knockback — відкидання, heavy — сильний удар (збиває замах ворога).
## Форма удару shape: "arc" — дуга попереду (звичайна), "circle" —
## довкола себе, "line" — вузький довгий укол крізь ряд ворогів (width —
## його ширина). Особливе: spin — герой обертається (сокира), hits — ще
## влучання в тій самій ланці (парні клинки), burst — вибух довкола цілі
## [радіус, частка шкоди] (кинджали), stun — оглушення в секундах (тесак).
const STYLE_COMBOS := {
	# Меч: два замахи в різні боки й удар ногою, що відкидає.
	"sword": [
		{"shot": "SlashShot", "anim": "Sword_Slash", "anim_speed": 1.15, "damage": 1.0, "reach": 2.9,
			"arc": 150.0, "hit_time": 0.17, "recover": 0.36, "pause": 0.14, "knockback": 0.6,
			"reverse": false, "tilt": 0.14, "heavy": false},
		{"shot": "SlashFastShot", "anim": "Sword_Slash", "anim_speed": 1.45, "damage": 1.15, "reach": 2.9,
			"arc": 150.0, "hit_time": 0.13, "recover": 0.32, "pause": 0.14, "knockback": 0.6,
			"reverse": true, "tilt": -0.2, "heavy": false},
		{"shot": "KickShot", "anim": "Kick_Right", "anim_speed": 1.1, "damage": 1.9, "reach": 2.6,
			"arc": 110.0, "hit_time": 0.22, "recover": 0.5, "pause": 0.42, "knockback": 3.5,
			"reverse": false, "tilt": 0.0, "heavy": true},
	],
	# Сокира: кожен удар — оберт довкола себе, дістає всіх поруч.
	"axe": [
		{"shot": "SlashShot", "anim": "Sword_Slash", "anim_speed": 1.0, "damage": 1.0, "reach": 2.7,
			"arc": 360.0, "shape": "circle", "spin": 0.42, "hit_time": 0.24, "recover": 0.5, "pause": 0.3,
			"knockback": 1.4, "reverse": false, "tilt": 0.0, "heavy": false},
		{"shot": "SlashFastShot", "anim": "Sword_Slash", "anim_speed": 1.2, "damage": 1.1, "reach": 2.7,
			"arc": 360.0, "shape": "circle", "spin": 0.38, "hit_time": 0.22, "recover": 0.46, "pause": 0.3,
			"knockback": 1.4, "reverse": true, "tilt": 0.0, "heavy": false},
		{"shot": "KickShot", "anim": "Sword_Slash", "anim_speed": 0.85, "damage": 1.7, "reach": 3.1,
			"arc": 360.0, "shape": "circle", "spin": 0.55, "hit_time": 0.34, "recover": 0.66, "pause": 0.6,
			"knockback": 3.8, "reverse": false, "tilt": 0.0, "heavy": true},
	],
	# Кинджали: швидкі уколи то правою, то лівою — і кожен вибухає
	# довкола цілі, зачіпаючи сусідів.
	"daggers": [
		{"shot": "SlashShot", "anim": "Punch_Right", "anim_speed": 1.5, "damage": 0.85, "reach": 2.6,
			"arc": 100.0, "burst": [1.6, 0.5], "hit_time": 0.1, "recover": 0.24, "pause": 0.1,
			"knockback": 0.3, "reverse": false, "tilt": 0.1, "heavy": false},
		{"shot": "SlashFastShot", "anim": "Punch_Left", "anim_speed": 1.5, "damage": 0.85, "reach": 2.6,
			"arc": 100.0, "burst": [1.6, 0.5], "hit_time": 0.1, "recover": 0.24, "pause": 0.1,
			"knockback": 0.3, "reverse": true, "tilt": -0.1, "heavy": false},
		{"shot": "KickShot", "anim": "Sword_Slash", "anim_speed": 1.4, "damage": 1.3, "reach": 2.7,
			"arc": 150.0, "burst": [2.2, 0.7], "hit_time": 0.14, "recover": 0.34, "pause": 0.42,
			"knockback": 1.6, "reverse": false, "tilt": 0.0, "heavy": true},
	],
	# Держакова (тризуб): укол прошиває всіх, хто стоїть у ряд, а третій
	# удар — широкий змах держаком.
	"glaive": [
		{"shot": "SlashShot", "anim": "Punch_Right", "anim_speed": 1.25, "damage": 1.1, "reach": 3.0,
			"arc": 30.0, "shape": "line", "width": 1.3, "hit_time": 0.15, "recover": 0.36, "pause": 0.2,
			"knockback": 1.2, "reverse": false, "tilt": 0.0, "heavy": false},
		{"shot": "SlashFastShot", "anim": "Punch_Right", "anim_speed": 1.45, "damage": 1.2, "reach": 3.0,
			"arc": 30.0, "shape": "line", "width": 1.3, "hit_time": 0.13, "recover": 0.33, "pause": 0.2,
			"knockback": 1.2, "reverse": false, "tilt": 0.0, "heavy": false},
		{"shot": "KickShot", "anim": "Sword_Slash", "anim_speed": 1.0, "damage": 1.5, "reach": 2.9,
			"arc": 220.0, "hit_time": 0.2, "recover": 0.5, "pause": 0.5, "knockback": 3.2,
			"reverse": false, "tilt": 0.0, "heavy": true},
	],
	# Парні клинки: кожен замах б'є двічі — правим і лівим.
	"twin_blades": [
		{"shot": "SlashShot", "anim": "Sword_Slash", "anim_speed": 1.35, "damage": 0.75, "reach": 2.8,
			"arc": 170.0, "hits": [0.24], "hit_time": 0.13, "recover": 0.34, "pause": 0.14,
			"knockback": 0.4, "reverse": false, "tilt": 0.14, "heavy": false},
		{"shot": "SlashFastShot", "anim": "Sword_Slash", "anim_speed": 1.6, "damage": 0.75, "reach": 2.8,
			"arc": 170.0, "hits": [0.22], "hit_time": 0.12, "recover": 0.32, "pause": 0.14,
			"knockback": 0.4, "reverse": true, "tilt": -0.2, "heavy": false},
		{"shot": "KickShot", "anim": "Sword_Slash", "anim_speed": 1.1, "damage": 1.1, "reach": 2.9,
			"arc": 360.0, "shape": "circle", "spin": 0.4, "hits": [0.32], "hit_time": 0.2, "recover": 0.46,
			"pause": 0.45, "knockback": 2.2, "reverse": false, "tilt": 0.0, "heavy": true},
	],
	# Тесак: повільні важкі удари, що оглушають; третій ще й б'є об землю.
	"cleaver": [
		{"shot": "SlashShot", "anim": "Sword_Slash", "anim_speed": 0.8, "damage": 1.0, "reach": 2.9,
			"arc": 110.0, "stun": 0.6, "hit_time": 0.3, "recover": 0.62, "pause": 0.3,
			"knockback": 1.2, "reverse": false, "tilt": 0.3, "heavy": true},
		{"shot": "SlashFastShot", "anim": "Sword_Slash", "anim_speed": 0.9, "damage": 1.05, "reach": 2.9,
			"arc": 110.0, "stun": 0.6, "hit_time": 0.28, "recover": 0.58, "pause": 0.3,
			"knockback": 1.2, "reverse": true, "tilt": -0.3, "heavy": true},
		{"shot": "KickShot", "anim": "Sword_Slash", "anim_speed": 0.7, "damage": 1.6, "reach": 3.0,
			"arc": 130.0, "stun": 1.1, "burst": [2.0, 0.5], "hit_time": 0.36, "recover": 0.72, "pause": 0.6,
			"knockback": 2.6, "reverse": false, "tilt": 0.5, "heavy": true},
	],
}

## Свої комбо героя (анімації — WardenMoves, зібрані кодом): п'ять ланок
## замість трьох, кожна — свій рух і свої іскри ("spark", див.
## CombatVfx.hit_spark); п'ята — фініш ("finisher": довша зупинка кадру й
## трус). Стилі, яких тут немає, б'ють за STYLE_COMBOS.
const HERO_COMBOS := {
	&"blade_warden": {
		# Меч (справжні анімації, WeaponAnims): назовні, назад, згори вниз і
		# широкий мах-фініш. Однорукий меч не крутить героя.
		"sword": [
			{"shot": "SlashShot", "anim": "W_attack_1", "anim_speed": 1.8, "damage": 0.95, "reach": 2.9, "arc": 150.0,
				"hit_time": 0.23, "recover": 0.42, "pause": 0.05, "knockback": 0.6, "reverse": true, "tilt": 0.25,
				"heavy": false, "spark": "slash"},
			{"shot": "SlashFastShot", "anim": "W_attack_2", "anim_speed": 1.8, "damage": 1.05, "reach": 2.9, "arc": 150.0,
				"hit_time": 0.25, "recover": 0.44, "pause": 0.05, "knockback": 0.6, "reverse": false, "tilt": -0.25,
				"heavy": false, "spark": "rising"},
			{"shot": "KickShot", "anim": "W_attack_3", "anim_speed": 1.6, "damage": 1.3, "reach": 3.1, "arc": 100.0,
				"hit_time": 0.27, "recover": 0.5, "pause": 0.08, "knockback": 1.4, "reverse": false, "tilt": 1.3,
				"heavy": true, "spark": "sweep"},
			{"shot": "Combo4Shot", "anim": "W_attack_4", "anim_speed": 1.5, "damage": 2.2, "reach": 3.1, "arc": 220.0,
				"hit_time": 0.35, "recover": 0.66, "pause": 0.45, "knockback": 3.5, "stun": 0.6,
				"reverse": false, "tilt": 0.0, "heavy": true, "spark": "finisher", "finisher": true},
		],
		# Сокира (справжні анімації): горизонтальний мах, оберт на 360° (оберт
		# у самому кліпі) і удар згори обома руками об землю.
		"axe": [
			{"shot": "SlashShot", "anim": "W_attack_1", "anim_speed": 1.5, "damage": 1.0, "reach": 2.9, "arc": 160.0,
				"hit_time": 0.33, "recover": 0.52, "pause": 0.06, "knockback": 1.2, "reverse": false, "tilt": 0.2,
				"heavy": true, "spark": "sweep"},
			{"shot": "SlashFastShot", "anim": "W_attack_2", "anim_speed": 1.5, "damage": 1.15, "reach": 2.8, "arc": 360.0,
				"shape": "circle", "hit_time": 0.4, "recover": 0.72, "pause": 0.08, "knockback": 1.6, "reverse": true,
				"tilt": 0.0, "heavy": true, "spark": "spin"},
			{"shot": "KickShot", "anim": "W_attack_3", "anim_speed": 1.4, "damage": 2.0, "reach": 3.0, "arc": 130.0,
				"hit_time": 0.54, "recover": 0.88, "pause": 0.5, "knockback": 3.6, "stun": 0.5, "reverse": false,
				"tilt": 1.3, "heavy": true, "spark": "finisher", "finisher": true},
		],
		# Тесак: три важкі рублячі удари без обертів, що оглушають; третій —
		# згори, з ударом об землю.
		"cleaver": [
			{"shot": "SlashShot", "anim": "W_attack_1", "anim_speed": 1.3, "damage": 1.0, "reach": 2.9, "arc": 120.0,
				"stun": 0.4, "hit_time": 0.27, "recover": 0.56, "pause": 0.08, "knockback": 1.2, "reverse": false,
				"tilt": 0.3, "heavy": true, "spark": "slash"},
			{"shot": "SlashFastShot", "anim": "W_attack_2", "anim_speed": 1.3, "damage": 1.1, "reach": 2.9, "arc": 120.0,
				"stun": 0.4, "hit_time": 0.35, "recover": 0.56, "pause": 0.08, "knockback": 1.2, "reverse": true,
				"tilt": -0.3, "heavy": true, "spark": "rising"},
			{"shot": "KickShot", "anim": "W_attack_3", "anim_speed": 1.25, "damage": 1.9, "reach": 3.0, "arc": 130.0,
				"stun": 1.0, "burst": [2.0, 0.5], "hit_time": 0.48, "recover": 0.82, "pause": 0.5, "knockback": 2.8,
				"reverse": false, "tilt": 1.3, "heavy": true, "spark": "finisher", "finisher": true},
		],
		# Глефа (дворучна): укол прошиває ряд, оберт із замахом (оберт у
		# кліпі), удар згори.
		"glaive": [
			{"shot": "SlashShot", "anim": "W_attack_1", "anim_speed": 1.4, "damage": 1.1, "reach": 3.4, "arc": 30.0,
				"shape": "line", "width": 1.3, "hit_time": 0.3, "recover": 0.55, "pause": 0.06, "knockback": 1.2,
				"reverse": false, "tilt": 0.0, "heavy": false, "spark": "slash"},
			{"shot": "SlashFastShot", "anim": "W_attack_2", "anim_speed": 1.4, "damage": 1.2, "reach": 3.2, "arc": 360.0,
				"shape": "circle", "hit_time": 0.43, "recover": 0.76, "pause": 0.08, "knockback": 1.8, "reverse": false,
				"tilt": 0.0, "heavy": true, "spark": "spin"},
			{"shot": "KickShot", "anim": "W_attack_3", "anim_speed": 1.35, "damage": 1.9, "reach": 3.4, "arc": 120.0,
				"hit_time": 0.33, "recover": 0.72, "pause": 0.45, "knockback": 3.4, "stun": 0.5, "reverse": false,
				"tilt": 1.3, "heavy": true, "spark": "finisher", "finisher": true},
		],
		# Кинджали (справжні анімації): уколи лівою, правою, лівою, зворотним
		# хватом і подвійний укол-фініш. Кожен укол вибухає довкола цілі.
		"daggers": [
			{"shot": "SlashShot", "anim": "W_attack_1", "anim_speed": 1.5, "damage": 0.75, "reach": 2.6, "arc": 100.0,
				"burst": [1.6, 0.4], "hit_time": 0.17, "recover": 0.31, "pause": 0.03, "knockback": 0.3,
				"reverse": true, "tilt": 0.1, "heavy": false, "spark": "slash"},
			{"shot": "SlashFastShot", "anim": "W_attack_2", "anim_speed": 1.5, "damage": 0.75, "reach": 2.6, "arc": 100.0,
				"burst": [1.6, 0.4], "hit_time": 0.2, "recover": 0.36, "pause": 0.03, "knockback": 0.3,
				"reverse": false, "tilt": -0.1, "heavy": false, "spark": "rising"},
			{"shot": "KickShot", "anim": "W_attack_3", "anim_speed": 1.5, "damage": 0.8, "reach": 2.6, "arc": 100.0,
				"burst": [1.6, 0.4], "hit_time": 0.17, "recover": 0.36, "pause": 0.03, "knockback": 0.4,
				"reverse": true, "tilt": 0.1, "heavy": false, "spark": "slash"},
			{"shot": "Combo4Shot", "anim": "W_attack_4", "anim_speed": 1.5, "damage": 0.9, "reach": 2.7, "arc": 120.0,
				"burst": [1.8, 0.45], "hit_time": 0.23, "recover": 0.4, "pause": 0.05, "knockback": 0.8,
				"reverse": false, "tilt": -0.2, "heavy": false, "spark": "sweep"},
			{"shot": "Combo5Shot", "anim": "W_attack_5", "anim_speed": 1.4, "damage": 1.9, "reach": 2.8, "arc": 140.0,
				"burst": [2.4, 0.6], "hit_time": 0.29, "recover": 0.62, "pause": 0.42, "knockback": 3.0, "stun": 0.5,
				"reverse": false, "tilt": 0.0, "heavy": true, "spark": "finisher", "finisher": true},
		],
		# Парні клинки (справжні анімації): лівий, правий, обидва, оберт
		# (оберт у кліпі), хрест обома. Удари обома клинками б'ють двічі.
		"twin_blades": [
			{"shot": "SlashShot", "anim": "W_attack_1", "anim_speed": 1.3, "damage": 0.7, "reach": 2.8, "arc": 160.0,
				"hit_time": 0.27, "recover": 0.4, "pause": 0.04, "knockback": 0.4, "reverse": true, "tilt": 0.35,
				"heavy": false, "spark": "slash"},
			{"shot": "SlashFastShot", "anim": "W_attack_2", "anim_speed": 1.3, "damage": 0.7, "reach": 2.8, "arc": 160.0,
				"hit_time": 0.19, "recover": 0.37, "pause": 0.04, "knockback": 0.4, "reverse": false, "tilt": -0.35,
				"heavy": false, "spark": "rising"},
			{"shot": "KickShot", "anim": "W_attack_3", "anim_speed": 1.3, "damage": 0.65, "reach": 2.9, "arc": 180.0,
				"hits": [0.36], "hit_time": 0.3, "recover": 0.45, "pause": 0.05, "knockback": 0.8, "reverse": true,
				"tilt": 0.0, "heavy": false, "spark": "sweep"},
			{"shot": "Combo4Shot", "anim": "W_attack_4", "anim_speed": 1.2, "damage": 0.75, "reach": 2.9, "arc": 360.0,
				"shape": "circle", "hits": [0.42], "hit_time": 0.29, "recover": 0.52, "pause": 0.06, "knockback": 1.8,
				"reverse": false, "tilt": 0.0, "heavy": true, "spark": "spin"},
			{"shot": "Combo5Shot", "anim": "W_attack_5", "anim_speed": 1.1, "damage": 1.6, "reach": 3.0, "arc": 200.0,
				"hits": [0.5], "hit_time": 0.2, "recover": 0.8, "pause": 0.45, "knockback": 3.5, "stun": 0.6,
				"reverse": false, "tilt": 0.0, "heavy": true, "spark": "finisher", "finisher": true},
		],
	},
}

## Як чаклує герой залежно від зброї — жодних помахів, як мечем:
##   посохи (Чарівниця) — то штовхає посох уперед, то наводить на ворога;
##   книга рун — тримає книгу, а руну посилає вільною рукою;
##   карти — кидає то правою, то лівою.
const CAST_ANIMS := {
	"staff": ["Punch_Right", "Gun_Shoot", "Interact"],
	"rune": ["Punch_Left", "Interact", "Interact"],
	"cards": ["Punch_Right", "Punch_Left", "Interact"],
}
const CAST_ANIM_SPEEDS := {
	"staff": [1.5, 1.6, 1.0],
	"rune": [1.4, 1.3, 1.0],
	"cards": [1.7, 1.7, 1.0],
}

## Три слоти анімації удару в дереві анімацій і їхні регулятори швидкості.
const SLOTS := ["SlashShot", "SlashFastShot", "KickShot", "Combo4Shot", "Combo5Shot"]
const SLOT_SCALES := ["SlashScale", "SlashFastScale", "KickScale", "Combo4Scale", "Combo5Scale"]
## Кадр анімації Dash_Strike, коли клинок б'є (WardenMoves) — під нього
## підганяємо швидкість, щоб удар збігся з кінцем ривка.
const DASH_STRIKE_AT := 0.46
## Вибух довкола цілі (кинджали, тесак).
const BURST_COLOR := Color(1.0, 0.6, 0.25)

## --- Перекат ---
const DODGE_SPEED := 11.0
const DODGE_TIME := 0.38
const DODGE_INVULNERABLE := 0.34
const DODGE_COOLDOWN := 0.9

## Скільки дає один рівень спільних талантів (екран "Таланти").
const TALENT_HP_PER_LEVEL := 10.0
const TALENT_DAMAGE_PER_LEVEL := 0.05
const TALENT_SPEED_PER_LEVEL := 0.03

## Після отриманої шкоди — мить невразливості, щоб натовп не "заклював"
## героя за один кадр.
const HURT_INVULNERABLE := 0.35

## ІДЕАЛЬНИЙ ПЕРЕКАТ: ворожий удар (меч, куля, вибух) влучив би, але
## герой саме котився. Світ на мить сповільнюється, наступні кілька
## секунд усі удари критичні, а перекат одразу готовий знову. Червоні
## зони замаху для цього й існують: перекотитись треба тоді, коли зона
## вже майже заповнилась.
const PERFECT_SLOWMO := 0.5
const PERFECT_SLOWMO_SCALE := 0.35
const PERFECT_CRIT_TIME := 2.0
const PERFECT_COLOR := Color(0.5, 0.95, 1.0)
## Щит після воскресіння за відео: золотава куля, світиться краями.
const REVIVE_SHIELD_COLOR := Color(1.0, 0.82, 0.4)
## Як швидко гасне відкидання, коли героя збили з ніг (м/с за секунду).
const KNOCK_DECAY := 14.0
const REVIVE_SHIELD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.82, 0.4, 1.0);
uniform float strength = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float shimmer = 0.85 + 0.15 * sin(TIME * 6.0 + UV.y * 18.0);
	ALBEDO = color.rgb * (0.12 + rim * 1.3) * shimmer * strength;
}
"""

const HEALTH_BAR_SCRIPT := preload("res://scenes/dungeon/health_bar_3d.gd")

## Зелена смужка — для своїх: героя й дружніх NPC.
const ALLY_BAR_COLOR := Color(0.35, 0.9, 0.4)
const BAR_HEIGHT := 2.1

## Кістки нижньої частини тіла. Удар під час бігу грається лише верхом:
## ноги біжать, руки б'ють.
const LOWER_BODY_MARKERS := ["Root", "Body", "Hips", "Leg", "Foot", "PT.", "Toe"]

@onready var model: Node3D = $Model
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var camera_pivot: Node3D = $CameraPivot

## Острів вимикає бойове керування з клавіатури: там пробіл — це "зайти
## в будівлю".
var combat_input_enabled := true

## Хто саме зараз у грі і з чим. Задається з GameState у _ready.
var hero_def: HeroDef
## Скільки шкоди завдало кожне джерело за похід: {&"weapon": ..., id здібності: ...}.
var damage_by_source: Dictionary = {}
var weapon_def: WeaponDef
var passive: HeroPassive3D

var max_hp := BASE_MAX_HP
var current_hp := BASE_MAX_HP

var _input_direction := Vector2.ZERO
var _facing_angle := 0.0
var _damage := BASE_DAMAGE
var _speed_bonus := 0.0
var _attack_speed := 1.0
var _dead := false
var _regen_per_second := 0.0
var _health_bar: HealthBar3D
var _torch: OmniLight3D

var _target: Enemy3D
var _retarget_left := 0.0
var _combat_left := 0.0
var _since_attack := 99.0
var _target_marker: MeshInstance3D

var _combo_index := 0
var _combo_expire := 0.0
var _attack_step := -1
var _attack_time := 0.0
var _attack_hit_done := false
var _attack_vfx_done := false
var _attack_queued := false
var _attack_held := false
## Перепочинок після удару: поки він іде, новий удар лише чекає черги.
var _attack_cooldown_left := 0.0
## Скільки повторних влучань ланки вже було (парні клинки).
var _extra_hit := 0
var _lunge_velocity := Vector3.ZERO
var _lunge_left := 0.0

var _roll_direction := Vector3.ZERO
var _roll_left := 0.0
var _dodge_cooldown_left := 0.0
var _invulnerable_left := 0.0
## Скільки ще триває невразливість саме від перекату (не після поранення).
var _roll_guard_left := 0.0
var _roll_origin := Vector3.INF
var _roll_started_msec := 0
var _perfect_this_roll := false
var _perfect_crit_left := 0.0
## Тимчасовий множник шкоди (серія ударів у данжі).
var _bonus_damage := 1.0
var _bonus_damage_left := 0.0
## Сповільнення (павутина): частка швидкості й скільки ще діє.
var _slow_factor := 1.0
var _slow_left := 0.0
var _slow_marker: MeshInstance3D
## Стороннє тягнення (вир Безодні мега-боса): гравець не втрачає керування,
## але його зносить до центру, поки він не вийде з зони. Задає сама
## небезпека щокадру (0 — не тягне).
var _pull_velocity := Vector3.ZERO
## Тягнення, додане до velocity минулого кадру. Перед кермуванням його
## віднімаємо: інакше velocity щокадру росла б на швидкість вихору
## (прискорення героя — лише ~0.23 м/с за кадр), героя розганяло в центр,
## там трясло на місці, а коли вир зникав — жбурляло геть.
var _pull_applied := Vector3.ZERO
## Збили з ніг (таран щитоносця): відлітає, мить не керує рухом і не б'є.
var _knock_left := 0.0
## Оглушення (бос): зірочки над головою, ні кроку, ні удару, ні перекату.
var _stun_stars: Node3D
## Схопили кістяні руки (чаклун): стоїть на місці, але може бити.
var _rooted_left := 0.0
var _root_marker: MeshInstance3D
var _knock_velocity := Vector3.ZERO

var _skills: Array[HeroSkill3D] = []
var _spin_left := 0.0
var _spin_total := 0.45
## Оберт робить код (крутить модель) — false, коли оберт є в самій
## анімації (Вихор із справжнім кліпом).
var _spin_turns := true
## Справжні анімації під зброю (WeaponAnims): коротка назва -> повна.
var _anim_overrides := {}
var _dash_strike_at := DASH_STRIKE_AT

## Тимчасові підсилення: прискорення ударів після ривка люті та
## "невидимість" асасина.
var _attack_speed_buff := 1.0
var _attack_speed_left := 0.0
## Холодний дотик (Кладовищенський привид): удари повільніші, доки не мине.
var _chill_factor := 1.0
var _chill_left := 0.0
var _chill_marker: MeshInstance3D
var _concealed_left := 0.0
var _concealed_damage := 1.0
var _concealed_speed := 0.0

var _model_instance: Node3D
var _weapon_node: Node3D

## Стрільба: скільки набоїв лишилось, коли можна наступний постріл і
## скільки триває перезарядка.
## --- Що дали здібності, набрані в поході (RunUpgrades) ---
## Кожне поле хтось читає в бою, тож жодна здібність не буває "пустою".
var _crit_chance := CRIT_CHANCE
var _lifesteal := 0.0
var _damage_taken_factor := 1.0

## СВЯТИЛИЩА ДАНЖУ (Shrine): тимчасова сила — лють (більше шкоди), вітер
## (швидше бігає й б'є) або камінь (менше шкоди по герою).
const SHRINE_FURY_DAMAGE := 1.5
const SHRINE_HASTE_SPEED := 0.3
const SHRINE_HASTE_ATTACK := 1.3
const SHRINE_GUARD_FACTOR := 0.6
var _shrine_kind := &""
var _shrine_left := 0.0
var _knockback_factor := 1.0
var _arc_factor := 1.0
var _reach_bonus := 0.0
var _skill_cooldown_factor := 1.0
var _dodge_cooldown_factor := 1.0
var _rage_gain_factor := 1.0
var _dash_power := 1.0
var _whirl_power := 1.0
var _mark_bonus := 0.0
var _smoke_bonus := 0.0
var _bullet_pierce := 0
var _bullets_extra := 0
var _spread_factor := 1.0
var _magazine_factor := 1.0
var _reload_factor := 1.0
var _fire_rate_factor := 1.0
var _explosive_bullets := 0

var _ammo := 0
var _fire_left := 0.0
var _reload_left := 0.0

## Чари посоха: затримка до наступних, відкладений випуск (снаряд
## злітає з посоха в мить помаху, а не на початку руху) і лічильник для
## чергування рухів.
var _cast_left := 0.0
var _cast_pending_left := -1.0
var _cast_count := 0
var _cast_rate_factor := 1.0
var _spell_extra := 0
var _spell_pierce := 0
var _spell_power := 1.0
var _ring_power := 1.0
var _phoenix_bonus := 0.0
var _nova_power := 1.0
var _charge_hits := 7

var _blend_position := Vector2.ZERO
var _upper_body_filter: Array[NodePath] = []

func _ready() -> void:
	_ensure_input_actions()
	_load_hero()
	_build_animation_tree()
	animation_tree.active = true
	_facing_angle = rotation.y
	_health_bar = HEALTH_BAR_SCRIPT.new()
	add_child(_health_bar)
	_health_bar.setup(ALLY_BAR_COLOR, BAR_HEIGHT, true)
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
	# У посоха своя особлива здібність — вона стає першою кнопкою.
	if weapon_def != null and weapon_def.staff_skill != &"":
		var staff_skill := Skills3D.create_skill(weapon_def.staff_skill)
		if staff_skill != null:
			_skills.insert(0, staff_skill)

## Модель героя й зброя в руці — те саме, що показує екран вибору
## (HeroBuilder). Немає своєї моделі — береться тимчасова в кольорі героя.
func _build_model() -> void:
	# Стару модель прибираємо З ДЕРЕВА одразу, а не лише queue_free():
	# інакше вона живе до кінця кадру, і зброя причепилась би до неї.
	for child in model.get_children():
		model.remove_child(child)
		child.queue_free()
	var built := HeroBuilder.build_model(hero_def)
	_model_instance = built[0]
	if _model_instance == null:
		push_warning("Немає жодної моделі героя")
		return
	model.add_child(_model_instance)

func _equip_weapon() -> void:
	if _model_instance != null:
		_weapon_node = HeroBuilder.attach_weapon(_model_instance, hero_def, weapon_def)
	if is_ranged():
		_ammo = magazine_size()

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
		_attack_speed = weapon_def.speed_mult_3d

## Світло, яке герой носить із собою. Це найдешевший спосіб освітити
## підземелля: одне джерело замість десятків по стінах.
func _add_torch_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.65)
	light.light_energy = 2.6
	light.omni_range = 18.0
	light.position = Vector3(0, 1.6, 0)
	add_child(light)
	_torch = light

## Удень на острові смолоскип не потрібен: сонце світить і так, а кожне
## джерело світла телефон рахує для кожного пікселя навколо героя.
func set_torch_enabled(enabled: bool) -> void:
	if _torch != null:
		_torch.visible = enabled

## Клавіші для ПК: пробіл/J — удар, Shift/K — перекат, E/L — вихор.
## Додаються кодом, щоб не залежати від налаштувань проєкту.
static func _ensure_input_actions() -> void:
	var actions := {
		"attack": [KEY_SPACE, KEY_J],
		"dodge": [KEY_SHIFT, KEY_K],
		"skill": [KEY_E, KEY_L],
		"skill_2": [KEY_Q, KEY_U],
	}
	for action: String in actions:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

# --- дерево анімацій ---

## Дерево анімацій будуємо кодом: увесь набір станів видно в одному
## місці, і його легко перенести на інших героїв Quaternius.
##
##   Move (2D)   — спокій, хода, біг уперед, назад, уліво, вправо;
##                 положення в просторі = швидкість відносно погляду.
##   SlashShot, SlashFastShot, KickShot — три ланки комбо поверх руху;
##   RollShot    — перекат, перекриває все;
##   HitShot     — здригання від удару (лише верх тіла);
##   Dead        — смерть, лишається на останньому кадрі.
func _build_animation_tree() -> void:
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	animation_tree.anim_player = animation_tree.get_path_to(player)
	# Справжні анімації під зброю героя (стійка, біг, серія, ривок, вихор).
	var style: String = weapon_def.style_3d if weapon_def != null else "sword"
	var hero_id: StringName = hero_def.id if hero_def != null else &""
	_anim_overrides = WeaponAnims.install(player, hero_id, style)
	_dash_strike_at = float(WeaponAnims.get_set(hero_id, style).get("dash_strike_at", DASH_STRIKE_AT))
	# Удари комбо й ривок Клинкової Вартової — зібрані кодом (WardenMoves).
	if hero_def != null and hero_def.id == &"blade_warden":
		ProceduralAnims.build(player, _anim("Idle_Sword"), WardenMoves.SPECS, _anim(""))
	_make_looping(player, ["Idle", "Walk", "Run", "Run_Back", "Run_Left", "Run_Right"])
	var slash_name := _anim("Sword_Slash")
	if not player.has_animation(slash_name):
		slash_name = player.get_animation_list()[0]
	_upper_body_filter = _collect_upper_body_tracks(player.get_animation(slash_name))

	var move := AnimationNodeBlendSpace2D.new()
	move.min_space = Vector2(-1, -1)
	move.max_space = Vector2(1, 1)
	# Зі стволом у руках герой і стоїть інакше, і стріляє, а не махає.
	var ranged := is_ranged()
	move.add_blend_point(_animation_node("Idle_Gun" if ranged else "Idle", ["Idle"]), Vector2(0, 0), -1, &"idle")
	move.add_blend_point(_animation_node("Walk"), Vector2(0, 0.48), -1, &"walk")
	move.add_blend_point(_animation_node("Run"), Vector2(0, 1), -1, &"run")
	move.add_blend_point(_animation_node("Run_Back", ["Walk", "Run"]), Vector2(0, -1), -1, &"back")
	move.add_blend_point(_animation_node("Run_Left", ["Walk", "Run"]), Vector2(-1, 0), -1, &"left")
	move.add_blend_point(_animation_node("Run_Right", ["Walk", "Run"]), Vector2(1, 0), -1, &"right")

	var tree := AnimationNodeBlendTree.new()
	tree.add_node(&"Move", move, Vector2(0, 0))

	# Три слоти удару. Що саме в них грає, залежить від зброї: у меча —
	# два замахи й удар ногою, у кинджалів — уколи з обох рук, у
	# стрільця — постріл і перезарядка.
	var slots := _attack_slot_animations()
	tree.add_node(&"SlashAnim", _animation_node(slots[0], ["Sword_Slash"]), Vector2(0, 200))
	tree.add_node(&"SlashScale", AnimationNodeTimeScale.new(), Vector2(200, 200))
	tree.add_node(&"SlashShot", _one_shot(0.06, 0.16), Vector2(400, 0))
	tree.add_node(&"SlashFastAnim", _animation_node(slots[1], ["Sword_Slash"]), Vector2(0, 400))
	tree.add_node(&"SlashFastScale", AnimationNodeTimeScale.new(), Vector2(200, 400))
	tree.add_node(&"SlashFastShot", _one_shot(0.05, 0.16), Vector2(600, 0))
	tree.add_node(&"KickAnim", _animation_node(slots[2],
		["Kick_Right", "Punch_Right", "Sword_Slash"]), Vector2(0, 600))
	tree.add_node(&"KickScale", AnimationNodeTimeScale.new(), Vector2(200, 600))
	tree.add_node(&"KickShot", _one_shot(0.06, 0.2), Vector2(800, 0))
	# Четверта й п'ята ланки (свої комбо героя) і ривок люті.
	tree.add_node(&"Combo4Anim", _animation_node(slots[3], ["Sword_Slash"]), Vector2(0, 1400))
	tree.add_node(&"Combo4Scale", AnimationNodeTimeScale.new(), Vector2(200, 1400))
	tree.add_node(&"Combo4Shot", _one_shot(0.05, 0.16), Vector2(850, 0))
	tree.add_node(&"Combo5Anim", _animation_node(slots[4], ["Sword_Slash"]), Vector2(0, 1600))
	tree.add_node(&"Combo5Scale", AnimationNodeTimeScale.new(), Vector2(200, 1600))
	tree.add_node(&"Combo5Shot", _one_shot(0.05, 0.2), Vector2(900, 0))
	# Вихор — свій слот (серія з 5 ударів займає всі п'ять слотів).
	tree.add_node(&"WhirlAnim", _animation_node("W_whirl", ["Sword_Slash"]), Vector2(0, 1700))
	tree.add_node(&"WhirlScale", AnimationNodeTimeScale.new(), Vector2(200, 1700))
	tree.add_node(&"WhirlShot", _one_shot(0.06, 0.2), Vector2(925, 0))
	tree.add_node(&"DashAnim", _animation_node("Dash_Strike", ["Sword_Slash"]), Vector2(0, 1800))
	tree.add_node(&"DashScale", AnimationNodeTimeScale.new(), Vector2(200, 1800))
	tree.add_node(&"DashShot", _one_shot(0.05, 0.18), Vector2(950, 0))
	tree.add_node(&"RollAnim", _animation_node("Roll", ["Run", "Walk"]), Vector2(0, 800))
	tree.add_node(&"RollScale", AnimationNodeTimeScale.new(), Vector2(200, 800))
	tree.add_node(&"RollShot", _one_shot(0.04, 0.12), Vector2(1000, 0))
	tree.add_node(&"HitAnim", _animation_node("HitRecieve", ["HitReact", "Idle"]), Vector2(0, 1000))
	var hit_shot := _one_shot(0.05, 0.15)
	_apply_filter(hit_shot, true)
	tree.add_node(&"HitShot", hit_shot, Vector2(1200, 0))
	tree.add_node(&"DeathAnim", _animation_node("Death", ["HitRecieve", "Idle"]), Vector2(0, 1200))
	var dead := AnimationNodeBlend2.new()
	tree.add_node(&"Dead", dead, Vector2(1400, 0))

	tree.connect_node(&"SlashScale", 0, &"SlashAnim")
	tree.connect_node(&"SlashShot", 0, &"Move")
	tree.connect_node(&"SlashShot", 1, &"SlashScale")
	tree.connect_node(&"SlashFastScale", 0, &"SlashFastAnim")
	tree.connect_node(&"SlashFastShot", 0, &"SlashShot")
	tree.connect_node(&"SlashFastShot", 1, &"SlashFastScale")
	tree.connect_node(&"KickScale", 0, &"KickAnim")
	tree.connect_node(&"KickShot", 0, &"SlashFastShot")
	tree.connect_node(&"KickShot", 1, &"KickScale")
	tree.connect_node(&"RollScale", 0, &"RollAnim")
	tree.connect_node(&"Combo4Scale", 0, &"Combo4Anim")
	tree.connect_node(&"Combo4Shot", 0, &"KickShot")
	tree.connect_node(&"Combo4Shot", 1, &"Combo4Scale")
	tree.connect_node(&"Combo5Scale", 0, &"Combo5Anim")
	tree.connect_node(&"Combo5Shot", 0, &"Combo4Shot")
	tree.connect_node(&"Combo5Shot", 1, &"Combo5Scale")
	tree.connect_node(&"DashScale", 0, &"DashAnim")
	tree.connect_node(&"WhirlScale", 0, &"WhirlAnim")
	tree.connect_node(&"WhirlShot", 0, &"Combo5Shot")
	tree.connect_node(&"WhirlShot", 1, &"WhirlScale")
	tree.connect_node(&"DashShot", 0, &"WhirlShot")
	tree.connect_node(&"DashShot", 1, &"DashScale")
	tree.connect_node(&"RollShot", 0, &"DashShot")
	tree.connect_node(&"RollShot", 1, &"RollScale")
	tree.connect_node(&"HitShot", 0, &"RollShot")
	tree.connect_node(&"HitShot", 1, &"HitAnim")
	tree.connect_node(&"Dead", 0, &"HitShot")
	tree.connect_node(&"Dead", 1, &"DeathAnim")
	tree.connect_node(&"output", 0, &"Dead")
	animation_tree.tree_root = tree

	# Перекат триває DODGE_TIME, а анімація довша — пришвидшуємо її так,
	# щоб перекид завершився разом із ривком.
	var roll_name := (tree.get_node(&"RollAnim") as AnimationNodeAnimation).animation
	var roll_length := player.get_animation(roll_name).length
	animation_tree.set("parameters/RollScale/scale", roll_length / (DODGE_TIME + 0.12))
	_apply_attack_speed()

func _one_shot(fade_in: float, fade_out: float) -> AnimationNodeOneShot:
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = fade_in
	shot.fadeout_time = fade_out
	return shot

## Фільтр "лише верх тіла" — список доріжок анімації, що рухають кістки
## від живота й вище.
func _apply_filter(shot: AnimationNodeOneShot, enabled: bool) -> void:
	for path in _upper_body_filter:
		shot.set_filter_path(path, true)
	shot.filter_enabled = enabled

func _collect_upper_body_tracks(animation: Animation) -> Array[NodePath]:
	var result: Array[NodePath] = []
	for i in animation.get_track_count():
		var path := animation.track_get_path(i)
		var bone := String(path.get_concatenated_subnames())
		if bone == "":
			continue
		var lower := false
		for marker: String in LOWER_BODY_MARKERS:
			if bone.contains(marker):
				lower = true
				break
		if not lower:
			result.append(path)
	return result

## Повна назва анімації в моделі. Стандарт — набори Quaternius
## ("CharacterArmature|Run"), але в HeroDef.animation_names можна задати
## свої назви для моделі з іншого набору.
func _anim(short_name: String) -> String:
	if _anim_overrides.has(short_name):
		return _anim_overrides[short_name]
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
	return node

## Хода, біг і спокій мають крутитись по колу; імпорт glTF за
## замовчуванням лишає їх одноразовими.
func _make_looping(player: AnimationPlayer, names: Array) -> void:
	for short_name: String in names:
		if player.has_animation(_anim(short_name)):
			player.get_animation(_anim(short_name)).loop_mode = Animation.LOOP_LINEAR

func _apply_attack_speed() -> void:
	var speed := attack_speed()
	var speeds := [1.15, 1.45, 1.1, 1.0, 1.0]
	if is_caster():
		var casts := _cast_moves()
		if not casts.is_empty():
			speeds = [casts[0][2], casts[1 % casts.size()][2], 1.0, 1.0, 1.0]
		else:
			speeds = (CAST_ANIM_SPEEDS.get(weapon_def.spell, CAST_ANIM_SPEEDS["staff"]) as Array).duplicate()
			speeds.append_array([1.0, 1.0])
	elif not is_ranged():
		for step: Dictionary in _combo():
			speeds[SLOTS.find(step.shot)] = float(step.get("anim_speed", 1.0))
	for i in SLOT_SCALES.size():
		animation_tree.set("parameters/%s/scale" % SLOT_SCALES[i], speeds[i] * speed)

## Комбо для зброї в руках — за її стилем (невідомий стиль б'є як меч).
func _combo() -> Array:
	var style: String = weapon_def.style_3d if weapon_def != null else "sword"
	var hero_id: StringName = hero_def.id if hero_def != null else &""
	var own: Dictionary = HERO_COMBOS.get(hero_id, {})
	if own.has(style):
		return own[style]
	return STYLE_COMBOS.get(style, STYLE_COMBOS["sword"])

## Анімації трьох слотів удару.
func _attack_slot_animations() -> Array:
	if is_ranged():
		# Для стрільця третій слот — рух перезарядки.
		return ["Gun_Shoot", "Gun_Shoot", "Interact", "Gun_Shoot", "Gun_Shoot"]
	if is_caster():
		var casts := _cast_moves()
		if not casts.is_empty():
			return [casts[0][0], casts[1 % casts.size()][0], "Interact", "Interact", "Interact"]
		return (CAST_ANIMS.get(weapon_def.spell, CAST_ANIMS["staff"]) as Array) + ["Interact", "Interact"]
	var result := ["Sword_Slash", "Sword_Slash", "Kick_Right", "Sword_Slash", "Sword_Slash"]
	for step: Dictionary in _combo():
		result[SLOTS.find(step.shot)] = String(step.get("anim", "Sword_Slash"))
	return result

## Швидкість ударів разом із тимчасовим прискоренням (ривок люті).
func amp_attack_speed() -> float:
	return attack_speed()

func attack_speed() -> float:
	return _attack_speed * (_attack_speed_buff if _attack_speed_left > 0.0 else 1.0) * _chill()

func _chill() -> float:
	return _chill_factor if _chill_left > 0.0 else 1.0

## Холодний дотик: seconds секунд удари на (1 - factor) повільніші, під
## героєм блідо-блакитне коло.
func chill_attacks(factor: float, seconds: float) -> void:
	if _dead:
		return
	_chill_factor = factor
	_chill_left = maxf(_chill_left, seconds)
	_apply_attack_speed()
	CombatVfx.flash_model(model, Color(0.6, 0.85, 1.0), 0.2)
	if _chill_marker == null:
		_chill_marker = CombatVfx.make_ground_marker(Color(0.55, 0.8, 1.0, 0.6), 0.6)
		CombatVfx.set_param(_chill_marker, &"progress", 1.0)
		_chill_marker.position.y = 0.06
		add_child(_chill_marker)
	_chill_marker.visible = true

## Підкидає (хробак вистрибнув під героєм): збиває з ніг на seconds, а
## модель злітає вгору й падає.
func toss(seconds: float) -> void:
	if _dead or _roll_left > 0.0:
		return
	knock_down(Vector3.ZERO, seconds)
	var rest := model.position.y
	var tween := model.create_tween()
	tween.tween_property(model, "position:y", rest + 1.3, seconds * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(model, "position:y", rest, seconds * 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _fire(shot: String, upper_body_only: bool = false) -> void:
	var node := (animation_tree.tree_root as AnimationNodeBlendTree).get_node(shot) as AnimationNodeOneShot
	if node != null and shot != "HitShot":
		_apply_filter(node, upper_body_only)
	animation_tree.set("parameters/%s/request" % shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _abort_attacks() -> void:
	for shot in SLOTS:
		animation_tree.set("parameters/%s/request" % shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)

# --- керування ---

## Напрямок від джойстика або клавіатури: (0,0) — стоїмо.
func set_move_input(direction: Vector2) -> void:
	_input_direction = direction

## Удар (дотик, клік, кнопка). Якщо герой ще б'є — удар запам'ятовується
## й почнеться одразу, щойно закінчиться попередній.
## Чи в руках вогнепальна зброя.
func is_ranged() -> bool:
	return weapon_def != null and weapon_def.ranged_3d

## Чи в руках посох: чари замість ударів.
func is_caster() -> bool:
	return weapon_def != null and weapon_def.spell != "none"

func attack() -> void:
	if _dead or _knock_left > 0.0:
		return
	if is_ranged():
		_try_shoot()
		return
	if is_caster():
		_try_cast()
		return
	# Удар ще йде, герой котиться чи переводить подих після удару —
	# натискання запам'ятовується й спрацює, щойно можна.
	if _attack_step >= 0 or _roll_left > 0.0 or _spin_left > 0.0 or _attack_cooldown_left > 0.0:
		_attack_queued = true
		return
	_start_attack()

# --- стрільба ---

## Набої в магазині: (скільки лишилось, скільки всього).
func get_ammo() -> Vector2i:
	if not is_ranged():
		return Vector2i.ZERO
	return Vector2i(_ammo, magazine_size())

## Розмір магазина з урахуванням здібності "Розширений магазин".
func magazine_size() -> int:
	return maxi(1, int(round(weapon_def.magazine * _magazine_factor)))

## Скільки лишилось перезаряджатись і скільки вона триває.
func get_reload() -> Vector2:
	return Vector2(_reload_left, weapon_def.reload_time * _reload_factor if is_ranged() else 0.0)

func reload() -> void:
	if not is_ranged() or _reload_left > 0.0 or _ammo >= magazine_size():
		return
	_reload_left = weapon_def.reload_time * _reload_factor / maxf(attack_speed(), 0.1)
	_fire("KickShot", true)

## Постріл, якщо ствол готовий: не в перезарядці, минула затримка після
## попереднього і є набої.
func _try_shoot() -> void:
	if _roll_left > 0.0 or _reload_left > 0.0 or _fire_left > 0.0:
		return
	if _ammo <= 0:
		reload()
		return
	_shoot()

func _shoot() -> void:
	_ammo -= 1
	_fire_left = weapon_def.fire_interval * _fire_rate_factor / maxf(attack_speed(), 0.1)
	_combat_left = COMBAT_MEMORY
	_since_attack = 0.0
	_refresh_target()

	var aim := _aim_angle()
	var direction := Vector3(sin(aim), 0.0, cos(aim))
	if _target != null and is_instance_valid(_target):
		# Ціль трохи вища за підлогу — цілимось у груди.
		direction = (_target.global_position + Vector3.UP * 0.9 - _muzzle_position()).normalized()
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	_fire("SlashShot", moving)

	var parent := get_parent()
	var muzzle := _muzzle_position()
	var shots := maxi(weapon_def.bullets_per_shot, 1) + _bullets_extra
	for i in shots:
		var spread := deg_to_rad(weapon_def.bullet_spread_deg) * _spread_factor
		# Додаткові кулі йдуть трохи вбік, щоб їх було видно як чергу.
		var offset := 0.0 if shots == 1 else lerpf(-0.05, 0.05, float(i) / float(shots - 1))
		var shot_direction := direction.rotated(Vector3.UP, randf_range(-spread, spread) + offset)
		var bullet := PlayerProjectile.create(self, 1.0, weapon_def.color, 1.2)
		bullet.pierce = _bullet_pierce
		bullet.explosion_radius = 1.9 if _explosive_bullets > 0 else 0.0
		bullet.explosion_damage = 0.35 * _explosive_bullets
		parent.add_child(bullet)
		bullet.launch(muzzle, shot_direction, weapon_def.bullet_speed)
	CombatVfx.muzzle_flash(parent, muzzle, direction, weapon_def.color)
	_shake_camera(0.03)
	if _ammo <= 0:
		reload()

## Кінчик ствола: беремо з моделі зброї в руці, а якщо її немає —
## приблизно від плеча героя.
func _muzzle_position(offhand: bool = false) -> Vector3:
	if _weapon_node != null and is_instance_valid(_weapon_node):
		var node := _weapon_node
		# Друга така сама зброя в лівій руці (парні карти, кинджали).
		if offhand and _weapon_node.has_meta(&"offhand"):
			var other: Node3D = _weapon_node.get_meta(&"offhand")
			if is_instance_valid(other):
				node = other
		return node.global_transform * weapon_def.muzzle_offset
	return global_position + Vector3.UP * 1.2 + _facing_vector() * 0.5

func _update_ranged(delta: float) -> void:
	if not is_ranged():
		return
	_fire_left = maxf(_fire_left - delta, 0.0)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_ammo = magazine_size()
	# Утримання кнопки — вогонь чергою, поки є набої.
	elif _attack_held and _fire_left <= 0.0:
		_try_shoot()

# --- чари ---

## Чари, якщо посох готовий: не в перекаті й минула затримка.
func _try_cast() -> void:
	if _roll_left > 0.0 or _cast_left > 0.0 or _cast_pending_left >= 0.0:
		return
	_cast_left = weapon_def.cast_interval * _cast_rate_factor / maxf(attack_speed(), 0.1)
	_cast_count += 1
	# Снаряд злітає з посоха в мить помаху — трохи згодом. Зі справжнім
	# кастом — точно тоді, коли рука викидає чари (непарний каст — перший
	# слот, парний — другий).
	var release := 0.12
	var casts := _cast_moves()
	if not casts.is_empty():
		var move: Array = casts[(0 if _cast_count % 2 == 1 else 1) % casts.size()]
		release = float(move[1]) / float(move[2])
	_cast_pending_left = release / maxf(attack_speed(), 0.1)
	_combat_left = COMBAT_MEMORY
	_since_attack = 0.0
	_refresh_target()
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	_fire("SlashShot" if _cast_count % 2 == 1 else "SlashFastShot", moving)

func _release_spell() -> void:
	# Карти летять із тієї руки, що кидає: парні ходи — з лівої.
	var origin := _muzzle_position(weapon_def.spell == "cards" and _cast_count % 2 == 0)
	var aim := _aim_angle()
	var direction := Vector3(sin(aim), 0.0, cos(aim))
	var target: Enemy3D = null
	if _target != null and is_instance_valid(_target) and _target.is_alive():
		target = _target
		direction = (_target.global_position + Vector3.UP * _target.target_height * 0.55 - origin).normalized()
	Spells3D.cast(self, weapon_def, origin, direction, target)
	_shake_camera(0.02)

func _update_casting(delta: float) -> void:
	if not is_caster():
		return
	_cast_left = maxf(_cast_left - delta, 0.0)
	if _cast_pending_left >= 0.0:
		_cast_pending_left -= delta
		if _cast_pending_left < 0.0 and not _dead:
			_release_spell()
	# Утримання кнопки — чари раз за разом, поки кнопку не відпустять.
	elif _attack_held and _cast_left <= 0.0:
		_try_cast()

## Звідки летять чари — з "голови" посоха.
func spell_origin() -> Vector3:
	return _muzzle_position()

func spell_extra() -> int:
	return _spell_extra

func spell_pierce() -> int:
	return _spell_pierce

func spell_power() -> float:
	return _spell_power

func ring_power() -> float:
	return _ring_power

func phoenix_bonus() -> float:
	return _phoenix_bonus

func nova_power() -> float:
	return _nova_power

## Кожен який удар підриває рунний заряд Руновода.
func rune_charge_hits() -> int:
	return _charge_hits

## Утримання кнопки удару: серія ударів, поки є ціль.
func set_attack_held(held: bool) -> void:
	_attack_held = held
	if held:
		attack()

func dodge() -> void:
	if _dead or _rooted_left > 0.0 or _knock_left > 0.0 or _dodge_cooldown_left > 0.0 or _roll_left > 0.0:
		return
	var direction := _get_world_direction()
	if direction.length() < 0.1:
		# Стоїть на місці — перекат назад, геть від ворога.
		direction = -_facing_vector()
	_roll_direction = direction.normalized()
	_roll_left = DODGE_TIME
	_invulnerable_left = maxf(_invulnerable_left, DODGE_INVULNERABLE)
	_roll_guard_left = DODGE_INVULNERABLE
	_roll_origin = global_position
	_roll_started_msec = Time.get_ticks_msec()
	_perfect_this_roll = false
	_dodge_cooldown_left = DODGE_COOLDOWN * _dodge_cooldown_factor
	# Перекат скасовує удар: у небезпеці гравець має реагувати миттєво.
	_attack_step = -1
	_lunge_left = 0.0
	_abort_attacks()
	_facing_angle = atan2(_roll_direction.x, _roll_direction.z)
	model.rotation.y = _facing_angle
	_fire("RollShot")
	CombatVfx.shockwave(get_parent(), global_position, 1.1, Color(0.85, 0.8, 0.7, 0.7), 0.3)

## Здібності героя — для кнопок на екрані.
func get_skills() -> Array[HeroSkill3D]:
	return _skills

## Натиснули кнопку здібності (0 — перша, 1 — друга).
func use_skill(index: int = 0) -> void:
	if _dead or _knock_left > 0.0 or _roll_left > 0.0 or index < 0 or index >= _skills.size():
		return
	# Спершу скидаємо удар, який герой робив, і лише потім застосовуємо
	# здібність: вона сама може задати рух (ривок люті), і зачищати його
	# після цього не можна.
	var skill := _skills[index]
	_attack_step = -1
	_lunge_left = 0.0
	_abort_attacks()
	if not skill.try_use(self):
		return
	_combat_left = COMBAT_MEMORY
	if not play_skill_move(skill.id):
		_fire("SlashFastShot")

func get_dodge_cooldown() -> Vector2:
	return Vector2(_dodge_cooldown_left, DODGE_COOLDOWN * _dodge_cooldown_factor)

# --- що здібності походу віддають бою й умінням ---

func skill_cooldown_factor() -> float:
	return _skill_cooldown_factor

func rage_gain_factor() -> float:
	return _rage_gain_factor

func dash_power() -> float:
	return _dash_power

func whirl_power() -> float:
	return _whirl_power

func mark_bonus() -> float:
	return _mark_bonus

func smoke_bonus() -> float:
	return _smoke_bonus

## Вороги біля точки — потрібно розривним кулям, які б'ють по площі.
func enemies_near(position: Vector3, radius: float) -> Array[Enemy3D]:
	var result: Array[Enemy3D] = []
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.is_alive() and enemy.global_position.distance_to(position) <= radius:
			result.append(enemy)
	return result

# --- те, чим користуються здібності ---

## Оберт моделі навколо себе (вихор, каст нови).
func spin_model(time: float) -> void:
	_spin_left = time
	_spin_total = maxf(time, 0.01)
	_spin_turns = true

## Касти чаклуна під чари в руках: [[анімація, мить викиду, швидкість], ...].
func _cast_moves() -> Array:
	if weapon_def == null or hero_def == null:
		return []
	var casts := WeaponAnims.cast_moves(hero_def.id, weapon_def.style_3d, weapon_def.spell)
	return casts.filter(func(move: Array) -> bool: return _anim_overrides.has(move[0]))

## Рух здібності (чаклуни): грає в слоті Вихору. false — свого руху немає.
func play_skill_move(skill_id: StringName) -> bool:
	if weapon_def == null or hero_def == null:
		return false
	var short_name := WeaponAnims.skill_move(hero_def.id, weapon_def.style_3d, skill_id)
	if short_name == "" or not _anim_overrides.has(short_name):
		return false
	var node := (animation_tree.tree_root as AnimationNodeBlendTree).get_node(&"WhirlAnim") as AnimationNodeAnimation
	node.animation = _anim_overrides[short_name]
	animation_tree.set("parameters/WhirlScale/scale", 1.3)
	# Оберт моделі кодом (Рунна нова) не потрібен — рух уже в кліпі.
	_spin_left = 0.0
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	_fire("WhirlShot", moving)
	return true

## Вихор: якщо в зброї є справжня анімація оберту — граємо її (оберт у
## самому кліпі, модель кодом не крутимо); інакше — старий оберт моделі.
func play_whirl(time: float) -> void:
	if not _anim_overrides.has("W_whirl"):
		spin_model(time)
		return
	var player: AnimationPlayer = animation_tree.get_node(animation_tree.anim_player)
	var length := player.get_animation(_anim_overrides["W_whirl"]).length
	((animation_tree.tree_root as AnimationNodeBlendTree).get_node(&"WhirlAnim") as AnimationNodeAnimation).animation = _anim_overrides["W_whirl"]
	var duration := time + 0.35
	_attack_step = -1
	_attack_queued = false
	_abort_attacks()
	_spin_left = duration
	_spin_total = maxf(duration, 0.01)
	_spin_turns = false
	animation_tree.set("parameters/WhirlScale/scale", length / duration)
	_fire("WhirlShot")

## Ривок люті: анімація ривка з ударом у кінці; strike_in — за скільки
## секунд ривок долетить (анімацію підганяємо, щоб удар збігся).
func play_dash_strike(strike_in: float) -> void:
	_attack_step = -1
	_attack_queued = false
	_abort_attacks()
	animation_tree.set("parameters/DashScale/scale", clampf(_dash_strike_at / maxf(strike_in, 0.05), 0.6, 3.0))
	_fire("DashShot")

## Одразу повернутись у бік direction (ривок у ціль).
func face_direction(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.01:
		return
	_facing_angle = atan2(flat.x, flat.z)
	model.rotation.y = _facing_angle

## Ривок у заданий бік — ним користується "Ривок Люті".
func dash(direction: Vector3, speed: float, time: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.01:
		flat = _facing_vector()
	_lunge_velocity = flat.normalized() * speed
	_lunge_left = time

func add_shrine_buff(kind: StringName, seconds: float) -> void:
	_shrine_kind = kind
	_shrine_left = seconds
	if kind == &"haste":
		add_attack_speed(SHRINE_HASTE_ATTACK, seconds)

## Сила святилища, що діє зараз: {kind, left}, або порожньо.
func get_shrine_buff() -> Dictionary:
	if _shrine_left <= 0.0:
		return {}
	return {"kind": _shrine_kind, "left": _shrine_left}

func _has_shrine(kind: StringName) -> bool:
	return _shrine_left > 0.0 and _shrine_kind == kind

## Живі вороги в радіусі, на яких можна навестись (без вибухових бочок) —
## для самонавідних чар і вмінь, що самі обирають ціль.
func aim_targets_in_radius(radius: float, require_sight: bool = true) -> Array[Enemy3D]:
	var result: Array[Enemy3D] = []
	for enemy in enemies_in_radius(radius, require_sight):
		if enemy.is_aim_target():
			result.append(enemy)
	return result

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
	return _facing_angle

func _unhandled_input(event: InputEvent) -> void:
	if not combat_input_enabled or event.is_echo():
		return
	if event.is_action_pressed("attack"):
		attack()
	elif event.is_action_pressed("dodge"):
		dodge()
	elif event.is_action_pressed("skill"):
		use_skill(0)
	elif event.is_action_pressed("skill_2"):
		use_skill(1)

# --- кадр фізики ---

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if _dead:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECELERATION * delta)
		velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
		move_and_slide()
		return

	_retarget_left -= delta
	if _retarget_left <= 0.0:
		_retarget_left = RETARGET_INTERVAL
		_refresh_target()

	var direction := _get_world_direction()
	_update_attack(delta)
	_update_ranged(delta)
	_update_casting(delta)
	_tick_skills(delta)
	# Наступний удар — лише після перепочинку: натиснутий заздалегідь чи
	# кнопка утримується (тоді — коли є кого бити, щоб герой не махав
	# зброєю в порожнечу).
	if _attack_step < 0 and _roll_left <= 0.0 and _spin_left <= 0.0 and _attack_cooldown_left <= 0.0 \
			and not is_ranged() and not is_caster() and (_attack_queued or (_attack_held and _target != null)):
		_start_attack()
	_update_velocity(direction, delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if _regen_per_second > 0.0 and current_hp < max_hp:
		current_hp = minf(current_hp + _regen_per_second * delta, max_hp)
		_update_health_bar()
		health_changed.emit(current_hp, max_hp)

	move_and_slide()
	_update_facing(direction, delta)
	_update_animation(delta)
	_update_target_marker()

func _tick_timers(delta: float) -> void:
	_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_combat_left = maxf(_combat_left - delta, 0.0)
	_attack_speed_left = maxf(_attack_speed_left - delta, 0.0)
	_shrine_left = maxf(_shrine_left - delta, 0.0)
	_roll_guard_left = maxf(_roll_guard_left - delta, 0.0)
	_perfect_crit_left = maxf(_perfect_crit_left - delta, 0.0)
	_bonus_damage_left = maxf(_bonus_damage_left - delta, 0.0)
	if _chill_left > 0.0:
		_chill_left -= delta
		if _chill_left <= 0.0:
			_apply_attack_speed()
			if _chill_marker != null:
				_chill_marker.visible = false
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_factor = 1.0
			if _slow_marker != null:
				_slow_marker.visible = false
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_since_attack += delta
	if _spin_left > 0.0:
		_spin_left -= delta
	if _concealed_left > 0.0:
		_concealed_left = maxf(_concealed_left - delta, 0.0)
		if _concealed_left <= 0.0:
			_set_model_transparency(0.0)
	_roll_left = maxf(_roll_left - delta, 0.0)
	if _attack_step < 0:
		_combo_expire = maxf(_combo_expire - delta, 0.0)

func _update_velocity(direction: Vector3, delta: float) -> void:
	velocity.x -= _pull_applied.x
	velocity.z -= _pull_applied.z
	_pull_applied = Vector3.ZERO
	if _rooted_left > 0.0:
		_rooted_left -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if _rooted_left <= 0.0 and _root_marker != null:
			_root_marker.visible = false
		return
	if _knock_left > 0.0:
		_knock_left -= delta
		if _knock_left <= 0.0 and _stun_stars != null:
			_stun_stars.visible = false
		_knock_velocity = _knock_velocity.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)
		velocity.x = _knock_velocity.x
		velocity.z = _knock_velocity.z
		return
	# Кілька вирів разом тягнуть не сильніше за MAX_PULL_SPEED — вирватись
	# можна завжди.
	var pull := _pull_velocity.limit_length(MAX_PULL_SPEED)
	_pull_velocity = Vector3.ZERO
	if _roll_left > 0.0:
		# Ривок швидкий на початку й гасне під кінець.
		var speed := DODGE_SPEED * (0.45 + 0.55 * _roll_left / DODGE_TIME)
		velocity.x = _roll_direction.x * speed
		velocity.z = _roll_direction.z * speed
		return
	if _lunge_left > 0.0:
		_lunge_left -= delta
		velocity.x = _lunge_velocity.x
		velocity.z = _lunge_velocity.z
		if _lunge_left <= 0.0:
			# Ривок скінчився — гасимо надлишок швидкості, інакше героя
			# несло б за інерцією ще кілька метрів.
			var flat := Vector2(velocity.x, velocity.z).limit_length(RUN_SPEED)
			velocity.x = flat.x
			velocity.z = flat.y
		return

	var factor := 1.0 + _speed_bonus + (_concealed_speed if _concealed_left > 0.0 else 0.0) \
		+ (SHRINE_HASTE_SPEED if _has_shrine(&"haste") else 0.0)
	if _slow_left > 0.0:
		factor *= _slow_factor
	if _is_facing_target() and direction.length() > 0.05:
		# Задки й убік — повільніше, ніж уперед: так відчувається, що герой
		# тримає оборону, а не тікає.
		if _facing_vector().dot(direction.normalized()) < 0.3:
			factor *= BACKPEDAL_FACTOR
	if _attack_step >= 0 or _spin_left > 0.0:
		factor *= ATTACK_MOVE_FACTOR

	var target_velocity := direction.normalized() * RUN_SPEED * factor * clampf(direction.length(), 0.0, 1.0)
	var rate := ACCELERATION if direction.length() > 0.05 else DECELERATION
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
	# Тягнення вихору додається зверху лише на цей кадр: герой і далі сам
	# керує рухом, але його зносить, якщо не тікати. Перекат і ривок (return
	# вище) від нього вільні — і тягнення за цей час не накопичується.
	velocity.x += pull.x
	velocity.z += pull.z
	_pull_applied = Vector3(pull.x, 0.0, pull.z)

## Вир Безодні (мега-боса) зносить героя до центру: step — швидкість (м/с)
## цього кадру; небезпека викликає щокадру, кілька вирів додаються.
func apply_pull(step: Vector3) -> void:
	_pull_velocity += step

## Напрямок руху у світових координатах: джойстик дає напрямок відносно
## ЕКРАНА, а рухатись треба відносно камери.
func _get_world_direction() -> Vector3:
	var input := _input_direction
	# "Вгору" на клавіатурі = вперед від камери.
	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	if keyboard != Vector2.ZERO:
		input = keyboard
	if input == Vector2.ZERO:
		return Vector3.ZERO
	# "Вперед" для камери — це -Z (так влаштований Godot).
	var camera_yaw := _get_camera_yaw()
	var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(-forward.z, 0.0, forward.x)
	return (right * input.x + forward * input.y) * input.length()

func _get_camera_yaw() -> float:
	var camera := get_viewport().get_camera_3d()
	return 0.0 if camera == null else camera.global_rotation.y

func get_move_yaw() -> float:
	return atan2(velocity.x, velocity.z)

func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.6

func _facing_vector() -> Vector3:
	return Vector3(sin(_facing_angle), 0.0, cos(_facing_angle))

# --- ціль ---

## Тримаємо поточну ціль, поки вона жива й поруч; інакше шукаємо нову:
## найближчу, з перевагою тим, що попереду, і тільки ту, яку видно
## (не крізь стіну).
func _refresh_target() -> void:
	if _target != null:
		if not is_instance_valid(_target) or not _target.is_alive() \
				or _flat_distance(_target) > LOCK_BREAK_RANGE:
			_target = null
	var best: Enemy3D = null
	var best_score := INF
	var forward := _facing_vector()
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if not enemy.is_aim_target():
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > LOCK_RANGE:
			continue
		var in_front := maxf(forward.dot(offset / maxf(distance, 0.01)), 0.0)
		var score := distance - in_front * 1.5
		if score < best_score and _can_see(enemy):
			best = enemy
			best_score = score
	if best == null:
		return
	# Перемикаємось лише на помітно кращу ціль, щоб приціл не стрибав.
	if _target == null or (best != _target and best_score < _target_score() - 1.2):
		_target = best

func _target_score() -> float:
	var offset := _target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	return distance - maxf(_facing_vector().dot(offset / maxf(distance, 0.01)), 0.0) * 1.5

func _flat_distance(node: Node3D) -> float:
	var offset := node.global_position - global_position
	offset.y = 0.0
	return offset.length()

func _can_see(node: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.1, node.global_position + Vector3.UP * 1.0)
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Обличчям до ворога:
##  - під час удару — завжди;
##  - одразу після удару — навіть на відході (б'єш і відступаєш);
##  - у бою поруч із ворогом, поки не тікаєш від нього.
## Тікаєш без ударів або відбіг далі за ENGAGE_RANGE — герой
## розвертається й біжить.
func _is_facing_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if _attack_step >= 0:
		return true
	var distance := _flat_distance(_target)
	if _since_attack < RETREAT_GUARD_TIME and distance < LOCK_BREAK_RANGE:
		return true
	if distance >= ENGAGE_RANGE or _combat_left <= 0.0:
		return false
	var direction := _get_world_direction()
	if direction.length() > 0.3:
		var to_target := (_target.global_position - global_position).normalized()
		if direction.normalized().dot(Vector3(to_target.x, 0.0, to_target.z)) < -0.4:
			return false
	return true

## Червоне кільце під ціллю — гравець бачить, кого зараз ударить.
func _update_target_marker() -> void:
	var has_target := _target != null and is_instance_valid(_target)
	if not has_target:
		if _target_marker != null:
			_target_marker.visible = false
		return
	if _target_marker == null:
		_target_marker = CombatVfx.make_ground_marker(Color(1.0, 0.35, 0.28, 0.9), 0.75)
		get_parent().add_child(_target_marker)
	_target_marker.visible = true
	_target_marker.global_position = _target.global_position + Vector3(0, 0.05, 0)

# --- удари ---

func _start_attack() -> void:
	var combo := _combo()
	var step_index := (_combo_index if _combo_expire > 0.0 else 0) % combo.size()
	var step: Dictionary = combo[step_index]
	_attack_step = step_index
	_combo_index = (step_index + 1) % combo.size()
	combo_step.emit(step_index, combo.size())
	_attack_time = 0.0
	_attack_hit_done = false
	_attack_vfx_done = false
	_attack_queued = false
	_extra_hit = 0
	_combat_left = COMBAT_MEMORY
	_since_attack = 0.0
	_refresh_target()

	# Лицем до цілі герой довертається сам (швидко, але плавно — див.
	# _update_facing), а удар однаково йде в ціль: цілитись не треба.
	if _target != null:
		var offset := _target.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		# Ціль трохи далі за замах — спокійний крок до неї. Лише на першому
		# ударі серії: далі ворог і так поруч, а кидатись за ним після
		# кожного удару — це й були "різкі рухи".
		var reach: float = _reach(step)
		if step_index == 0 and distance > reach * 0.9 and distance < reach + LUNGE_REACH_EXTRA:
			var travel := minf(distance - reach * 0.75, LUNGE_MAX_DISTANCE)
			_lunge_velocity = offset.normalized() * LUNGE_SPEED
			_lunge_left = travel / LUNGE_SPEED

	# Кругова сокира: герой обертається разом із ударом.
	if step.has("spin"):
		spin_model(float(step.spin) / maxf(_attack_speed, 0.1))
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	_fire(step.shot, moving)

func _update_attack(delta: float) -> void:
	if _attack_step < 0:
		return
	_attack_time += delta * _attack_speed * _chill()
	var step: Dictionary = _combo()[_attack_step]
	if not _attack_vfx_done and _attack_time >= step.hit_time - 0.07:
		_attack_vfx_done = true
		_attack_vfx(step, bool(step.get("reverse", false)))
	if not _attack_hit_done and _attack_time >= step.hit_time:
		_attack_hit_done = true
		_apply_hit(step)
	# Парні клинки: та сама ланка б'є ще раз — другим клинком.
	var extra: Array = step.get("hits", [])
	if _attack_hit_done and _extra_hit < extra.size() and _attack_time >= float(extra[_extra_hit]):
		_extra_hit += 1
		_attack_vfx(step, not bool(step.get("reverse", false)))
		_apply_hit(step)
	if _attack_time >= step.recover:
		_attack_step = -1
		# Перепочинок після удару: наступний почнеться не одразу, а важкий
		# завершальний удар серії дає довшу паузу.
		_attack_cooldown_left = float(step.get("pause", 0.0)) / maxf(attack_speed(), 0.1)
		_combo_expire = COMBO_WINDOW + _attack_cooldown_left

## Слід удару за його формою: дуга, повне коло довкола героя або прямий
## укол уперед.
func _attack_vfx(step: Dictionary, reverse: bool) -> void:
	var color := HEAVY_COLOR if step.heavy else SLASH_COLOR
	var origin := global_position + Vector3.UP * 1.0
	# Розсіч: легкий удар — тонкий швидкий серп, важкий — широкий, фініш
	# серії ще й лишає на підлозі світний шрам.
	var width := 1.3 if step.heavy else 0.85
	var scar := bool(step.get("finisher", false))
	match String(step.get("shape", "arc")):
		"circle":
			CombatVfx.slash(get_parent(), origin, _aim_angle(), _reach(step) + 0.2, 359.0, color,
				reverse, 0.0, 0.34, width, scar)
		"line":
			# Тризуб лишає три вітрові смуги вістрів, решта держакової — одну.
			var prongs := 3 if weapon_def != null and weapon_def.id == &"harpoon_glaive" else 1
			CombatVfx.thrust(get_parent(), origin, _aim_angle(), _reach(step) + 0.3, color, prongs)
		_:
			CombatVfx.slash(get_parent(), origin, _aim_angle(), _reach(step) + 0.2, _arc(step), color,
				reverse, float(step.get("tilt", 0.0)), 0.26 if step.heavy else 0.22, width, scar)

## Шкода всім ворогам у дузі перед героєм. Стіна захищає: крізь неї
## меч не дістає.
## Дальність і ширина замаху залежать від зброї: сокира б'є широко,
## глефа — далеко й вузько.
func _reach(step: Dictionary) -> float:
	if weapon_def == null:
		return step.reach + _reach_bonus
	return step.reach * weapon_def.reach_3d / 2.9 + _reach_bonus

func _arc(step: Dictionary) -> float:
	if weapon_def == null:
		return step.arc * _arc_factor
	return clampf(step.arc * weapon_def.arc_3d / 150.0 * _arc_factor, 40.0, 359.0)

func _apply_hit(step: Dictionary) -> void:
	var aim := _aim_angle()
	var forward := Vector3(sin(aim), 0.0, cos(aim))
	var side := Vector3(forward.z, 0.0, -forward.x)
	var shape: String = step.get("shape", "arc")
	var reach := _reach(step)
	var half_arc := deg_to_rad(_arc(step)) * 0.5
	var half_width: float = float(step.get("width", 1.2)) * 0.5
	var knockback: float = step.knockback * (weapon_def.knockback_mult_3d if weapon_def != null else 1.0)
	var hit: Array[Enemy3D] = []
	for enemy: Enemy3D in get_tree().get_nodes_in_group(&"enemies"):
		if not enemy.is_alive():
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		match shape:
			"circle":
				if distance > reach + 0.5:
					continue
			"line":
				# Укол: вузька смуга вперед — дістає всіх, хто в ній стоїть.
				var along := offset.dot(forward)
				if along < -0.3 or along > reach + 0.4 or absf(offset.dot(side)) > half_width + 0.3:
					continue
			_:
				if distance > reach + 0.5:
					continue
				if distance > 0.4 and forward.angle_to(offset / distance) > half_arc:
					continue
		if not _can_see(enemy):
			continue
		var crit := deal_damage(enemy, step.damage, offset.normalized() * knockback, step.heavy)
		# Іскри — свої для кожної ланки (не більше чотирьох ворогів за удар).
		if hit.size() < 4:
			CombatVfx.hit_spark(get_parent(), enemy.global_position + Vector3.UP * enemy.target_height * 0.55,
				offset, _spark_kind(step), crit)
		if step.has("stun"):
			enemy.stun(float(step.stun))
		hit.append(enemy)
	if hit.is_empty():
		return
	if step.has("burst"):
		_burst(step, hit)
	if step.get("finisher", false):
		# Фініш серії: довша зупинка кадру й відчутний трус.
		CombatVfx.hitstop(get_tree(), 0.09)
		_shake_camera(0.16)
	else:
		_feel_hit(step.heavy)

## Які іскри від цієї ланки: свої ("spark") або за формою удару.
func _spark_kind(step: Dictionary) -> String:
	if step.has("spark"):
		return String(step.spark)
	if String(step.get("shape", "arc")) == "circle":
		return "spin"
	return "sweep" if step.heavy else "slash"

## Удар зачіпає сусідів цілі (кинджали, завершальний удар тесака) —
## невеликою часткою шкоди. Це зброя, не магія: кинджали — віхола коротких
## порізів довкола цілі, тесак — гупає об землю (тріщини й пил).
func _burst(step: Dictionary, hit: Array[Enemy3D]) -> void:
	var center_enemy: Enemy3D = hit[0]
	if _target != null and is_instance_valid(_target) and hit.has(_target):
		center_enemy = _target
	var center := center_enemy.global_position
	var radius: float = float(step.burst[0])
	var style: String = weapon_def.style_3d if weapon_def != null else "sword"
	if style == "cleaver":
		CombatVfx.ground_hit(get_parent(), center, radius * 0.7)
	else:
		CombatVfx.slash(get_parent(), center + Vector3.UP * 0.9, randf() * TAU, radius * 0.75, 359.0,
			SLASH_COLOR, randf() < 0.5, 0.0, 0.16)
	for enemy: Enemy3D in enemies_near(center, radius):
		if hit.has(enemy):
			continue
		var push := enemy.global_position - center
		push.y = 0.0
		deal_damage(enemy, float(step.burst[1]), push.normalized() * 1.2, false)

## Здібності й пасивка живуть своїм життям: перезарядка, накопичення
## люті, тик вогняного кола.
func _tick_skills(delta: float) -> void:
	for skill: HeroSkill3D in _skills:
		skill.tick(self, delta)
	if passive != null:
		passive.tick(self, delta)

## Єдине місце, де героєві рахується шкода: сюди приходять і звичайні
## удари, і здібності, і пасивки. Тут же діють мітка ворога, димова
## завіса й критичні удари.
## source — хто вдарив: &"weapon" (зброя), id здібності чи пасивки. Для
## екрана підсумків данжу (damage_by_source).
## Повертає, чи був удар критичним.
func deal_damage(enemy: Enemy3D, multiplier: float, knockback: Vector3, heavy: bool,
		source: StringName = &"weapon") -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return false
	var hp_before := enemy.current_hp
	var crit := randf() < _crit_chance or _perfect_crit_left > 0.0
	var amount := _damage * multiplier * (CRIT_MULTIPLIER if crit else 1.0)
	if _bonus_damage_left > 0.0:
		amount *= _bonus_damage
	if _concealed_left > 0.0:
		amount *= _concealed_damage
	if _has_shrine(&"fury"):
		amount *= SHRINE_FURY_DAMAGE
	if passive != null:
		amount = passive.modify_damage(self, enemy, amount)
	enemy.last_hit_source = source
	enemy.take_damage(amount, knockback * _knockback_factor, crit, heavy)
	# Скільки здоров'я ворог справді втратив (щит, тотем і добивання
	# вже враховані).
	var dealt := maxf(hp_before - enemy.current_hp, 0.0)
	damage_by_source[source] = float(damage_by_source.get(source, 0.0)) + dealt
	hit_landed.emit(amount, crit)
	# Вампіризм: частина завданої шкоди повертається здоров'ям.
	if _lifesteal > 0.0:
		heal(amount * _lifesteal)
	if passive == null:
		return crit
	passive.on_hit(self, enemy, amount, heavy)
	if not enemy.is_alive():
		passive.on_kill(self, enemy)
	return crit

## Лише сильний удар (ногою) на мить пригальмовує гру й ледь трусить
## камеру. Звичайні помахи — без цього: на кожному ударі це
## сприймалось як ривки.
func _feel_hit(heavy: bool) -> void:
	if heavy:
		CombatVfx.hitstop(get_tree(), 0.045)
		_shake_camera(0.07)

## Куди йде удар: у ціль, якщо вона є, інакше — куди дивиться герой.
## Герой довертається до цілі плавно, а удар не має промахуватись через
## те, що поворот ще не завершився.
func _aim_angle() -> float:
	if _target != null and is_instance_valid(_target) and _target.is_alive():
		var offset := _target.global_position - global_position
		if Vector2(offset.x, offset.z).length() > 0.05:
			return atan2(offset.x, offset.z)
	return _facing_angle

## Трусонути камеру — цим користуються й здібності.
func shake_camera(strength: float) -> void:
	_shake_camera(strength)

func _shake_camera(strength: float) -> void:
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(strength)

# --- поворот і анімація ---

func _update_facing(direction: Vector3, delta: float) -> void:
	if _roll_left > 0.0:
		return   # напрямок перекату задано на старті
	if _spin_left > 0.0 and _spin_turns:
		# Вихор — повний оберт навколо себе.
		_facing_angle = wrapf(_facing_angle + TAU / _spin_total * delta, -PI, PI)
	elif _spin_left > 0.0:
		pass   # оберт є в самій анімації — напрямок тримаємо
	elif _is_facing_target():
		var offset := _target.global_position - global_position
		if Vector2(offset.x, offset.z).length() > 0.05:
			_facing_angle = rotate_toward(_facing_angle, atan2(offset.x, offset.z), COMBAT_TURN_SPEED * delta)
	elif direction.length() > 0.05:
		_facing_angle = rotate_toward(_facing_angle, atan2(direction.x, direction.z), ROTATION_SPEED * delta)
	model.rotation.y = _facing_angle

## Швидкість у системі координат героя -> положення в просторі рухів:
## вперед — біг, назад — біг задки, вбік — біг боком. Проміжні
## напрямки AnimationTree змішує сам.
func _update_animation(delta: float) -> void:
	var forward := _facing_vector()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if _roll_left > 0.0:
		flat = Vector3.ZERO
	# right — права рука героя: коли він дивиться на +Z, це -X світу.
	var wanted := Vector2(flat.dot(right), flat.dot(forward)) / RUN_SPEED
	_blend_position = _blend_position.lerp(wanted.limit_length(1.0), clampf(12.0 * delta, 0.0, 1.0))
	animation_tree.set("parameters/Move/blend_position", _blend_position)

# --- здоров'я ---

## Повертає false, якщо удар не пройшов (перекат, мить після удару).
func take_damage(amount: float) -> bool:
	if _dead:
		return false
	if _invulnerable_left > 0.0:
		if _roll_guard_left > 0.0 and not _perfect_this_roll:
			_on_perfect_dodge()
		return false
	amount *= _damage_taken_factor
	if _has_shrine(&"guard"):
		amount *= SHRINE_GUARD_FACTOR
	current_hp = maxf(current_hp - amount, 0.0)
	_invulnerable_left = HURT_INVULNERABLE
	_combat_left = COMBAT_MEMORY
	if passive != null:
		passive.on_damage_taken(self, amount)
		# Фенікс: смертельний удар не вбиває, а піднімає героя знову.
		if current_hp <= 0.0 and passive.on_lethal(self):
			_update_health_bar()
			health_changed.emit(current_hp, max_hp)
			return true
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)
	CombatVfx.flash_model(model, Color(1.0, 0.25, 0.2), 0.12)
	_shake_camera(0.06)
	if _attack_step < 0 and _roll_left <= 0.0:
		_fire("HitShot")
	if current_hp <= 0.0:
		_die()
	return true

func _on_perfect_dodge() -> void:
	_perfect_this_roll = true
	_perfect_crit_left = PERFECT_CRIT_TIME
	_dodge_cooldown_left = 0.0
	CombatVfx.hitstop(get_tree(), PERFECT_SLOWMO, PERFECT_SLOWMO_SCALE)
	CombatVfx.shockwave(get_parent(), global_position, 2.2, PERFECT_COLOR, 0.45)
	perfect_dodge.emit()

## Звідки герой почав перекат, якщо це було щойно (не давніше за window
## секунд) і ідеальний перекат за нього ще не зараховано; інакше INF.
## Ворог перевіряє: чи накрив би його удар ту точку — тоді герой
## вискочив із червоної зони в останню мить.
func late_dodge_origin(window: float) -> Vector3:
	if _perfect_this_roll or _roll_origin == Vector3.INF:
		return Vector3.INF
	if Time.get_ticks_msec() - _roll_started_msec > int(window * 1000.0):
		return Vector3.INF
	return _roll_origin

func register_perfect_dodge() -> void:
	if not _perfect_this_roll and not _dead:
		_on_perfect_dodge()

## Чи діють зараз гарантовані крити після ідеального перекату.
func has_perfect_crits() -> bool:
	return _perfect_crit_left > 0.0

## Куди дивиться герой (на підлозі) — ворог, що мерехтить, стає за спину.
func get_facing() -> Vector3:
	return _facing_vector()

## Павутина: герой повільніший кілька секунд, під ним біле коло.
## Перекат не сповільнюється — ним і вириваються.
func apply_slow(factor: float, seconds: float) -> void:
	_slow_factor = minf(_slow_factor, factor) if _slow_left > 0.0 else factor
	_slow_left = maxf(_slow_left, seconds)
	CombatVfx.flash_model(model, Color(0.9, 0.95, 1.0), 0.15)
	if _slow_marker == null:
		_slow_marker = CombatVfx.make_ground_marker(Color(0.92, 0.92, 1.0, 0.7), 0.8)
		CombatVfx.set_param(_slow_marker, &"progress", 1.0)
		_slow_marker.position.y = 0.05
		add_child(_slow_marker)
	_slow_marker.visible = true

func is_slowed() -> bool:
	return _slow_left > 0.0

## Тимчасово сильніші удари (серія ударів у данжі).
func add_damage_buff(multiplier: float, seconds: float) -> void:
	_bonus_damage = multiplier
	_bonus_damage_left = seconds

func _die() -> void:
	_dead = true
	_attack_step = -1
	_target = null
	if _target_marker != null:
		_target_marker.visible = false
	animation_tree.set("parameters/Dead/blend_amount", 1.0)
	died.emit()

## Збили з ніг: відкидає (push, м/с, гасне) і seconds секунд герой не
## керує рухом, не б'є й не котиться. Перекат, що вже йде, рятує.
func knock_down(push: Vector3, seconds: float) -> void:
	if _dead or _roll_left > 0.0:
		return
	_knock_left = seconds
	_knock_velocity = Vector3(push.x, 0.0, push.z)
	_attack_step = -1
	_abort_attacks()
	_fire("HitShot")
	CombatVfx.shockwave(get_parent(), global_position, 1.2, Color(0.9, 0.85, 0.7, 0.8), 0.3)

## Схопили (кістяні руки чаклуна): seconds секунд на місці — ні кроку, ні
## перекату, бити можна. Перекат, що вже йде, рятує. true — схопили.
func root(seconds: float) -> bool:
	if _dead or _roll_left > 0.0 or _invulnerable_left > 0.0 and _roll_guard_left > 0.0:
		return false
	_rooted_left = maxf(_rooted_left, seconds)
	if _root_marker == null:
		_root_marker = CombatVfx.make_ground_marker(Color(0.45, 1.0, 0.45, 0.6), 0.7)
		CombatVfx.set_param(_root_marker, &"progress", 1.0)
		_root_marker.position.y = 0.05
		add_child(_root_marker)
	_root_marker.visible = true
	return true

func is_rooted() -> bool:
	return _rooted_left > 0.0

## Оглушити на seconds секунд (або доки не зніме end_stun). Перекат не
## рятує — це не удар, а сила боса.
func stun(seconds: float) -> void:
	if _dead:
		return
	_roll_left = 0.0
	_knock_left = maxf(_knock_left, seconds)
	_knock_velocity = Vector3.ZERO
	_attack_step = -1
	_abort_attacks()
	if _stun_stars == null:
		_stun_stars = Enemy3D.make_stun_stars()
		add_child(_stun_stars)
		_stun_stars.position = Vector3(0, 2.1, 0)
		var spin := _stun_stars.create_tween().set_loops()
		spin.tween_property(_stun_stars, "rotation:y", TAU, 0.9).from(0.0)
	_stun_stars.visible = true

func end_stun() -> void:
	_knock_left = 0.0
	if _stun_stars != null:
		_stun_stars.visible = false

## Воскресіння за відео (данж): частина здоров'я й щит на кілька секунд.
## Перезарядка здібностей лишається, як була, — лише перекат готовий
## одразу, щоб було чим вирватись з оточення.
func revive(hp_fraction: float, shield_seconds: float) -> void:
	if not _dead:
		return
	_dead = false
	_attack_step = -1
	_roll_left = 0.0
	velocity = Vector3.ZERO
	animation_tree.set("parameters/Dead/blend_amount", 0.0)
	current_hp = max_hp * hp_fraction
	_dodge_cooldown_left = 0.0
	_invulnerable_left = maxf(_invulnerable_left, shield_seconds)
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)
	CombatVfx.shockwave(get_parent(), global_position, 4.0, REVIVE_SHIELD_COLOR, 0.6)
	CombatVfx.impact(get_parent(), global_position + Vector3.UP * 1.0, REVIVE_SHIELD_COLOR, true)
	_show_revive_shield(shield_seconds)

## Щит воскресіння: світна куля довкола героя, що наприкінці блимає й
## спадає — видно, скільки ще він захищає.
func _show_revive_shield(seconds: float) -> void:
	var shield := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.05
	sphere.height = 2.1
	sphere.radial_segments = 20
	sphere.rings = 10
	shield.mesh = sphere
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = REVIVE_SHIELD_SHADER
	material.shader = shader
	material.set_shader_parameter(&"color", REVIVE_SHIELD_COLOR)
	shield.material_override = material
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shield)
	shield.position = Vector3(0, 0.95, 0)
	shield.scale = Vector3.ONE * 0.2
	var tween := shield.create_tween()
	tween.tween_property(shield, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(seconds - 0.25 - 0.8, 0.0))
	# Останні 0.8 с — блимає: щит от-от спаде.
	for i in 4:
		tween.tween_method(func(value: float) -> void:
			material.set_shader_parameter(&"strength", value), 1.0, 0.25, 0.1)
		tween.tween_method(func(value: float) -> void:
			material.set_shader_parameter(&"strength", value), 0.25, 1.0, 0.1)
	tween.tween_property(shield, "scale", Vector3.ONE * 1.3, 0.2)
	tween.parallel().tween_method(func(value: float) -> void:
		material.set_shader_parameter(&"strength", value), 1.0, 0.0, 0.2)
	tween.tween_callback(shield.queue_free)

## Здібність, обрана в поході (див. RunUpgrades). Кожен випадок тут
## щось реально змінює в бою — саме тому список здібностей у кожного
## героя свій: мечниці не пропонують пробивних куль, а стрільцю —
## ширшого замаху.
func apply_run_upgrade(id: StringName) -> void:
	match id:
		&"hp_up":
			max_hp += 25.0
			heal(25.0)
		&"regen":
			_regen_per_second += 1.0
		&"speed":
			_speed_bonus += 0.08
		&"damage":
			_damage *= 1.12
		&"crit":
			_crit_chance += 0.06
		&"lifesteal":
			_lifesteal += 0.05
		&"armor":
			_damage_taken_factor *= 0.9
		&"skill_cd":
			_skill_cooldown_factor *= 0.88
		&"dodge_cd":
			_dodge_cooldown_factor *= 0.82
		&"arc":
			_arc_factor *= 1.2
			_reach_bonus += 0.25
		&"knockback":
			_knockback_factor *= 1.6
		&"combo_speed":
			_attack_speed *= 1.12
			_apply_attack_speed()
		&"rage_gain":
			_rage_gain_factor *= 1.3
		&"dash_power":
			_dash_power *= 1.6
		&"whirl_power":
			_whirl_power *= 1.25
		&"pierce":
			_bullet_pierce += 1
		&"magazine":
			_magazine_factor += 0.4
			_ammo = magazine_size()
		&"reload":
			_reload_factor *= 0.75
		&"extra_bullet":
			_bullets_extra += 1
		&"accuracy":
			_spread_factor *= 0.5
			_damage *= 1.1
		&"fire_rate":
			_fire_rate_factor *= 0.85
		&"explosive":
			_explosive_bullets += 1
		&"mark_power":
			_mark_bonus += 0.15
		&"smoke_power":
			_smoke_bonus += 1.0
		&"cast_speed":
			_cast_rate_factor *= 0.87
		&"spell_extra":
			_spell_extra += 1
		&"spell_pierce":
			_spell_pierce += 1
		&"spell_power":
			_spell_power += 0.3
		&"ring_power":
			_ring_power += 0.3
		&"phoenix_power":
			_phoenix_bonus += 0.2
		&"nova_power":
			_nova_power += 0.3
		&"charge_speed":
			_charge_hits = maxi(_charge_hits - 1, 4)
		_:
			push_warning("Невідома здібність походу: %s" % id)
	_update_health_bar()
	health_changed.emit(current_hp, max_hp)

## Стара назва — щоб не ламати 2D-частину гри, яка ще жива в проєкті.
func apply_ability(id: StringName) -> void:
	apply_run_upgrade(id)

func _update_health_bar() -> void:
	if _health_bar != null:
		_health_bar.set_ratio(current_hp / max_hp)
