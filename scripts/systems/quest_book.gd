extends RefCounted
class_name QuestBook

## КВЕСТИ ПРИХИСТКУ. Кожен квест — у кого береш (giver), що зробити
## (objectives) і що отримаєш. Квести відкриваються по черзі (after —
## після якого стає доступним).
##
## Головне правило: квест не закінчується на "приніс — отримав золото".
## Принесене ЩОСЬ МІНЯЄ: дрова розпалюють багаття в таборі (і біля нього
## тепер можна вечеряти перед походом), камінь лагодить точило Коваля,
## трави наповнюють казан Мудреця. Такі квести мають поле boon — яку
## підготовку до походу вони відкривають (див. Boons); перша — у подарунок.
##
## Цілі (kind):
##   talk   — поговорити з NPC (target — його id);
##   wood / stone / herb — нарубати дерев / добути каменю / зібрати трав;
##   clear  — пройти рівні данжу (будь-які, скільки разів — count);
##   kill   — перемогти ворогів у данжі;
##   chest  — знайти загублені скрині в долині;
##   potion — зілля врятувало героя в бою.
##
## Нагорода: reward — золото, gems — геми, boon — підготовка до походу.
##
## ДОРУЧЕННЯ ДНЯ. Коли навчання позаду, Старійшина щодня має нове
## доручення (DAILY_POOL, по колу) — за нього дають геми. Його id завжди
## "daily"; наступного дня воно оновлюється саме.
##
## Стан у GameState.quests: id -> {"state": "active"|"ready"|"done",
## "progress": [число на кожну ціль]}. "ready" — усе виконано, лишилось
## здати тому, хто дав.

const QUESTS := [
	{"id": "welcome", "giver": &"elder", "title": "Місто, що не спить",
		"text": "Мандрівнику, ти прийшов у лиху годину. Третю ніч з-під старої каплиці чути стогін, а гробар Микола спустився до склепів — і не повернувся. Познайомся з нашими людьми: кожен знадобиться тобі, коли підеш униз.",
		"done_text": "Тепер ти знаєш усіх. Ось золото — купи в Наставниці Дарини зброю й броню свого класу. Без них у склепи не ходять.",
		"objectives": [
			{"kind": "talk", "target": &"mentor", "count": 1, "label": "Поговори з Наставницею Дариною"},
			{"kind": "talk", "target": &"smith", "count": 1, "label": "Поговори з Ковалем Богданом"},
			{"kind": "talk", "target": &"sage", "count": 1, "label": "Поговори з Мудрецем Велимиром"},
			{"kind": "talk", "target": &"merchant", "count": 1, "label": "Поговори з Торговкою Олесею"},
		], "reward": 450, "items": [["peasant_shirt", "common"], ["peasant_pants", "common"]]},
	{"id": "path", "giver": &"mentor", "after": "welcome", "title": "Шлях героя",
		"text": "Мечник, танк, маг, лучник чи друїд — ким підеш у темряву? Пам'ятай: клас вирішує зброя в руках. Візьми свою — і покажи мені.",
		"done_text": "Тримаєш упевнено! Ось ще трохи золота — на сет броні до цієї зброї.",
		"objectives": [{"kind": "equip", "count": 1, "label": "Візьми в руки зброю класу (у Дарини)"}], "reward": 200},
	{"id": "first_dive", "giver": &"elder", "after": "path", "title": "Тиша під каплицею",
		"text": "Вхід до склепів — за ратушею, біля старої каплиці. Спустись, знайди сліди Миколи й проклади собі шлях крізь першу залу.",
		"done_text": "Живий! І приніс Миколину лопату... Значить, він пішов глибше. Ми не залишимо його там.",
		"objectives": [{"kind": "clear", "count": 1, "label": "Пройди рівень склепів (портал за ратушею)"}], "reward": 400,
		"items": [["ranger_pants", "uncommon"]]},
	{"id": "temper", "giver": &"smith", "after": "path", "title": "Загартування",
		"text": "Сталь гартують у бою, хлопче. Пройдися склепами — дай мечу відчути кістку. Повернешся — нагострю так, що різатиме тіні.",
		"done_text": "Чую, як дзвенить! Відтепер моє точило — твоє: перед походом заходь, нагострю за кілька монет.",
		"objectives": [{"kind": "kill", "count": 25, "label": "Перемож ворогів у склепах"}], "reward": 250, "boon": "sharp",
		"items": [["ranger_boots", "uncommon"]]},
	{"id": "elixir", "giver": &"sage", "after": "path", "title": "Зілля з туману",
		"text": "У склепах повзе туман, що висмоктує життя. Я зварив зілля, яке саме рятує на краю. Візьми його — і дай йому врятувати тебе. Мені треба знати, чи воно діє.",
		"done_text": "Діє! Тепер мій казан до твоїх послуг: за дрібку золота зварю ще.",
		"objectives": [{"kind": "potion", "count": 1, "label": "Нехай зілля врятує тебе в бою"}], "reward": 250, "boon": "potion", "gems": 5},
	{"id": "trophies", "giver": &"merchant", "after": "first_dive", "title": "Трофеї для крамниці",
		"text": "Кажуть, мерці там тримають при собі чимало добра. Принеси мені три речі, що впадуть із них, — подивлюсь, що там за майстри були.",
		"done_text": "Оце робота! Залиш собі — мені досить подивитись. А ось тобі за клопіт.",
		"objectives": [{"kind": "loot", "count": 3, "label": "Підбери 3 речі, що впали з ворогів"}], "reward": 300, "gems": 15},
	{"id": "tavern", "giver": &"elder", "after": "first_dive", "title": "Вечеря в «Золотому Кабані»",
		"text": "Ситий воїн витримує більше. Корчмар уже знає тебе — сідай за стіл біля таверни перед кожним походом.",
		"done_text": "Смачного! Відтепер вечеря в таверні додає сил перед походом.",
		"objectives": [{"kind": "clear", "count": 1, "label": "Пройди ще один рівень склепів"}], "reward": 200, "boon": "meal"},
	{"id": "deeper", "giver": &"elder", "after": "first_dive", "title": "Сліди Миколи",
		"text": "Лопата лежала біля зламаної печаті. Хтось зламав її зсередини. Йди глибше — знайди, хто там прокинувся.",
		"done_text": "Хранитель Склепів... Отже, легенди правдиві. Микола живий — він ховався в бічній ніші. Дякую тобі.",
		"objectives": [{"kind": "boss", "count": 1, "label": "Перемож Хранителя Склепів"}], "reward": 800, "gems": 10,
		"items": [["ranger_pauldron", "rare"]]},
	{"id": "hunter", "giver": &"mentor", "after": "first_dive", "title": "Набита рука",
		"text": "Справжній воїн росте в бою. Перемож шістдесят ворогів — і я навчу тебе ще дечого.",
		"done_text": "Відчуваєш, як окріпла рука? Так і має бути.",
		"objectives": [{"kind": "kill", "count": 60, "label": "Перемож ворогів у данжах"}], "reward": 500, "gems": 5},
]

## Доручення дня з'являються після цього квесту.
const DAILY_AFTER := "first_dive"
## Щоденні доручення Старійшини (по колу).
const DAILY_POOL := [
	{"title": "Нічна варта", "text": "Мерці знову лізуть нагору. Прорідь їх.",
		"objective": {"kind": "kill", "count": 40, "label": "Перемож ворогів у данжі"}, "reward": 300, "gems": 3},
	{"title": "Розвідка", "text": "Глянь, що діється на нижніх рівнях.",
		"objective": {"kind": "clear", "count": 2, "label": "Пройди рівні данжу"}, "reward": 400, "gems": 4},
	{"title": "Здобич для міста", "text": "Олеся платить за трофеї — принеси щось цінне.",
		"objective": {"kind": "loot", "count": 2, "label": "Підбери речі з ворогів"}, "reward": 300, "gems": 3},
	{"title": "Велика облава", "text": "Їх стало забагато. Час для великої облави.",
		"objective": {"kind": "kill", "count": 80, "label": "Перемож ворогів у данжі"}, "reward": 500, "gems": 5},
]

## Сьогоднішній день (номер) — щоб знати, коли доручення застаріло.
static func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

## Доручення дня як звичайний квест.
static func daily() -> Dictionary:
	var pick: Dictionary = DAILY_POOL[today() % DAILY_POOL.size()]
	return {"id": "daily", "giver": &"elder", "after": DAILY_AFTER, "title": pick.title, "text": pick.text,
		"done_text": "Добра робота. Завтра приходь знову — справи в Прихистку не закінчуються.",
		"objectives": [pick.objective], "reward": pick.reward, "gems": pick.gems}

## Усі квести: постійні й сьогоднішнє доручення. Учорашнє доручення
## (взяте чи здане) тут же забувається.
static func all_quests() -> Array:
	var entry: Dictionary = GameState.quests.get("daily", {})
	if not entry.is_empty() and int(entry.get("day", -1)) != today():
		GameState.quests.erase("daily")
	var result := QUESTS.duplicate()
	result.append(daily())
	return result

static func get_quest(id: String) -> Dictionary:
	for quest: Dictionary in all_quests():
		if quest.id == id:
			return quest
	return {}

static func state_of(id: String) -> String:
	var entry: Dictionary = GameState.quests.get(id, {})
	return String(entry.get("state", ""))

## Можна взяти: ще не брали і попередній уже здано.
static func is_available(quest: Dictionary) -> bool:
	if state_of(quest.id) != "":
		return false
	var after: String = quest.get("after", "")
	return after == "" or state_of(after) == "done"

## Що має сказати цей NPC: квест на здачу, далі новий квест, або нічого.
static func ready_for(npc: StringName) -> Dictionary:
	for quest: Dictionary in all_quests():
		if quest.giver == npc and state_of(quest.id) == "ready":
			return quest
	return {}

static func available_for(npc: StringName) -> Dictionary:
	for quest: Dictionary in all_quests():
		if quest.giver == npc and is_available(quest):
			return quest
	return {}

static func active_quests() -> Array:
	var result := []
	for quest: Dictionary in all_quests():
		if state_of(quest.id) in ["active", "ready"]:
			result.append(quest)
	return result

static func accept(id: String) -> void:
	var quest := get_quest(id)
	if quest.is_empty():
		return
	var progress := []
	for objective: Dictionary in quest.objectives:
		# Скрині, знайдені ще до розмови з Торговкою, теж рахуються.
		progress.append(mini(found_caches().size(), int(objective.count)) if objective.kind == "chest" else 0)
	GameState.quests[id] = {"state": "active", "progress": progress, "day": today()}
	_check(id)
	GameState.quests_changed.emit()
	SaveManager.save_game()

## Здати квест. Повертає, що отримано: {"gold", "gems", "boon"}.
static func complete(id: String) -> Dictionary:
	if state_of(id) != "ready":
		return {}
	var quest := get_quest(id)
	GameState.quests[id]["state"] = "done"
	var result := {"gold": int(quest.get("reward", 0)), "gems": int(quest.get("gems", 0)), "boon": String(quest.get("boon", ""))}
	GameState.add_gold(result.gold)
	if result.gems > 0:
		GameState.add_gems(result.gems)
	if result.boon != "":
		Boons.grant(result.boon)
	# Речі — у торбу (вдягаються в спорядженні).
	var given := []
	for entry: Array in quest.get("items", []):
		var item := ItemDb.roll(String(entry[0]), String(entry[1]), maxi(GameState.hero_level, 1))
		ItemDb.give(item)
		given.append(ItemDb.title_of(item))
	result["items"] = given
	# Досвід героя: за кожне завдання.
	result["xp"] = xp_of(quest)
	result["levels"] = GameState.add_hero_xp(result.xp)
	GameState.quests_changed.emit()
	SaveManager.save_game()
	return result

## Досвід за завдання: більше золота — більше досвіду.
static func xp_of(quest: Dictionary) -> int:
	return 60 + int(quest.get("reward", 0)) / 2 + int(quest.get("gems", 0)) * 10

## Рядок нагороди для кнопки "Здати": "+200 золота, +5 гемів".
static func reward_text(quest: Dictionary) -> String:
	var parts := PackedStringArray()
	if int(quest.get("reward", 0)) > 0:
		parts.append("+%d золота" % int(quest.reward))
	if int(quest.get("gems", 0)) > 0:
		parts.append("+%d гемів" % int(quest.gems))
	parts.append("+%d досвіду" % xp_of(quest))
	for entry: Array in quest.get("items", []):
		parts.append(String(ItemDb.BASES.get(entry[0], {}).get("title", "річ")))
	return ", ".join(parts)

## Подія гри: поговорив, нарубав, зібрав, пройшов рівень, переміг ворога,
## знайшов скриню, випив зілля.
static func report(kind: String, amount: int = 1, target: StringName = &"") -> void:
	var changed := false
	for quest: Dictionary in all_quests():
		if state_of(quest.id) != "active":
			continue
		var entry: Dictionary = GameState.quests[quest.id]
		var progress: Array = entry.progress
		for i in quest.objectives.size():
			var objective: Dictionary = quest.objectives[i]
			if objective.kind != kind:
				continue
			if objective.has("target") and objective.target != target:
				continue
			var before: int = progress[i]
			progress[i] = mini(before + amount, int(objective.count))
			changed = changed or progress[i] != before
		_check(quest.id)
	if changed:
		GameState.quests_changed.emit()
		# Вороги падають десятками — сейв щоразу смикав би телефон; прогрес
		# "kill" збережеться з найближчим сейвом (кінець рівня, золото).
		if kind != "kill":
			SaveManager.save_game()

static func objective_progress(id: String, index: int) -> int:
	var entry: Dictionary = GameState.quests.get(id, {})
	var progress: Array = entry.get("progress", [])
	return int(progress[index]) if index < progress.size() else 0

## Загублені скрині, які герой уже знайшов (їхні id).
static func found_caches() -> Array:
	if not GameState.haven.has("caches"):
		GameState.haven["caches"] = []
	return GameState.haven["caches"]

static func _check(id: String) -> void:
	var quest := get_quest(id)
	var entry: Dictionary = GameState.quests[id]
	for i in quest.objectives.size():
		if int(entry.progress[i]) < int(quest.objectives[i].count):
			return
	entry["state"] = "ready"
