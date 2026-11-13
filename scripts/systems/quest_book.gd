extends RefCounted
class_name QuestBook

## КВЕСТИ ПРИХИСТКУ. Кожен квест — у кого береш (giver), що зробити
## (objectives) і що отримаєш (нагорода золотом). Квести відкриваються
## по черзі (after — після якого стає доступним).
##
## Цілі (kind):
##   talk  — поговорити з NPC (target — його id);
##   wood / stone / herb — нарубати дерев / добути каменю / зібрати трав;
##   clear — пройти рівні данжу (будь-які, скільки разів — count);
##   kill  — перемогти ворогів у данжі.
##
## Стан у GameState.quests: id -> {"state": "active"|"ready"|"done",
## "progress": [число на кожну ціль]}. "ready" — усе виконано, лишилось
## здати тому, хто дав.
##
## Нові квести — просто новий запис у QUESTS (і, як треба, нова ціль у
## report()). Навчання для новачка — це перші квести: Старійшина знайомить
## з усіма жителями, далі дрова, трави, перший похід у данж.

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
	{"id": "firewood", "giver": &"elder", "after": "welcome", "title": "Дрова для багаття",
		"text": "Ночі тут холодні. Нарубай дров у гаю на схід від площі — підійди до дерева й рубай.",
		"done_text": "Гарна робота! Тепер біля багаття тепло всім.",
		"objectives": [{"kind": "wood", "count": 3, "label": "Нарубай дерев у гаю"}], "reward": 200},
	{"id": "herbs", "giver": &"sage", "after": "firewood", "title": "Трави й камінь",
		"text": "Для мого зілля потрібні трави з пагорба на заході — і кілька каменів із рунами, вони там же.",
		"done_text": "Саме те, що треба. Ці руни ще послужать тобі.",
		"objectives": [{"kind": "herb", "count": 3, "label": "Збери трави на західному пагорбі"},
			{"kind": "stone", "count": 2, "label": "Добудь каменю там же"}], "reward": 250},
	{"id": "first_dive", "giver": &"elder", "after": "herbs", "title": "Перший похід",
		"text": "Портал на верхній терасі веде в підземелля. Пройди перший рівень — і повертайся живим.",
		"done_text": "Ти повернувся! Прихисток пишається тобою.",
		"objectives": [{"kind": "clear", "count": 1, "label": "Пройди рівень данжу (портал на півночі)"}], "reward": 400},
	{"id": "hunter", "giver": &"mentor", "after": "first_dive", "title": "Набита рука",
		"text": "Справжній воїн росте в бою. Здолай шістдесят ворогів у підземеллях.",
		"done_text": "Відчуваєш, як окріпла рука? Так і має бути.",
		"objectives": [{"kind": "kill", "count": 60, "label": "Перемож ворогів у данжі"}], "reward": 500},
	{"id": "smith_stone", "giver": &"smith", "after": "herbs", "title": "Камінь для кузні",
		"text": "Горн тріснув. Принеси п'ять каменів із західного пагорба — віддячу.",
		"done_text": "Горн як новий. Заходь, підберемо тобі зброю.",
		"objectives": [{"kind": "stone", "count": 5, "label": "Добудь каменю на західному пагорбі"}], "reward": 300},
	{"id": "deeper", "giver": &"elder", "after": "first_dive", "title": "Глибше в темряву",
		"text": "Темрява під землею не спить. Пройди ще три рівні — і світ стане трохи безпечнішим.",
		"done_text": "Неймовірно. Про тебе вже співають біля багаття.",
		"objectives": [{"kind": "clear", "count": 3, "label": "Пройди рівні данжу"}], "reward": 800},
	{"id": "lumber", "giver": &"smith", "after": "smith_stone", "title": "Деревина для руків'їв",
		"text": "Мені потрібне міцне дерево для руків'їв. Нарубай ще п'ять дерев.",
		"done_text": "Добра деревина. Дякую, друже.",
		"objectives": [{"kind": "wood", "count": 5, "label": "Нарубай дерев у гаю"}], "reward": 350},
]

static func get_quest(id: String) -> Dictionary:
	for quest: Dictionary in QUESTS:
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
	for quest: Dictionary in QUESTS:
		if quest.giver == npc and state_of(quest.id) == "ready":
			return quest
	return {}

static func available_for(npc: StringName) -> Dictionary:
	for quest: Dictionary in QUESTS:
		if quest.giver == npc and is_available(quest):
			return quest
	return {}

static func active_quests() -> Array:
	var result := []
	for quest: Dictionary in QUESTS:
		if state_of(quest.id) in ["active", "ready"]:
			result.append(quest)
	return result

static func accept(id: String) -> void:
	var quest := get_quest(id)
	if quest.is_empty():
		return
	var progress := []
	for objective: Dictionary in quest.objectives:
		progress.append(0)
	GameState.quests[id] = {"state": "active", "progress": progress}
	_check(id)
	GameState.quests_changed.emit()
	SaveManager.save_game()

## Здати квест: нагорода й наступні квести.
static func complete(id: String) -> int:
	if state_of(id) != "ready":
		return 0
	var quest := get_quest(id)
	GameState.quests[id]["state"] = "done"
	var reward: int = quest.get("reward", 0)
	GameState.add_gold(reward)
	GameState.quests_changed.emit()
	SaveManager.save_game()
	return reward

## Подія гри: поговорив, нарубав, зібрав, пройшов рівень, переміг ворога.
static func report(kind: String, amount: int = 1, target: StringName = &"") -> void:
	var changed := false
	for quest: Dictionary in QUESTS:
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

static func _check(id: String) -> void:
	var quest := get_quest(id)
	var entry: Dictionary = GameState.quests[id]
	for i in quest.objectives.size():
		if int(entry.progress[i]) < int(quest.objectives[i].count):
			return
	entry["state"] = "ready"
