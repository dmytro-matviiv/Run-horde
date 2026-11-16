extends RefCounted
class_name TalentTree

## ДЕРЕВО ТАЛАНТІВ — одне спільне на всіх (як в Enshrouded): посередині
## центр, від нього п'ять гілок — Мечник, Танк, Маг, Лучник, Друїд.
## Класу не обирають: гравець веде гілку, що пасує його зброї, і може
## прихопити корисне з сусідньої (мечникові — лікування друїда тощо).
##
## Вузол відкривається, якщо вивчено сусіда ближче до центру (кільце
## r-1, найближчий за кутом). Типи вузлів (як у PoE / Diablo 4):
##   stat     — мале: + до характеристики (ті самі назви, що в ItemDb);
##   notable  — помітна пасивка з умовою (вампіризм, удар по повному
##              здоров'ю, броня на низькому здоров'ї...);
##   active   — новий прийом: кнопка в бою (будь-якою зброєю);
##   keystone — ключова: сильна, але з мінусом; міняє стиль гри.
##
## Очки: 2 за рівень (рівні 1..30). Скидання — GameState.talent_resets:
## перше безкоштовне, далі RESET_BASE_COST * 2^(n-1) золота.

const POINTS_PER_LEVEL := 2
const MAX_LEVEL := 30
const RESET_BASE_COST := 500
## Скільки прийомів із дерева може бути на кнопках одночасно.
const MAX_TALENT_SKILLS := 2

const BRANCHES := {
	"knight": {"title": "Мечник", "color": Color(0.95, 0.35, 0.28), "angle": -90.0},
	"tank": {"title": "Танк", "color": Color(0.85, 0.72, 0.35), "angle": -18.0},
	"druid": {"title": "Друїд", "color": Color(0.35, 0.85, 0.55), "angle": 54.0},
	"archer": {"title": "Лучник", "color": Color(0.55, 0.9, 0.3), "angle": 126.0},
	"mage": {"title": "Маг", "color": Color(0.45, 0.6, 1.0), "angle": 198.0},
}

## Ефекти, які розуміє бій (Player3D.apply_talents):
##  характеристики ItemDb (hp, armor, damage, attack_speed, crit,
##  move_speed, mana, mana_regen, cooldown, regen) +
##  lifesteal (%), kill_heal (% здоров'я за вбивство), low_hp_damage (%
##  шкоди нижче 35% здоров'я), first_strike (% шкоди по ворогу з повним
##  здоров'ям), crit_damage (%), mana_on_hit, damage_reduction (%),
##  dodge_cooldown (% швидше), last_stand (% броні нижче 35%), gold_find,
##  xp_gain, potion_heal (%), skill (id прийому), glass_cannon,
##  stoneskin, blood_magic, berserk, arcane_shield, deadeye, wild_heart.

## Гілка: кільця від центру. Кожен вузол — [id, назва, тип, ефекти, опис].
## Порожній опис для stat — збирається з ефектів.
const NODES := {
	"knight": [
		[["k_dmg1", "Гострий клинок", "stat", {"damage": 4}, ""], ["k_as1", "Швидка рука", "stat", {"attack_speed": 3}, ""], ["k_hp1", "Загартування", "stat", {"hp": 12}, ""]],
		[["k_dmg2", "Вага сталі", "stat", {"damage": 4}, ""], ["k_crit1", "Влучне око", "stat", {"crit": 2}, ""], ["k_first", "Перший удар", "notable", {"first_strike": 30}, "Удар по ворогу з повним здоров'ям завдає на 30% більше шкоди."], ["k_as2", "Ритм бою", "stat", {"attack_speed": 3}, ""]],
		[["k_hp2", "Міцна статура", "stat", {"hp": 15}, ""], ["k_whirl", "Вихор", "active", {"skill": "whirlwind"}, "Новий прийом: крутишся з клинком, ранячи всіх довкола."], ["k_dmg3", "Відточена техніка", "stat", {"damage": 5}, ""], ["k_lifesteal", "Спрага крові", "notable", {"lifesteal": 4}, "4% завданої шкоди повертається здоров'ям."], ["k_crit2", "Слабке місце", "stat", {"crit": 2}, ""]],
		[["k_as3", "Вихрові удари", "stat", {"attack_speed": 4}, ""], ["k_critdmg", "Смертельна точність", "notable", {"crit_damage": 35}, "Критичні удари завдають на 35% більше шкоди."], ["k_dmg4", "Майстер меча", "stat", {"damage": 5}, ""], ["k_hp3", "Залізне тіло", "stat", {"hp": 18}, ""], ["k_killheal", "Тріумф", "notable", {"kill_heal": 3}, "Кожна перемога над ворогом лікує 3% здоров'я."], ["k_move", "Легкий крок", "stat", {"move_speed": 3}, ""]],
		[["k_dmg5", "Нищівна сила", "stat", {"damage": 6}, ""], ["k_dash", "Ривок люті", "active", {"skill": "rage_dash"}, "Новий прийом: стрімкий ривок крізь ворогів."], ["k_crit3", "Холодний розрахунок", "stat", {"crit": 3}, ""], ["k_lowhp", "Лють загнаного", "notable", {"low_hp_damage": 35}, "Нижче 35% здоров'я твої удари сильніші на 35%."], ["k_as4", "Танець клинків", "stat", {"attack_speed": 4}, ""], ["k_hp4", "Сталевий дух", "stat", {"hp": 20}, ""]],
		[["k_dmg6", "Удар майстра", "stat", {"damage": 6}, ""], ["k_cd", "Бойовий досвід", "stat", {"cooldown": 5}, ""], ["k_berserk", "Берсерк", "keystone", {"berserk": 1}, "Чим менше в тебе здоров'я, тим швидше б'єш (до +40%), але броня вдвічі слабша."], ["k_crit4", "Око яструба", "stat", {"crit": 3}, ""], ["k_leech2", "Кривавий бенкет", "notable", {"lifesteal": 5}, "Ще 5% шкоди повертається здоров'ям."]],
		[["k_glass", "Скляна гармата", "keystone", {"glass_cannon": 1}, "+35% шкоди, але на 20% менше здоров'я."], ["k_master", "Легенда арени", "notable", {"damage": 10, "attack_speed": 8, "crit": 4}, "+10% шкоди, +8% швидкості атаки, +4% критичного удару."], ["k_execute", "Кат", "notable", {"first_strike": 25, "crit_damage": 25}, "Перший удар і критичні удари — ще на 25% сильніші."]],
	],
	"tank": [
		[["t_armor1", "Щільна шкура", "stat", {"armor": 4}, ""], ["t_hp1", "Велике серце", "stat", {"hp": 15}, ""], ["t_regen1", "Друге дихання", "stat", {"regen": 1}, ""]],
		[["t_armor2", "Кольчуга", "stat", {"armor": 5}, ""], ["t_dr1", "Стійкість", "notable", {"damage_reduction": 5}, "Уся отримана шкода менша на 5%."], ["t_hp2", "Витривалість", "stat", {"hp": 18}, ""], ["t_regen2", "Живучість", "stat", {"regen": 1}, ""]],
		[["t_armor3", "Латні пластини", "stat", {"armor": 6}, ""], ["t_seal", "Велика печать", "active", {"skill": "great_seal"}, "Новий прийом: золота печать на землі, що нищить ворогів у колі."], ["t_hp3", "Гранітна плоть", "stat", {"hp": 20}, ""], ["t_laststand", "Останній рубіж", "notable", {"last_stand": 60}, "Нижче 35% здоров'я твоя броня більша на 60%."], ["t_dr2", "Непохитність", "stat", {"damage_reduction": 3}, ""]],
		[["t_armor4", "Сталевий щит", "stat", {"armor": 7}, ""], ["t_hp4", "Тіло велетня", "stat", {"hp": 24}, ""], ["t_potion", "Цілюще зілля", "notable", {"potion_heal": 50}, "Зілля лікують на 50% сильніше."], ["t_regen3", "Невтомність", "stat", {"regen": 2}, ""], ["t_dodge", "Відскок", "notable", {"dodge_cooldown": 25}, "Перекат перезаряджається на 25% швидше."], ["t_dmg1", "Важкий кулак", "stat", {"damage": 4}, ""]],
		[["t_armor5", "Фортеця", "stat", {"armor": 8}, ""], ["t_nova", "Рунічний удар", "active", {"skill": "rune_nova"}, "Новий прийом: вибух рун відкидає й ранить ворогів довкола."], ["t_hp5", "Безмежна сила", "stat", {"hp": 26}, ""], ["t_dr3", "Броньований", "stat", {"damage_reduction": 4}, ""], ["t_killheal", "Рятівний удар", "notable", {"kill_heal": 4}, "Кожна перемога лікує 4% здоров'я."], ["t_regen4", "Кремінь", "stat", {"regen": 2}, ""]],
		[["t_stone", "Кам'яна шкіра", "keystone", {"stoneskin": 1}, "+40% броні й +10% здоров'я, але рухаєшся на 12% повільніше."], ["t_armor6", "Неприступність", "stat", {"armor": 9}, ""], ["t_hp6", "Гірська міць", "stat", {"hp": 30}, ""], ["t_dr4", "Залізна воля", "notable", {"damage_reduction": 6}, "Уся отримана шкода менша ще на 6%."], ["t_regen5", "Відродження", "stat", {"regen": 3}, ""]],
		[["t_bulwark", "Жива стіна", "notable", {"armor": 15, "hp": 40, "damage_reduction": 5}, "+15 броні, +40 здоров'я, шкода по тобі менша на 5%."], ["t_juggernaut", "Таран", "keystone", {"stoneskin": 1, "damage": 12}, "Кам'яна шкіра і ще +12% шкоди."], ["t_titan", "Титан", "notable", {"hp": 60, "regen": 3}, "+60 здоров'я і +3 відновлення на секунду."]],
	],
	"mage": [
		[["m_mana1", "Глибина духу", "stat", {"mana": 15}, ""], ["m_regen1", "Потік сили", "stat", {"mana_regen": 1}, ""], ["m_dmg1", "Іскра", "stat", {"damage": 4}, ""]],
		[["m_cd1", "Швидкі руни", "stat", {"cooldown": 4}, ""], ["m_onhit", "Відлуння мани", "notable", {"mana_on_hit": 2}, "Кожне влучання повертає 2 мани."], ["m_dmg2", "Полум'я розуму", "stat", {"damage": 5}, ""], ["m_mana2", "Колодязь мани", "stat", {"mana": 18}, ""]],
		[["m_frost", "Крижана нова", "active", {"skill": "frost_nova"}, "Новий прийом: вибух криги заморожує ворогів довкола."], ["m_regen2", "Медитація", "stat", {"mana_regen": 1}, ""], ["m_crit1", "Ясність", "stat", {"crit": 2}, ""], ["m_critdmg", "Тріщина реальності", "notable", {"crit_damage": 30}, "Критичні удари чарами на 30% сильніші."], ["m_cd2", "Знання рун", "stat", {"cooldown": 5}, ""]],
		[["m_dmg3", "Розпечений жезл", "stat", {"damage": 6}, ""], ["m_fire", "Вогняне коло", "active", {"skill": "fire_ring"}, "Новий прийом: стіна вогню довкола тебе палить усіх."], ["m_mana3", "Безодня сили", "stat", {"mana": 22}, ""], ["m_first", "Удар блискавки", "notable", {"first_strike": 35}, "Перше влучання по свіжому ворогу — на 35% сильніше."], ["m_regen3", "Гармонія", "stat", {"mana_regen": 2}, ""], ["m_hp1", "Захисний оберіг", "stat", {"hp": 12}, ""]],
		[["m_barrage", "Арканний залп", "active", {"skill": "arcane_barrage"}, "Новий прийом: залп магічних куль, що самі шукають ціль."], ["m_dmg4", "Сила стихій", "stat", {"damage": 6}, ""], ["m_cd3", "Потік часу", "stat", {"cooldown": 6}, ""], ["m_onhit2", "Живлення", "notable", {"mana_on_hit": 3}, "Кожне влучання повертає ще 3 мани."], ["m_crit2", "Пророцтво", "stat", {"crit": 3}, ""], ["m_mana4", "Океан мани", "stat", {"mana": 25}, ""]],
		[["m_shield", "Арканний щит", "keystone", {"arcane_shield": 1}, "Половину шкоди по тобі забирає мана замість здоров'я."], ["m_blood", "Кровна магія", "keystone", {"blood_magic": 1}, "Прийоми коштують здоров'я, а не ману; +15% здоров'я."], ["m_dmg5", "Архімаг", "stat", {"damage": 7}, ""], ["m_moon", "Місячна буря", "active", {"skill": "moon_storm"}, "Новий прийом: з неба падають місячні зорі."], ["m_regen4", "Вічне джерело", "stat", {"mana_regen": 3}, ""]],
		[["m_master", "Володар чар", "notable", {"damage": 12, "cooldown": 10, "mana": 30}, "+12% шкоди, прийоми швидше на 10%, +30 мани."], ["m_storm", "Серце бурі", "notable", {"crit": 5, "crit_damage": 40}, "+5% критичного удару, критичні — на 40% сильніші."], ["m_cards", "Карткова буря", "active", {"skill": "card_storm"}, "Новий прийом: вихор магічних карт ріже все довкола."]],
	],
	"archer": [
		[["a_as1", "Тятива", "stat", {"attack_speed": 4}, ""], ["a_crit1", "Зір сокола", "stat", {"crit": 2}, ""], ["a_move1", "Тихий крок", "stat", {"move_speed": 3}, ""]],
		[["a_dmg1", "Гострі наконечники", "stat", {"damage": 4}, ""], ["a_first", "Засідка", "notable", {"first_strike": 35}, "Перший постріл по ворогу — на 35% сильніший."], ["a_crit2", "Стрілецький інстинкт", "stat", {"crit": 2}, ""], ["a_move2", "Мисливець", "stat", {"move_speed": 3}, ""]],
		[["a_as2", "Швидкі руки", "stat", {"attack_speed": 4}, ""], ["a_venom", "Отруйне болото", "active", {"skill": "venom_swamp"}, "Новий прийом: калюжа отрути труїть ворогів у ній."], ["a_dodge", "Спритність", "notable", {"dodge_cooldown": 30}, "Перекат перезаряджається на 30% швидше."], ["a_dmg2", "Важкі стріли", "stat", {"damage": 5}, ""], ["a_hp1", "Мисливська витривалість", "stat", {"hp": 12}, ""]],
		[["a_critdmg", "Постріл у серце", "notable", {"crit_damage": 35}, "Критичні постріли на 35% сильніші."], ["a_crit3", "Холодне око", "stat", {"crit": 3}, ""], ["a_as3", "Злива стріл", "stat", {"attack_speed": 5}, ""], ["a_smoke", "Димова завіса", "active", {"skill": "smoke_veil"}, "Новий прийом: зникаєш у диму, вороги губляться."], ["a_move3", "Вітер", "stat", {"move_speed": 4}, ""], ["a_gold", "Нюх скарбошукача", "notable", {"gold_find": 20}, "+20% золота з ворогів."]],
		[["a_dmg3", "Розривні стріли", "stat", {"damage": 6}, ""], ["a_killheal", "Здобич", "notable", {"kill_heal": 3}, "Кожна перемога лікує 3% здоров'я."], ["a_crit4", "Снайпер", "stat", {"crit": 3}, ""], ["a_as4", "Безперервний вогонь", "stat", {"attack_speed": 5}, ""], ["a_cd1", "Мисливські хитрощі", "stat", {"cooldown": 5}, ""], ["a_hp2", "Шкіряна броня", "stat", {"armor": 4}, ""]],
		[["a_deadeye", "Мертве око", "keystone", {"deadeye": 1}, "+8% критичного удару, критичні вдвічі сильніші, але без критичного — шкода менша на 15%."], ["a_dmg4", "Майстер лука", "stat", {"damage": 7}, ""], ["a_move4", "Тінь лісу", "stat", {"move_speed": 4}, ""], ["a_cards", "Віяло лез", "active", {"skill": "card_storm"}, "Новий прийом: віяло лез летить на всіх довкола."], ["a_xp", "Слідопит", "notable", {"xp_gain": 15}, "+15% досвіду героя."]],
		[["a_legend", "Легендарний стрілець", "notable", {"damage": 10, "crit": 5, "attack_speed": 6}, "+10% шкоди, +5% критичного удару, +6% швидкості атаки."], ["a_glass", "Скляна гармата", "keystone", {"glass_cannon": 1}, "+35% шкоди, але на 20% менше здоров'я."], ["a_ghost", "Привид", "notable", {"move_speed": 8, "dodge_cooldown": 20}, "+8% швидкості й перекат швидше на 20%."]],
	],
	"druid": [
		[["d_regen1", "Сік життя", "stat", {"regen": 1}, ""], ["d_hp1", "Корінь", "stat", {"hp": 14}, ""], ["d_mana1", "Дух лісу", "stat", {"mana": 12}, ""]],
		[["d_heal", "Цілюща природа", "notable", {"kill_heal": 3}, "Кожна перемога лікує 3% здоров'я."], ["d_armor1", "Кора", "stat", {"armor": 4}, ""], ["d_regen2", "Весняна сила", "stat", {"regen": 1}, ""], ["d_dmg1", "Пазурі", "stat", {"damage": 4}, ""]],
		[["d_hp2", "Дубова міць", "stat", {"hp": 18}, ""], ["d_swamp", "Болото", "active", {"skill": "venom_swamp"}, "Новий прийом: болото отрути з-під землі."], ["d_mana2", "Шепіт лісу", "stat", {"mana_regen": 1}, ""], ["d_leech", "Голод звіра", "notable", {"lifesteal": 4}, "4% завданої шкоди повертається здоров'ям."], ["d_as1", "Дикість", "stat", {"attack_speed": 4}, ""]],
		[["d_armor2", "Шкура ведмедя", "stat", {"armor": 6}, ""], ["d_regen3", "Цвітіння", "stat", {"regen": 2}, ""], ["d_moon", "Місячне сяйво", "active", {"skill": "moon_storm"}, "Новий прийом: місячні зорі падають на ворогів."], ["d_dmg2", "Ікла", "stat", {"damage": 5}, ""], ["d_potion", "Травник", "notable", {"potion_heal": 60}, "Зілля лікують на 60% сильніше."], ["d_move1", "Біг вовка", "stat", {"move_speed": 4}, ""]],
		[["d_hp3", "Серце лісу", "stat", {"hp": 22}, ""], ["d_wild", "Дике серце", "keystone", {"wild_heart": 1}, "+12% шкоди й +12% броні; відновлення здоров'я вдвічі сильніше, але мана відновлюється вдвічі повільніше."], ["d_crit1", "Інстинкт хижака", "stat", {"crit": 3}, ""], ["d_lowhp", "Поранений звір", "notable", {"low_hp_damage": 30, "last_stand": 30}, "Нижче 35% здоров'я: +30% шкоди і +30% броні."], ["d_regen4", "Безсмертний дуб", "stat", {"regen": 2}, ""], ["d_as2", "Шал", "stat", {"attack_speed": 5}, ""]],
		[["d_armor3", "Кам'яна кора", "stat", {"armor": 8}, ""], ["d_dmg3", "Розлючений звір", "stat", {"damage": 6}, ""], ["d_nature", "Подих природи", "notable", {"regen": 4, "hp": 30}, "+4 відновлення здоров'я на секунду, +30 здоров'я."], ["d_mana3", "Друїдське коло", "stat", {"mana": 25}, ""], ["d_hp4", "Віковічний", "stat", {"hp": 26}, ""]],
		[["d_alpha", "Ватажок зграї", "notable", {"damage": 12, "lifesteal": 3, "attack_speed": 6}, "+12% шкоди, +3% вампіризму, +6% швидкості атаки."], ["d_ancient", "Древній", "notable", {"hp": 50, "armor": 12, "regen": 3}, "+50 здоров'я, +12 броні, +3 відновлення на секунду."], ["d_blood", "Кровна магія", "keystone", {"blood_magic": 1}, "Прийоми коштують здоров'я, а не ману; +15% здоров'я."]],
	],
}

## Геометрія павутини (ті самі числа — в екрані дерева): вузли одного
## кільця не ближче GEO_MIN_GAP пікселів один до одного.
const GEO_RING_START := 190.0
const GEO_RING_STEP := 118.0
const GEO_MIN_GAP := 92.0

static var _cache := {}

## Усі вузли з геометрією: id -> {id, title, kind, effects, text, branch,
## ring, index, angle (градуси), parents: [id...]}.
static func nodes() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	for branch: String in NODES:
		var rings: Array = NODES[branch]
		var center_angle: float = BRANCHES[branch].angle
		var previous := []
		for r in rings.size():
			var ring: Array = rings[r]
			# Гілка — клин, що розширюється від центру, але не ширший за
			# ~56° (між гілками 72°): гілки не налазять одна на одну.
			var radius := GEO_RING_START + GEO_RING_STEP * r
			var spread := maxf(9.0 + 3.2 * r, rad_to_deg((ring.size() - 1) * GEO_MIN_GAP * 0.5 / radius))
			var placed := []
			for i in ring.size():
				var entry: Array = ring[i]
				var t := 0.0 if ring.size() == 1 else (float(i) / (ring.size() - 1) - 0.5)
				var angle := center_angle + t * spread * 2.0
				var node := {"id": entry[0], "title": entry[1], "kind": entry[2], "effects": entry[3], "text": entry[4],
					"branch": branch, "ring": r + 1, "index": i, "angle": angle, "parents": []}
				# Батьки: 1–2 найближчі за кутом у попередньому кільці.
				if not previous.is_empty():
					var sorted := previous.duplicate()
					sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
						return absf(a.angle - angle) < absf(b.angle - angle))
					node.parents.append(sorted[0].id)
					# Другий батько — лише коли він майже так само близько:
					# дерево читається гілками, а не павутиною ліній.
					if sorted.size() > 1 and absf(sorted[1].angle - angle) < absf(sorted[0].angle - angle) + 1.5:
						node.parents.append(sorted[1].id)
				if node.text == "":
					node.text = describe(node.effects)
				_cache[node.id] = node
				placed.append(node)
			previous = placed
	return _cache

static func get_node(id: String) -> Dictionary:
	return nodes().get(id, {})

## "+4% шкоди, +12 здоров'я" — опис малого вузла з його ефектів.
static func describe(effects: Dictionary) -> String:
	var parts := PackedStringArray()
	for key: String in effects:
		if ItemDb.STATS.has(key):
			var stat: Dictionary = ItemDb.STATS[key]
			parts.append("+%d%s %s" % [int(effects[key]), stat.suffix, String(stat.title).to_lower()])
		elif key == "damage_reduction":
			parts.append("-%d%% отриманої шкоди" % int(effects[key]))
	return ", ".join(parts)

static func learned() -> Dictionary:
	return GameState.talents

static func is_learned(id: String) -> bool:
	return GameState.talents.has(id)

## Скільки очок усього дано за рівні й скільки ще вільно.
static func points_total() -> int:
	return (GameState.hero_level - 1) * POINTS_PER_LEVEL + GameState.bonus_talent_points

static func points_free() -> int:
	return points_total() - GameState.talents.size()

## Чи можна вивчити: є очко, ще не вивчено, вивчено батька (або це
## перше кільце — воно біля центру).
static func can_learn(id: String) -> bool:
	var node := get_node(id)
	if node.is_empty() or is_learned(id) or points_free() <= 0:
		return false
	if int(node.ring) == 1:
		return true
	for parent: String in node.parents:
		if is_learned(parent):
			return true
	return false

static func is_reachable(id: String) -> bool:
	var node := get_node(id)
	if int(node.get("ring", 0)) == 1:
		return true
	for parent: String in node.get("parents", []):
		if is_learned(parent):
			return true
	return false

static func learn(id: String) -> bool:
	if not can_learn(id):
		return false
	GameState.talents[id] = 1
	GameState.talents_changed.emit()
	SaveManager.save_game()
	return true

static func reset_cost() -> int:
	var resets := GameState.talent_resets
	return 0 if resets == 0 else RESET_BASE_COST * int(pow(2, resets - 1))

## Скинути все: очки повертаються, наступне скидання дорожче.
static func reset() -> bool:
	var cost := reset_cost()
	if GameState.talents.is_empty() or GameState.gold < cost:
		return false
	GameState.gold -= cost
	GameState.talents = {}
	GameState.talent_resets += 1
	GameState.talents_changed.emit()
	SaveManager.save_game()
	return true

## Сума ефектів усіх вивчених вузлів (числа додаються; skill — список).
static func total_effects() -> Dictionary:
	var total := {}
	var skills := []
	for id: String in GameState.talents:
		var node := get_node(id)
		for key: String in node.get("effects", {}):
			var value: Variant = node.effects[key]
			if key == "skill":
				if skills.size() < MAX_TALENT_SKILLS and not skills.has(value):
					skills.append(value)
			else:
				total[key] = float(total.get(key, 0.0)) + float(value)
	total["skills"] = skills
	return total

## Скільки вузлів у кожній гілці вивчено — для підпису й "класу".
static func branch_progress() -> Dictionary:
	var counts := {}
	for id: String in GameState.talents:
		var branch := String(get_node(id).get("branch", ""))
		counts[branch] = int(counts.get(branch, 0)) + 1
	return counts
