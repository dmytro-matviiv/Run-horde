extends RefCounted
class_name Boons

## ПІДГОТОВКА ДО ПОХОДУ. Те, заради чого варто збирати ресурси в
## Прихистку: кожен ресурс перетворюється на перевагу в данжі.
##
##   meal   — вечеря біля багаття в таборі (дерево): більше здоров'я
##            в наступному поході;
##   sharp  — гостріння зброї на точилі Коваля (камінь): більше шкоди
##            в наступному поході;
##   potion — зілля з казана Мудреця (трави): саме вип'ється, коли в бою
##            здоров'я впаде нижче третини. Зілля не згорають — лежать у
##            торбі, доки не знадобляться.
##
## Кожну перевагу відкриває свій квест (quest): нарубав дров — багаття
## знову горить і біля нього можна вечеряти, і так далі.
##
## Запас лежить у GameState.haven["boons"]: id -> кількість.

const BOONS := {
	"meal": {"title": "Вечеря біля багаття", "verb": "Повечеряти", "quest": "firewood",
		"cost": {"wood": 2}, "limit": 1, "short": "Вечеря",
		"effect": "+20% здоров'я в наступному поході",
		"done": "Ситна вечеря! У наступному поході — на 20% більше здоров'я.",
		"full": "Ти вже ситий — вечеря чекає наступного походу."},
	"sharp": {"title": "Гостре лезо", "verb": "Нагострити", "quest": "smith_stone",
		"cost": {"stone": 3}, "limit": 1, "short": "Гостре лезо",
		"effect": "+15% шкоди в наступному поході",
		"done": "Зброя гостра як бритва! У наступному поході — на 15% більше шкоди.",
		"full": "Зброя вже нагострена — гостріша не стане."},
	"potion": {"title": "Зілля зцілення", "verb": "Зварити зілля", "quest": "herbs",
		"cost": {"herb": 3}, "limit": 3, "short": "Зілля",
		"effect": "саме вип'ється, коли здоров'я впаде нижче третини",
		"done": "Зілля готове! Воно саме вип'ється, коли в бою стане скрутно.",
		"full": "Більше трьох зіль у торбу не влізе."},
}

const RESOURCE_TITLES := {"wood": "Дерево", "stone": "Камінь", "herb": "Трави"}

const MEAL_HP_FACTOR := 1.2
const SHARP_DAMAGE_FACTOR := 1.15
## Зілля спрацьовує, коли здоров'я нижче цієї частки, і повертає стільки.
const POTION_THRESHOLD := 0.34
const POTION_HEAL := 0.45

static func _store() -> Dictionary:
	if not GameState.haven.has("boons"):
		GameState.haven["boons"] = {}
	return GameState.haven["boons"]

static func count(id: String) -> int:
	return int(_store().get(id, 0))

static func is_unlocked(id: String) -> bool:
	return QuestBook.state_of(String(BOONS[id].quest)) == "done"

## "Дерево ×2" — ціна для напису на кнопці.
static func cost_text(id: String) -> String:
	var parts := PackedStringArray()
	var cost: Dictionary = BOONS[id].cost
	for resource: String in cost:
		parts.append("%s ×%d" % [RESOURCE_TITLES.get(resource, resource), int(cost[resource])])
	return ", ".join(parts)

## Чому зараз не можна: порожній рядок — можна.
static func problem(id: String) -> String:
	var boon: Dictionary = BOONS[id]
	if count(id) >= int(boon.limit):
		return String(boon.full)
	var cost: Dictionary = boon.cost
	for resource: String in cost:
		var have := int(GameState.resources.get(resource, 0))
		if have < int(cost[resource]):
			return "Потрібно: %s (у тебе %d)" % [cost_text(id), have]
	return ""

## Зробити перевагу за ресурси. Повертає false, якщо не вийшло.
static func craft(id: String) -> bool:
	if problem(id) != "":
		return false
	var cost: Dictionary = BOONS[id].cost
	for resource: String in cost:
		GameState.resources[resource] = int(GameState.resources.get(resource, 0)) - int(cost[resource])
	grant(id)
	return true

## Подарувати (нагорода квесту) — у межах того, що можна нести.
static func grant(id: String, amount: int = 1) -> void:
	_store()[id] = mini(count(id) + amount, int(BOONS[id].limit))
	GameState.quests_changed.emit()
	SaveManager.save_game()

## Що герой бере з собою: для рядка в кутку екрана.
static func summary() -> String:
	var parts := PackedStringArray()
	for id: String in BOONS:
		var have := count(id)
		if have > 0:
			parts.append(String(BOONS[id].short) + (" ×%d" % have if int(BOONS[id].limit) > 1 else ""))
	return ", ".join(parts)

## Початок походу в данж: вечеря й гостріння спрацьовують і витрачаються,
## зілля герой несе з собою. Повертає рядки для повідомлення гравцеві.
static func begin_run(player: Node) -> PackedStringArray:
	var notes := PackedStringArray()
	var hp_factor := 1.0
	var damage_factor := 1.0
	var store := _store()
	if count("meal") > 0:
		store["meal"] = count("meal") - 1
		hp_factor = MEAL_HP_FACTOR
		notes.append("вечеря: +20% здоров'я")
	if count("sharp") > 0:
		store["sharp"] = count("sharp") - 1
		damage_factor = SHARP_DAMAGE_FACTOR
		notes.append("гостре лезо: +15% шкоди")
	var potions := count("potion")
	if potions > 0:
		notes.append("зілля ×%d" % potions)
	if player != null and player.has_method("apply_boons"):
		player.call("apply_boons", hp_factor, damage_factor, potions)
	if not notes.is_empty():
		SaveManager.save_game()
	return notes

## Герой випив зілля в бою.
static func spend_potion() -> void:
	_store()["potion"] = maxi(count("potion") - 1, 0)
	QuestBook.report("potion")
	SaveManager.save_game()
