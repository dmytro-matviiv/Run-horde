extends RefCounted
class_name RunUpgrades

## ЗДІБНОСТІ, ЯКІ ВИПАДАЮТЬ У ПОХОДІ.
##
## Раніше тут був список зі старої 2D-гри, і він пропонував дурниці:
## мечниці — "снаряд пробиває ще одного ворога", хоча вона не стріляє, а
## стрільцю — те саме пробиття, якого в бою просто не існувало.
##
## Тепер кожна здібність знає, КОМУ вона підходить:
##   scope = "any"     — будь-кому;
##   scope = "melee"   — лише з холодною зброєю;
##   scope = "ranged"  — лише з вогнепальною;
##   scope = id героя  — лише цьому героєві (його особисті прийоми).
##
## І кожна щось РЕАЛЬНО робить: ефект застосовує герой у
## player_3d.gd::apply_run_upgrade(). Нова здібність додається сюди
## одним рядком і одним випадком у тому match.

const UPGRADES := [
	# --- спільні ---
	{"id": &"hp_up", "scope": "any", "max": 4, "title": "Міцний корпус",
		"text": "+25 до здоров'я і стільки ж лікує одразу."},
	{"id": &"regen", "scope": "any", "max": 3, "title": "Аптечка",
		"text": "+1 здоров'я за секунду, поки триває похід."},
	{"id": &"speed", "scope": "any", "max": 3, "title": "Легкий крок",
		"text": "+8% швидкості руху."},
	{"id": &"damage", "scope": "any", "max": 5, "title": "Сила",
		"text": "+12% шкоди від усього."},
	{"id": &"crit", "scope": "any", "max": 4, "title": "Влучність",
		"text": "+6% шансу критичного удару (він б'є майже вдвічі)."},
	{"id": &"lifesteal", "scope": "any", "max": 3, "title": "Вампіризм",
		"text": "5% завданої шкоди повертається тобі здоров'ям."},
	{"id": &"armor", "scope": "any", "max": 3, "title": "Броня",
		"text": "-10% шкоди, яку отримуєш."},
	{"id": &"skill_cd", "scope": "any", "max": 3, "title": "Тактика",
		"text": "-12% перезарядки здібностей."},
	{"id": &"dodge_cd", "scope": "any", "max": 2, "title": "Спритність",
		"text": "-18% перезарядки перекату."},

	# --- холодна зброя ---
	{"id": &"arc", "scope": "melee", "max": 3, "title": "Ширший замах",
		"text": "+20% ширини удару й трохи більша дальність."},
	{"id": &"knockback", "scope": "melee", "max": 2, "title": "Важка рука",
		"text": "Удари відкидають ворогів помітно далі."},
	{"id": &"combo_speed", "scope": "melee", "max": 3, "title": "Швидкі руки",
		"text": "+12% швидкості ударів."},

	# --- особисте: Клинкова Вартова ---
	{"id": &"rage_gain", "scope": "blade_warden", "max": 3, "title": "Невгамовна лють",
		"text": "Лють накопичується на 30% швидше — ривки частіші."},
	{"id": &"dash_power", "scope": "blade_warden", "max": 2, "title": "Таран",
		"text": "Ривок Люті б'є на 60% сильніше й пролітає далі."},
	{"id": &"whirl_power", "scope": "blade_warden", "max": 3, "title": "Буря клинків",
		"text": "Вихор б'є на 25% сильніше й ширше."},

	# --- вогнепальна зброя ---
	{"id": &"pierce", "scope": "ranged", "max": 3, "title": "Пробивний набій",
		"text": "Куля прошиває ще одного ворога наскрізь."},
	{"id": &"magazine", "scope": "ranged", "max": 3, "title": "Розширений магазин",
		"text": "+40% набоїв у магазині."},
	{"id": &"reload", "scope": "ranged", "max": 3, "title": "Швидка перезарядка",
		"text": "-25% часу перезарядки."},
	{"id": &"extra_bullet", "scope": "ranged", "max": 2, "title": "Подвійний постріл",
		"text": "Кожен постріл випускає ще одну кулю поруч."},
	{"id": &"accuracy", "scope": "ranged", "max": 2, "title": "Точний приціл",
		"text": "Удвічі менший розкид і +10% шкоди."},
	{"id": &"fire_rate", "scope": "ranged", "max": 3, "title": "Швидкий вогонь",
		"text": "+15% темпу стрільби."},
	{"id": &"explosive", "scope": "ranged", "max": 2, "title": "Розривні кулі",
		"text": "Куля вибухає й зачіпає тих, хто поруч із ціллю."},

	# --- особисте: Оперативник ---
	{"id": &"mark_power", "scope": "void_assassin", "max": 2, "title": "Мисливець",
		"text": "Мічені цілі отримують ще на 15% більше шкоди."},
	{"id": &"smoke_power", "scope": "void_assassin", "max": 2, "title": "Густий дим",
		"text": "Димова граната тримається на секунду довше."},
]

const CARDS_PER_LEVEL := 3

## Три картки на вибір: лише те, що підходить цьому героєві з його
## зброєю і ще не прокачане до межі.
##
## Талант "Удача" підвищує шанс, що серед карток буде ОСОБИСТА здібність
## героя, — саме вони найсильніші.
static func pick(player: Node, taken: Dictionary, luck: float = 0.0, count: int = CARDS_PER_LEVEL) -> Array:
	var personal: Array = []
	var general: Array = []
	for upgrade: Dictionary in UPGRADES:
		if not _fits(upgrade, player) or int(taken.get(upgrade.id, 0)) >= int(upgrade.max):
			continue
		if upgrade.scope == "any" or upgrade.scope == "melee" or upgrade.scope == "ranged":
			general.append(upgrade)
		else:
			personal.append(upgrade)
	personal.shuffle()
	general.shuffle()

	var cards: Array = []
	while cards.size() < count and (not personal.is_empty() or not general.is_empty()):
		var take_personal := not personal.is_empty() and (general.is_empty() or randf() < 0.35 + luck)
		var upgrade: Dictionary = personal.pop_back() if take_personal else general.pop_back()
		var level := int(taken.get(upgrade.id, 0))
		cards.append({
			"id": upgrade.id,
			"title": upgrade.title,
			"text": upgrade.text,
			"level": level + 1,
			"max": int(upgrade.max),
		})
	return cards

## Чи підходить здібність цьому героєві з його поточною зброєю.
static func _fits(upgrade: Dictionary, player: Node) -> bool:
	var scope: String = upgrade.scope
	if scope == "any":
		return true
	if scope == "melee":
		return not player.is_ranged()
	if scope == "ranged":
		return player.is_ranged()
	var hero: HeroDef = player.hero_def
	return hero != null and String(hero.id) == scope
