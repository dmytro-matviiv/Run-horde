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
	{"id": "welcome", "giver": &"elder", "title": "Ласкаво просимо до Прихистку",
		"text": "Ти прибув вчасно, мандрівнику. Познайомся з нашими людьми — кожен знадобиться тобі в дорозі.",
		"done_text": "Тепер ти знаєш усіх. Ось трохи золота на перші покупки.",
		"objectives": [
			{"kind": "talk", "target": &"mentor", "count": 1, "label": "Поговори з Наставницею героїв"},
			{"kind": "talk", "target": &"smith", "count": 1, "label": "Поговори з Ковалем"},
			{"kind": "talk", "target": &"sage", "count": 1, "label": "Поговори з Мудрецем"},
			{"kind": "talk", "target": &"merchant", "count": 1, "label": "Поговори з Торговкою"},
		], "reward": 150},
	{"id": "firewood", "giver": &"elder", "after": "welcome", "title": "Згасле багаття",
		"text": "Багаття в таборі біля стежки згасло, і мандрівникам ніде перепочити. Нарубай дров у гаю на схід від площі — розпалимо його знову.",
		"done_text": "Горить! Відтепер перед походом можеш повечеряти біля багаття в таборі: ситий воїн витримує більше ударів. Перша вечеря — від мене.",
		"objectives": [{"kind": "wood", "count": 3, "label": "Нарубай дерев у гаю"}], "reward": 200, "boon": "meal"},
	{"id": "herbs", "giver": &"sage", "after": "firewood", "title": "Порожній казан",
		"text": "Мій казан порожній. Принеси трав із пагорба на заході й пару каменів із рунами — і я навчу тебе варити зілля, що рятує життя.",
		"done_text": "Тримай перше зілля: воно саме вип'ється, коли в бою стане зовсім скрутно. Захочеш іще — принось трави до мого казана.",
		"objectives": [{"kind": "herb", "count": 3, "label": "Збери трави на західному пагорбі"},
			{"kind": "stone", "count": 2, "label": "Добудь каменю там же"}], "reward": 250, "boon": "potion"},
	{"id": "first_dive", "giver": &"elder", "after": "herbs", "title": "Перший похід",
		"text": "Портал на верхній терасі веде в підземелля. Повечеряй біля багаття, візьми зілля — і пройди перший рівень.",
		"done_text": "Ти повернувся! Прихисток пишається тобою. Відтепер у мене щодня буде для тебе доручення.",
		"objectives": [{"kind": "clear", "count": 1, "label": "Пройди рівень данжу (портал на півночі)"}], "reward": 400},
	{"id": "caches", "giver": &"merchant", "after": "welcome", "title": "Загублений крам",
		"text": "Буря розкидала мої скрині по всій долині. Знайдеш — вміст твій, мені аби знати, що не пропали. Шукай за возом, на пагорбі, в гаю, за порталом — вони поблискують.",
		"done_text": "Усі п'ять! Та ти справжній слідопит. Тримай — це не золото, це краще.",
		"objectives": [{"kind": "chest", "count": 5, "label": "Знайди загублені скрині в долині"}], "reward": 300, "gems": 15},
	{"id": "smith_stone", "giver": &"smith", "after": "herbs", "title": "Тріснутий горн",
		"text": "Горн тріснув, і точило стоїть без діла. Принеси п'ять каменів із західного пагорба — полагоджу, і зможеш гострити зброю перед походом.",
		"done_text": "Горн палає, точило крутиться! Перше гостріння — за мій рахунок: у наступному поході битимеш сильніше.",
		"objectives": [{"kind": "stone", "count": 5, "label": "Добудь каменю на західному пагорбі"}], "reward": 300, "boon": "sharp"},
	{"id": "tested", "giver": &"sage", "after": "first_dive", "title": "Перевірено боєм",
		"text": "Зілля — не прикраса на поясі. Візьми одне в похід і дай йому врятувати тебе — тоді й поговоримо про справжню алхімію.",
		"done_text": "Відчув, як воно підхопило тебе на краю? Тепер знаєш, навіщо збирати трави.",
		"objectives": [{"kind": "potion", "count": 1, "label": "Нехай зілля врятує тебе в бою"}], "reward": 350, "gems": 5},
	{"id": "hunter", "giver": &"mentor", "after": "first_dive", "title": "Набита рука",
		"text": "Справжній воїн росте в бою. Здолай шістдесят ворогів у підземеллях.",
		"done_text": "Відчуваєш, як окріпла рука? Так і має бути.",
		"objectives": [{"kind": "kill", "count": 60, "label": "Перемож ворогів у данжі"}], "reward": 500, "gems": 5},
	{"id": "deeper", "giver": &"elder", "after": "first_dive", "title": "Глибше в темряву",
		"text": "Темрява під землею не спить. Пройди ще три рівні — і світ стане трохи безпечнішим.",
		"done_text": "Неймовірно. Про тебе вже співають біля багаття.",
		"objectives": [{"kind": "clear", "count": 3, "label": "Пройди рівні данжу"}], "reward": 800, "gems": 5},
	{"id": "lumber", "giver": &"smith", "after": "smith_stone", "title": "Деревина для руків'їв",
		"text": "Мені потрібне міцне дерево для руків'їв. Нарубай ще п'ять дерев — а я не поскуплюсь.",
		"done_text": "Добра деревина. Дякую, друже.",
		"objectives": [{"kind": "wood", "count": 5, "label": "Нарубай дерев у гаю"}], "reward": 350, "gems": 3},
]

## Доручення дня з'являються після цього квесту.
const DAILY_AFTER := "first_dive"
const DAILY_POOL := [
	{"title": "Доручення дня: зачистка", "text": "Сьогодні з порталу тягне холодом. Здолай сорок ворогів, доки вони не полізли нагору.",
		"objective": {"kind": "kill", "count": 40, "label": "Перемож ворогів у данжі"}, "reward": 300, "gems": 3},
	{"title": "Доручення дня: запаси", "text": "Запаси трав тануть. Збери шість — Мудрець не лишиться в боргу.",
		"objective": {"kind": "herb", "count": 6, "label": "Збери трави на західному пагорбі"}, "reward": 200, "gems": 2},
	{"title": "Доручення дня: розвідка", "text": "Нам треба знати, що діється внизу. Пройди два рівні підземелля.",
		"objective": {"kind": "clear", "count": 2, "label": "Пройди рівні данжу"}, "reward": 400, "gems": 4},
	{"title": "Доручення дня: дрова", "text": "Багаття їсть дрова швидше, ніж ми рубаємо. Нарубай шість дерев.",
		"objective": {"kind": "wood", "count": 6, "label": "Нарубай дерев у гаю"}, "reward": 200, "gems": 2},
	{"title": "Доручення дня: велике полювання", "text": "Чим менше їх унизу, тим спокійніше нагорі. Здолай вісімдесят ворогів.",
		"objective": {"kind": "kill", "count": 80, "label": "Перемож ворогів у данжі"}, "reward": 500, "gems": 5},
	{"title": "Доручення дня: камінь", "text": "Підпірні стіни сиплються. Добудь шість каменів на західному пагорбі.",
		"objective": {"kind": "stone", "count": 6, "label": "Добудь каменю на західному пагорбі"}, "reward": 200, "gems": 2},
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
	GameState.quests_changed.emit()
	SaveManager.save_game()
	return result

## Рядок нагороди для кнопки "Здати": "+200 золота, +5 гемів".
static func reward_text(quest: Dictionary) -> String:
	var parts := PackedStringArray()
	if int(quest.get("reward", 0)) > 0:
		parts.append("+%d золота" % int(quest.reward))
	if int(quest.get("gems", 0)) > 0:
		parts.append("+%d гемів" % int(quest.gems))
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
