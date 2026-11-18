extends RefCounted
class_name TalentTree

## ДЕРЕВО ТАЛАНТІВ — своя гілка в кожного класу: Мечник, Танк, Маг,
## Лучник, Друїд. Гілка працює ЛИШЕ зі зброєю свого класу в руках:
## мечник не чаклує, хоч би скільки очок вклав у мага.
##
## Гілка — шість ярусів. Ярус відкривається, коли в гілку вкладено
## TIER_POINTS очок (як у класичних деревах). Вузли мають ранги (1..5):
##   stat     — + до характеристики чи основного атрибута класу;
##   upgrade  — посилює конкретний прийом класу;
##   proc     — суперпасивка: спрацьовує з шансом або змінює бій;
##   super    — суперздібність: нова кнопка (ставиться в слот у
##              «Здібностях»; у бою — 1 удар, 2 здібності й перекат);
##   keystone — ключова: сильна, але з мінусом.
##
## Основні атрибути (TalentTree.ATTRIBUTES) перетворюються на числа бою:
## Сила мечника, Витривалість танка, Інтелект мага, Спритність лучника,
## Дух друїда.
##
## Очки: 2 за рівень (рівні 1..30). GameState.talents: id -> ранг.
## Скидання — перше безкоштовне, далі RESET_BASE_COST * 2^(n-1) золота.

const POINTS_PER_LEVEL := 2
const MAX_LEVEL := 30
const RESET_BASE_COST := 500
## Скільки очок треба вкласти в гілку, щоб відкрився ярус.
const TIER_POINTS := [0, 3, 7, 12, 18, 25]
## Слотів під здібності в бою.
const SKILL_SLOTS := 2

const CLASSES := {
	"knight": {"title": "Мечник", "color": Color(0.95, 0.38, 0.3), "icon": "tal_branch_knight", "attribute": "strength"},
	"tank": {"title": "Танк", "color": Color(0.5, 0.68, 1.0), "icon": "tal_branch_tank", "attribute": "stamina"},
	"mage": {"title": "Маг", "color": Color(0.7, 0.5, 1.0), "icon": "tal_branch_mage", "attribute": "intellect"},
	"archer": {"title": "Лучник", "color": Color(0.6, 0.92, 0.32), "icon": "tal_branch_archer", "attribute": "agility"},
	"druid": {"title": "Друїд", "color": Color(0.35, 0.88, 0.6), "icon": "tal_branch_druid", "attribute": "spirit"},
}
const CLASS_ORDER := ["knight", "tank", "mage", "archer", "druid"]
## Кругле дерево: напрям гілки (градуси) і геометрія кілець.
const BRANCH_ANGLES := {"knight": -90.0, "tank": -18.0, "druid": 54.0, "archer": 126.0, "mage": 198.0}
const GEO_RING_START := 250.0
const GEO_RING_STEP := 125.0
const GEO_MIN_GAP := 96.0

## Атрибут -> що дає одне очко атрибута.
const ATTRIBUTES := {
	"strength": {"title": "Сила", "gives": {"damage": 1.0, "hp": 1.0}, "text": "+1% шкоди й +1 здоров'я"},
	"stamina": {"title": "Витривалість", "gives": {"hp": 3.0, "armor": 0.6}, "text": "+3 здоров'я й +0.6 броні"},
	"intellect": {"title": "Інтелект", "gives": {"damage": 1.0, "mana": 1.5}, "text": "+1% сили чар і +1.5 мани"},
	"agility": {"title": "Спритність", "gives": {"attack_speed": 0.8, "crit": 0.3}, "text": "+0.8% швидкості атаки й +0.3% критичного удару"},
	"spirit": {"title": "Дух", "gives": {"damage": 0.8, "hp": 1.5, "regen": 0.1}, "text": "+0.8% шкоди, +1.5 здоров'я, +0.1 відновлення"},
}

## Прийоми класу: base — відкриті одразу, super — відкриває дерево.
## "staff" — особлива здібність посоха в руках (у кожного посоха своя).
## Друїд-людина лише перетворюється; прийоми — у звірів (fenrir, bear).
const CLASS_SKILLS := {
	"knight": {"base": ["whirlwind", "rage_dash"], "super": ["leap_slam", "battle_cry"]},
	"tank": {"base": ["shield_bash", "fortify"], "super": ["ground_fissure", "shield_ram"]},
	"mage": {"base": ["fire_ring", "staff"], "super": ["frost_nova", "moon_storm"]},
	"archer": {"base": ["arrow_volley", "piercing_shot"], "super": ["arrow_rain", "hunter_trap"]},
	"druid": {"base": ["bear_form", "fenrir_form"], "super": []},
	"fenrir": {"base": ["rend", "pounce"], "super": ["spirit_pack", "moon_howl"]},
	"bear": {"base": ["paw_swipe", "bear_charge"], "super": []},
}

## Гілки: ярус -> вузли [id, назва, тип, рангів, ефекти за ранг, опис, іконка].
## Порожній опис — збирається з ефектів. Ефекти power_<прийом> — % шкоди
## цього прийому, cd_<прийом> — % швидшої перезарядки.
const BRANCHES := {
	"knight": [
		[["k_str1", "Сила", "stat", 5, {"strength": 2}, "", "stat_damage"],
			["k_hp1", "Загартування", "stat", 3, {"hp": 6}, "", "stat_hp"],
			["k_as1", "Швидка рука", "stat", 3, {"attack_speed": 2}, "", "stat_attack_speed"]],
		[["k_whirl", "Буревій", "upgrade", 3, {"power_whirlwind": 15, "cd_whirlwind": 5}, "Вихор б'є на 15% сильніше й перезаряджається на 5% швидше за ранг.", "skill_whirlwind"],
			["k_dash", "Нестримний ривок", "upgrade", 3, {"power_rage_dash": 20}, "Ривок крізь ворогів завдає на 20% більше шкоди за ранг.", "skill_rage_dash"],
			["k_crit1", "Слабке місце", "stat", 3, {"crit": 2}, "", "stat_crit"]],
		[["k_double", "Подвійний удар", "proc", 3, {"double_strike": 6}, "Шанс 6% за ранг, що удар зброєю влучить двічі.", "tal_k_master"],
			["k_str2", "Сила велетня", "stat", 5, {"strength": 2}, "", "stat_damage"],
			["k_leech", "Спрага крові", "stat", 2, {"lifesteal": 2}, "2% завданої шкоди за ранг повертається здоров'ям.", "tal_k_lifesteal"]],
		[["k_leap", "Стрибок-удар", "super", 1, {"skill": "leap_slam"}, "СУПЕРЗДІБНІСТЬ: стрибаєш до ворогів і з розмаху б'єш об землю — шкода й оглушення довкола.", "tal_t_titan"],
			["k_bleed", "Кровопуск", "proc", 2, {"crit_bleed": 25}, "Критичний удар відкриває рану: ворог втрачає ще 25% за ранг від цієї шкоди за 3 секунди.", "tal_d_blood"],
			["k_heal", "Тріумф", "stat", 2, {"kill_heal": 1.5}, "Кожна перемога лікує 1.5% здоров'я за ранг.", "tal_k_killheal"]],
		[["k_cry", "Бойовий клич", "super", 1, {"skill": "battle_cry"}, "СУПЕРЗДІБНІСТЬ: могутній клич — 8 секунд +30% шкоди й +25% швидкості атаки, вороги поруч відлітають.", "tal_k_berserk"],
			["k_lowhp", "Лють загнаного", "stat", 2, {"low_hp_damage": 15}, "Нижче 35% здоров'я удари сильніші на 15% за ранг.", "tal_k_lowhp"],
			["k_exec", "Кат", "stat", 2, {"first_strike": 15}, "Удар по ворогу з повним здоров'ям сильніший на 15% за ранг.", "tal_k_execute"]],
		[["k_berserk", "Берсерк", "keystone", 1, {"berserk": 1}, "Чим менше здоров'я, тим швидше б'єш (до +40%), але броня вдвічі слабша.", "tal_k_berserk"],
			["k_legend", "Легенда арени", "stat", 1, {"damage": 10, "attack_speed": 6, "crit": 3}, "", "tal_k_critdmg"],
			["k_glass", "Скляна гармата", "keystone", 1, {"glass_cannon": 1}, "+35% шкоди, але на 20% менше здоров'я.", "tal_k_glass"]],
	],
	"tank": [
		[["t_sta1", "Витривалість", "stat", 5, {"stamina": 2}, "", "stat_hp"],
			["t_arm1", "Щільна шкура", "stat", 3, {"armor": 3}, "", "stat_armor"],
			["t_reg1", "Друге дихання", "stat", 2, {"regen": 1}, "", "tal_t_killheal"]],
		[["t_bash", "Важкий щит", "upgrade", 3, {"power_shield_bash": 20, "cd_shield_bash": 6}, "Удар щитом сильніший на 20% і перезаряджається на 6% швидше за ранг.", "skill_shield_bash"],
			["t_wall", "Непохитність", "upgrade", 2, {"fortify_time": 1.5, "power_fortify": 25}, "Стіна щитів триває на 1.5 с довше за ранг, поштовх сильніший.", "skill_fortify"],
			["t_dr1", "Стійкість", "stat", 3, {"damage_reduction": 2}, "", "tal_t_dr1"]],
		[["t_thorns", "Шипи", "proc", 3, {"thorns": 30}, "Коли тебе б'ють, найближчий ворог отримує у відповідь 30% твоєї шкоди за ранг.", "tal_t_stone"],
			["t_sta2", "Гранітна плоть", "stat", 5, {"stamina": 2}, "", "stat_hp"],
			["t_last", "Останній рубіж", "stat", 2, {"last_stand": 30}, "Нижче 35% здоров'я броня більша на 30% за ранг.", "tal_t_laststand"]],
		[["t_fissure", "Земний розлам", "super", 1, {"skill": "ground_fissure"}, "СУПЕРЗДІБНІСТЬ: б'єш щитом об землю — розлам біжить уперед, оглушуючи й ранячи всіх на лінії.", "tal_t_titan"],
			["t_counter", "Контрудар", "proc", 2, {"counter": 8}, "Шанс 8% за ранг: отримавши удар, одразу відповідаєш щитом усім поруч (шкода й оглушення).", "tal_t_dr4"],
			["t_potion", "Цілюще зілля", "stat", 2, {"potion_heal": 25}, "Зілля лікують на 25% сильніше за ранг.", "tal_t_potion"]],
		[["t_ram", "Таран щитом", "super", 1, {"skill": "shield_ram"}, "СУПЕРЗДІБНІСТЬ: мчиш уперед зі щитом, збиваючи й відкидаючи всіх на шляху; кого вріжеш — оглушено.", "tal_t_juggernaut"],
			["t_hp", "Тіло велетня", "stat", 3, {"hp": 12}, "", "stat_hp"],
			["t_kheal", "Рятівний удар", "stat", 2, {"kill_heal": 2}, "Кожна перемога лікує 2% здоров'я за ранг.", "tal_t_killheal"]],
		[["t_stone", "Кам'яна шкіра", "keystone", 1, {"stoneskin": 1}, "Броня +40% і здоров'я +10%, але рухаєшся на 12% повільніше.", "tal_t_stone"],
			["t_bastion", "Бастіон", "stat", 1, {"armor": 15, "hp": 30, "damage_reduction": 5}, "", "tal_t_bulwark"]],
	],
	"mage": [
		[["m_int1", "Інтелект", "stat", 5, {"intellect": 2}, "", "tal_book"],
			["m_mana1", "Запас мани", "stat", 3, {"mana": 8}, "", "tal_m_onhit"],
			["m_reg1", "Медитація", "stat", 2, {"mana_regen": 1}, "", "tal_m_onhit2"]],
		[["m_ring", "Пекельне коло", "upgrade", 3, {"power_fire_ring": 20}, "Вогняне коло палить на 20% сильніше за ранг.", "skill_fire_ring"],
			["m_staff", "Резонанс посоха", "upgrade", 3, {"staff_power": 15}, "Особлива здібність посоха сильніша на 15% за ранг.", "skill_arcane_barrage"],
			["m_cd1", "Знання рун", "stat", 3, {"cooldown": 3}, "", "skill_rune_charge"]],
		[["m_chain", "Ланцюгова блискавка", "proc", 3, {"chain_lightning": 6}, "Шанс 6% за ранг, що влучання чарами перескочить блискавкою ще на 3 ворогів.", "tal_m_storm"],
			["m_int2", "Мудрість віків", "stat", 5, {"intellect": 2}, "", "tal_book"],
			["m_onhit", "Живлення", "stat", 3, {"mana_on_hit": 1}, "", "tal_m_onhit"]],
		[["m_frost", "Крижана нова", "super", 1, {"skill": "frost_nova"}, "СУПЕРЗДІБНІСТЬ: вибух криги довкола заморожує й ранить ворогів.", "skill_frost_nova"],
			["m_overload", "Перевантаження", "proc", 1, {"overload": 1}, "Кожне п'яте закляття вилітає подвійним.", "tal_m_onhit2"],
			["m_crit", "Ясність", "stat", 3, {"crit": 2}, "", "stat_crit"]],
		[["m_moon", "Місячна буря", "super", 1, {"skill": "moon_storm"}, "СУПЕРЗДІБНІСТЬ: з неба падають місячні зорі на ворогів.", "skill_moon_storm"],
			["m_critdmg", "Тріщина реальності", "stat", 2, {"crit_damage": 15}, "Критичні чари сильніші на 15% за ранг.", "tal_m_critdmg"],
			["m_first", "Удар блискавки", "stat", 2, {"first_strike": 15}, "Перше влучання по свіжому ворогу сильніше на 15% за ранг.", "tal_m_first"]],
		[["m_shield", "Арканний щит", "keystone", 1, {"arcane_shield": 1}, "Половину шкоди по тобі забирає мана замість здоров'я.", "tal_m_shield"],
			["m_master", "Володар чар", "stat", 1, {"damage": 12, "cooldown": 8, "mana": 25}, "", "tal_m_master"],
			["m_blood", "Кровна магія", "keystone", 1, {"blood_magic": 1}, "Прийоми коштують здоров'я, а не ману; +15% здоров'я.", "tal_m_blood"]],
	],
	"archer": [
		[["a_agi1", "Спритність", "stat", 5, {"agility": 2}, "", "stat_attack_speed"],
			["a_dmg1", "Сила натягу", "stat", 3, {"damage": 3}, "", "stat_damage"],
			["a_move1", "Легкі ноги", "stat", 3, {"move_speed": 2}, "", "stat_speed"]],
		[["a_volley", "Широке віяло", "upgrade", 2, {"volley_extra": 2, "power_arrow_volley": 10}, "Віяло стріл: +2 стріли й +10% шкоди за ранг.", "skill_arrow_volley"],
			["a_pierce", "Вибухова стріла", "upgrade", 2, {"power_piercing_shot": 25, "cd_piercing_shot": 10}, "Пробивний постріл сильніший на 25% і перезаряджається на 10% швидше за ранг.", "skill_piercing_shot"],
			["a_crit1", "Влучність", "stat", 3, {"crit": 2}, "", "stat_crit"]],
		[["a_multi", "Мультипостріл", "proc", 3, {"multishot": 7}, "Шанс 7% за ранг, що з лука вилетить одразу три стріли.", "tal_a_first"],
			["a_agi2", "Котяча грація", "stat", 5, {"agility": 2}, "", "stat_attack_speed"],
			["a_dodge", "Відскок", "stat", 2, {"dodge_cooldown": 10}, "Перекат перезаряджається на 10% швидше за ранг.", "tal_a_dodge"]],
		[["a_rain", "Град стріл", "super", 1, {"skill": "arrow_rain"}, "СУПЕРЗДІБНІСТЬ: злива стріл падає з неба на ворогів довкола цілі.", "tal_branch_archer"],
			["a_eye", "Влучне око", "proc", 2, {"eagle_eye": 15}, "Постріли по ворогах далі за 7 м сильніші на 15% за ранг.", "tal_a_deadeye"],
			["a_hp", "Мисливська витривалість", "stat", 3, {"hp": 6}, "", "stat_hp"]],
		[["a_trap", "Пастка мисливця", "super", 1, {"skill": "hunter_trap"}, "СУПЕРЗДІБНІСТЬ: ставиш пастку — ворог, що наступить, сковується, а всіх поруч ранить вибух.", "tal_a_glass"],
			["a_critdmg", "Постріл у серце", "stat", 2, {"crit_damage": 15}, "Критичні постріли сильніші на 15% за ранг.", "tal_a_critdmg"],
			["a_gold", "Нюх скарбошукача", "stat", 2, {"gold_find": 10}, "+10% золота з ворогів за ранг.", "tal_a_gold"]],
		[["a_deadeye", "Мертве око", "keystone", 1, {"deadeye": 1}, "+8% критичного удару, критичні вдвічі сильніші, але без криту шкода менша на 15%.", "tal_a_deadeye"],
			["a_ghost", "Привид лісу", "stat", 1, {"move_speed": 6, "dodge_cooldown": 15, "attack_speed": 6}, "", "tal_a_ghost"],
			["a_legend", "Легенда лука", "stat", 1, {"damage": 10, "crit": 3, "attack_speed": 5}, "", "tal_a_legend"]],
	],
	"druid": [
		[["d_spi1", "Дух", "stat", 5, {"spirit": 2}, "", "tal_d_nature"],
			["d_arm1", "Шкура ведмедя", "stat", 3, {"armor": 3}, "", "stat_armor"],
			["d_reg1", "Шепіт лісу", "stat", 2, {"mana_regen": 1}, "", "tal_d_heal"]],
		[["d_bear", "Важка лапа", "upgrade", 3, {"power_paw_swipe": 15, "power_bear_charge": 15, "bear_hp": 8}, "Ведмідь: удари лапою й розбіг сильніші на 15%, здоров'я ведмедя +8% за ранг.", "skill_paw_swipe"],
			["d_fenrir", "Ненаситність Фенріра", "upgrade", 2, {"fenrir_stacks": 1, "power_rend": 15}, "Фенрір: серія укусів довша на 1 (до 7), Кровотік сильніший на 15% за ранг.", "skill_rend"],
			["d_as1", "Дикість", "stat", 3, {"attack_speed": 2}, "", "stat_attack_speed"]],
		[["d_beast", "Дух звіра", "proc", 3, {"beast_spirit": 8}, "У звірячій подобі +8% шкоди й +4% швидкості за ранг.", "tal_d_wild"],
			["d_spi2", "Серце лісу", "stat", 5, {"spirit": 2}, "", "tal_d_nature"],
			["d_leech", "Голод звіра", "stat", 2, {"lifesteal": 2}, "2% завданої шкоди за ранг повертається здоров'ям.", "tal_d_leech"]],
		[["d_pack", "Примарна зграя", "super", 1, {"skill": "spirit_pack"}, "СУПЕРЗДІБНІСТЬ ФЕНРІРА: кличе двох примарних вовків — 8 секунд вони кидаються на ворогів поруч.", "tal_d_alpha"],
			["d_regen", "Регенерація лісу", "stat", 2, {"regen": 1.5}, "", "tal_d_heal"],
			["d_potion", "Травник", "stat", 2, {"potion_heal": 25}, "Зілля лікують на 25% сильніше за ранг.", "tal_d_potion"]],
		[["d_howl", "Місячне виття", "super", 1, {"skill": "moon_howl"}, "СУПЕРЗДІБНІСТЬ ФЕНРІРА: виття під місяцем — вороги довкола в жаху завмирають і кровоточать.", "tal_d_ancient"],
			["d_kheal", "Кровожерність", "stat", 2, {"kill_heal": 2}, "Кожна перемога лікує 2% здоров'я за ранг.", "tal_k_killheal"],
			["d_fangs", "Ікла", "stat", 2, {"crit_damage": 15}, "Критичні удари сильніші на 15% за ранг.", "tal_d_leech"]],
		[["d_wild", "Дике серце", "keystone", 1, {"wild_heart": 1}, "+12% шкоди й броні, відновлення вдвічі сильніше, але мана відновлюється вдвічі повільніше.", "tal_d_ancient"],
			["d_alpha", "Альфа", "stat", 1, {"damage": 10, "hp": 20, "move_speed": 5}, "", "tal_d_alpha"]],
	],
}

static var _cache := {}

## Усі вузли: id -> {id, title, kind, max, effects, text, icon, branch,
## tier, index, ring, angle, parents}. ring/angle/parents — для круглого
## дерева: ярус = кільце від центру, батько — найближчий у ярусі нижче.
static func nodes() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	for branch: String in BRANCHES:
		var tiers: Array = BRANCHES[branch]
		var center_angle: float = BRANCH_ANGLES[branch]
		var previous := []
		for t in tiers.size():
			var radius := GEO_RING_START + GEO_RING_STEP * t
			var count: int = tiers[t].size()
			# Клин гілки не ширший за ±26° (між гілками 72°) — сусіди не налазять.
			var spread := minf(maxf(10.0 + 2.6 * t, rad_to_deg((count - 1) * GEO_MIN_GAP * 0.5 / radius)), 26.0)
			var placed := []
			for i in count:
				var entry: Array = tiers[t][i]
				var offset := 0.0 if count == 1 else (float(i) / (count - 1) - 0.5)
				var angle := center_angle + offset * spread * 2.0
				var node := {"id": entry[0], "title": entry[1], "kind": entry[2], "max": entry[3], "effects": entry[4],
					"text": entry[5], "icon": entry[6], "branch": branch, "tier": t, "index": i,
					"ring": t + 1, "angle": angle, "parents": []}
				if not previous.is_empty():
					var sorted := previous.duplicate()
					sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
						return absf(a.angle - angle) < absf(b.angle - angle))
					node.parents.append(sorted[0].id)
					if sorted.size() > 1 and absf(sorted[1].angle - angle) < absf(sorted[0].angle - angle) + 1.5:
						node.parents.append(sorted[1].id)
				if node.text == "":
					node.text = describe(node.effects) + (" за ранг" if int(node.max) > 1 else "")
				_cache[node.id] = node
				placed.append(node)
			previous = placed
	return _cache

static func get_node(id: String) -> Dictionary:
	return nodes().get(id, {})

static func branch_nodes(branch: String) -> Array:
	var result := []
	for id: String in nodes():
		if nodes()[id].branch == branch:
			result.append(nodes()[id])
	return result

## "+4% шкоди, +12 здоров'я" — опис вузла з його ефектів (за один ранг).
static func describe(effects: Dictionary) -> String:
	var parts := PackedStringArray()
	for key: String in effects:
		var value: float = float(effects[key])
		if ATTRIBUTES.has(key):
			parts.append("+%d %s" % [int(value), String(ATTRIBUTES[key].title).to_lower()])
		elif ItemDb.STATS.has(key):
			var stat: Dictionary = ItemDb.STATS[key]
			parts.append("+%s%s %s" % [_num(value), stat.suffix, String(stat.title).to_lower()])
		elif key == "damage_reduction":
			parts.append("-%d%% отриманої шкоди" % int(value))
		elif key == "lifesteal":
			parts.append("+%d%% вампіризму" % int(value))
	return ", ".join(parts)

static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

# --- ранги й очки ---

static func rank(id: String) -> int:
	return int(GameState.talents.get(id, 0)) if nodes().has(id) else 0

static func is_learned(id: String) -> bool:
	return rank(id) > 0

static func points_total() -> int:
	return (GameState.hero_level - 1) * POINTS_PER_LEVEL + GameState.bonus_talent_points

## Витрачені очки — лише на вузли, що є в дереві (старі сейви з іншими
## id нічого не з'їдають).
static func points_spent(branch: String = "") -> int:
	var total := 0
	for id: String in GameState.talents:
		var node := get_node(id)
		if node.is_empty():
			continue
		if branch == "" or node.branch == branch:
			total += int(GameState.talents[id])
	return total

static func points_free() -> int:
	return points_total() - points_spent()

static func tier_open(branch: String, tier: int) -> bool:
	return points_spent(branch) >= int(TIER_POINTS[mini(tier, TIER_POINTS.size() - 1)])

## Сусід ближче до центру вже вивчений (перше кільце — завжди).
static func parent_learned(id: String) -> bool:
	var node := get_node(id)
	if int(node.get("tier", 0)) == 0:
		return true
	for parent: String in node.get("parents", []):
		if is_learned(parent):
			return true
	return false

## Можна вчити: є очко, ще не максимальний ранг, ярус відкрито очками в
## гілці й вивчено сусіда ближче до центру.
static func can_learn(id: String) -> bool:
	var node := get_node(id)
	if node.is_empty() or points_free() <= 0 or rank(id) >= int(node.max):
		return false
	return tier_open(String(node.branch), int(node.tier)) and parent_learned(id)

## Чи вузол уже досяжний (без огляду на вільні очки) — для підсвітки.
static func is_reachable(id: String) -> bool:
	var node := get_node(id)
	return not node.is_empty() and tier_open(String(node.branch), int(node.tier)) and parent_learned(id)

static func learn(id: String) -> bool:
	if not can_learn(id):
		return false
	GameState.talents[id] = rank(id) + 1
	GameState.talents_changed.emit()
	SaveManager.save_game()
	return true

static func reset_cost() -> int:
	var resets := GameState.talent_resets
	return 0 if resets == 0 else RESET_BASE_COST * int(pow(2, resets - 1))

## Скинути все: очки повертаються, наступне скидання дорожче.
static func reset() -> bool:
	var cost := reset_cost()
	if points_spent() == 0 or GameState.gold < cost:
		return false
	GameState.gold -= cost
	GameState.talents = {}
	GameState.talent_resets += 1
	GameState.skill_loadout = {}
	GameState.talents_changed.emit()
	SaveManager.save_game()
	return true

# --- клас і ефекти ---

## Клас за зброєю в руках ("" — без зброї).
static func current_class() -> String:
	var weapon: Dictionary = ItemDb.equipped_items().get("weapon", {})
	return String(ItemDb.base_of(weapon).get("class", ""))

## Сума ефектів вивчених вузлів гілки branch (за замовчуванням — класу
## зброї в руках). Атрибути розкладаються на числа бою. skills — відкриті
## суперздібності гілки.
static func total_effects(branch: String = "*") -> Dictionary:
	if branch == "*":
		branch = current_class()
	var total := {}
	var skills := []
	for id: String in GameState.talents:
		var node := get_node(id)
		if node.is_empty() or node.branch != branch:
			continue
		var ranks := int(GameState.talents[id])
		for key: String in node.effects:
			var value: Variant = node.effects[key]
			if key == "skill":
				skills.append(String(value))
			else:
				total[key] = float(total.get(key, 0.0)) + float(value) * ranks
	for attribute: String in ATTRIBUTES:
		if total.has(attribute):
			var gives: Dictionary = ATTRIBUTES[attribute].gives
			for key: String in gives:
				total[key] = float(total.get(key, 0.0)) + float(gives[key]) * float(total[attribute])
	total["skills"] = skills
	return total

# --- здібності в слотах ---

## Усі прийоми набору (клас або звір): [{id, open}] — відкриті й закриті.
static func skill_pool(set_id: String, staff_skill: String = "") -> Array:
	var info: Dictionary = CLASS_SKILLS.get(set_id, {})
	var unlocked: Array = total_effects("druid" if set_id in ["fenrir", "bear"] else set_id).get("skills", [])
	var result := []
	for id: String in info.get("base", []):
		var real := staff_skill if id == "staff" else id
		if real != "":
			result.append({"id": real, "open": true})
	for id: String in info.get("super", []):
		result.append({"id": id, "open": unlocked.has(id)})
	return result

## Що стоїть у слотах (SKILL_SLOTS штук): збережений вибір гравця, а
## порожні чи закриті місця — заповнюються відкритими по черзі.
static func loadout(set_id: String, staff_skill: String = "") -> Array:
	var pool := skill_pool(set_id, staff_skill)
	var open := []
	for entry: Dictionary in pool:
		if entry.open:
			open.append(entry.id)
	var chosen: Array = GameState.skill_loadout.get(set_id, [])
	var result := []
	for id: String in chosen:
		if open.has(id) and not result.has(id) and result.size() < SKILL_SLOTS:
			result.append(id)
	for id: String in open:
		if result.size() >= SKILL_SLOTS:
			break
		if not result.has(id):
			result.append(id)
	return result

static func set_slot(set_id: String, slot: int, skill_id: String, staff_skill: String = "") -> void:
	var current := loadout(set_id, staff_skill)
	while current.size() < SKILL_SLOTS:
		current.append("")
	var other := current.find(skill_id)
	if other >= 0 and other != slot:
		current[other] = current[slot]
	current[slot] = skill_id
	GameState.skill_loadout[set_id] = current
	GameState.talents_changed.emit()
	SaveManager.save_game()
