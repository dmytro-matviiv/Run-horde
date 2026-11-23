extends RefCounted
class_name ItemDb

## ПРЕДМЕТИ: броня, зброя, прикраси.
##
## Заготовка (BASES) — що це за річ: слот, назва, з яких частин складається
## на персонажі (CharacterBuilder), до якого класу тяжіє, базові числа.
## Конкретна річ у торбі — словник:
##   {"uid": "i123", "base": "ranger_jacket", "rarity": "rare",
##    "stats": {"armor": 14, "hp": 22, "crit": 3}, "level": 1}
## Рідкість множить базові числа і додає випадкові властивості:
## сіра 0, зелена 1, синя 2, фіолетова 3, легендарна 4.
##
## Торба — GameState.inventory (масив речей), надіте —
## GameState.equipment (слот -> uid), скриня вдома — GameState.stash.

const SLOTS := ["helmet", "chest", "legs", "boots", "weapon", "amulet", "ring1", "ring2"]
const SLOT_TITLES := {"helmet": "Шолом", "chest": "Груди", "legs": "Штани", "boots": "Взуття", "weapon": "Зброя",
	"amulet": "Талісман", "ring1": "Кільце", "ring2": "Кільце"}
## Прикраси відкриваються з цього рівня.
const JEWELRY_LEVEL := 10

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_TITLES := {"common": "Звичайна", "uncommon": "Незвичайна", "rare": "Рідкісна", "epic": "Епічна", "legendary": "Легендарна"}
const RARITY_COLORS := {"common": Color(0.75, 0.75, 0.75), "uncommon": Color(0.45, 0.9, 0.4), "rare": Color(0.35, 0.65, 1.0),
	"epic": Color(0.75, 0.45, 1.0), "legendary": Color(1.0, 0.72, 0.2)}
const RARITY_POWER := {"common": 1.0, "uncommon": 1.25, "rare": 1.55, "epic": 1.9, "legendary": 2.4}
const RARITY_AFFIXES := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4}

## Характеристики: назва, одиниця, наскільки "добре" більше значення.
const STATS := {
	"hp": {"title": "Здоров'я", "suffix": "", "icon": "stat_hp"},
	"armor": {"title": "Броня", "suffix": "", "icon": "stat_armor"},
	"damage": {"title": "Шкода", "suffix": "%", "icon": "stat_damage"},
	"attack_speed": {"title": "Швидкість атаки", "suffix": "%", "icon": "stat_attack_speed"},
	"crit": {"title": "Критичний удар", "suffix": "%", "icon": "stat_crit"},
	"move_speed": {"title": "Швидкість руху", "suffix": "%", "icon": "stat_speed"},
	"mana": {"title": "Мана", "suffix": "", "icon": "boon_potion"},
	"mana_regen": {"title": "Відновлення мани", "suffix": "/с", "icon": "boon_potion"},
	"cooldown": {"title": "Перезарядка вмінь", "suffix": "%", "icon": "skill_rune_charge"},
	"regen": {"title": "Відновлення здоров'я", "suffix": "/с", "icon": "stat_hp"},
}
## Випадкові властивості: стат -> [мінімум, максимум] для сірої речі.
const AFFIX_RANGES := {
	"hp": [6, 14], "armor": [2, 5], "damage": [2, 5], "attack_speed": [2, 5], "crit": [1, 3],
	"move_speed": [1, 3], "mana": [6, 14], "mana_regen": [1, 2], "cooldown": [2, 4], "regen": [1, 2],
}

## Класи, до яких тяжіють речі (і дерево талантів).
const CLASSES := {"knight": "Мечник", "tank": "Танк", "mage": "Маг", "archer": "Лучник", "druid": "Друїд", "any": "Будь-хто"}

## Сети: id -> назва, клас, рідкість, речі, бонуси за 2/3/4 речі.
const SETS := {
	"knight_common": {"title": "Сет Мечника", "class": "knight", "rarity": "common", "pieces": ["knight_hood", "knight_coat", "knight_legs", "knight_boots"],
		"bonus": {2: {"damage": 5}, 3: {"crit": 3}, 4: {"double_strike": 6, "crit_bleed": 15}}, "look": "simple squire armor: steel nasal helmet, padded brown gambeson with a small steel pauldron, leather trousers with knee pads, brown leather boots"},
	"knight_uncommon": {"title": "Сет Вартового Брами", "class": "knight", "rarity": "uncommon", "pieces": ["knight_uncommon_helmet", "knight_uncommon_chest", "knight_uncommon_legs", "knight_uncommon_boots"],
		"bonus": {2: {"damage": 7.5}, 3: {"crit": 4.5}, 4: {"double_strike": 9, "crit_bleed": 22.5}}, "look": "town guard armor: open steel kettle helmet, chainmail shirt with a blue tabard, steel greaves over grey trousers, steel-capped boots"},
	"knight_rare": {"title": "Сет Сталевого Лева", "class": "knight", "rarity": "rare", "pieces": ["knight_rare_helmet", "knight_rare_chest", "knight_rare_legs", "knight_rare_boots"],
		"bonus": {2: {"damage": 10}, 3: {"crit": 6}, 4: {"double_strike": 12, "crit_bleed": 30}}, "look": "knight plate armor with gold lion engravings: great helm with a lion crest, polished steel breastplate with a golden lion emblem and red cloth, steel leg plates, armored sabatons"},
	"knight_epic": {"title": "Сет Кривавого Місяця", "class": "knight", "rarity": "epic", "pieces": ["knight_epic_helmet", "knight_epic_chest", "knight_epic_legs", "knight_epic_boots"],
		"bonus": {2: {"damage": 12.5}, 3: {"crit": 7.5}, 4: {"double_strike": 15, "crit_bleed": 37.5}}, "look": "dark crimson blood knight armor: horned black helmet with red visor glow, black and blood-red spiked breastplate with a red moon emblem, black plated legs with red trim, spiked black boots"},
	"knight_legendary": {"title": "Сет Короля Клинків", "class": "knight", "rarity": "legendary", "pieces": ["knight_legendary_helmet", "knight_legendary_chest", "knight_legendary_legs", "knight_legendary_boots"],
		"bonus": {2: {"damage": 15}, 3: {"crit": 9}, 4: {"double_strike": 18, "crit_bleed": 45}}, "look": "legendary golden king warrior armor: ornate golden crowned helmet with a white plume, gleaming gold and white breastplate with glowing blue gems, gold leg armor, gold winged boots, faint golden glow"},
	"tank_common": {"title": "Сет Вартового", "class": "tank", "rarity": "common", "pieces": ["tank_hood", "tank_coat", "tank_legs", "tank_boots"],
		"bonus": {2: {"armor": 6}, 3: {"hp": 20}, 4: {"thorns": 25, "damage_reduction": 3}}, "look": "simple sentinel armor: round iron helmet, thick padded vest with iron plates, padded trousers, heavy leather boots"},
	"tank_uncommon": {"title": "Сет Залізної Стіни", "class": "tank", "rarity": "uncommon", "pieces": ["tank_uncommon_helmet", "tank_uncommon_chest", "tank_uncommon_legs", "tank_uncommon_boots"],
		"bonus": {2: {"armor": 9}, 3: {"hp": 30}, 4: {"thorns": 37.5, "damage_reduction": 4.5}}, "look": "heavy iron wall armor: bucket great helm, thick riveted iron breastplate with big round pauldrons, iron leg plates, heavy iron boots"},
	"tank_rare": {"title": "Сет Кам'яного Бастіону", "class": "tank", "rarity": "rare", "pieces": ["tank_rare_helmet", "tank_rare_chest", "tank_rare_legs", "tank_rare_boots"],
		"bonus": {2: {"armor": 12}, 3: {"hp": 40}, 4: {"thorns": 50, "damage_reduction": 6}}, "look": "stone bastion armor made of grey stone-like plates with moss: blocky stone helmet, massive stone chest plate with rune carvings, stone leg guards, stone boots"},
	"tank_epic": {"title": "Сет Гірського Велетня", "class": "tank", "rarity": "epic", "pieces": ["tank_epic_helmet", "tank_epic_chest", "tank_epic_legs", "tank_epic_boots"],
		"bonus": {2: {"armor": 15}, 3: {"hp": 50}, 4: {"thorns": 62.5, "damage_reduction": 7.5}}, "look": "mountain giant armor: huge horned steel helm, massive dark blue steel breastplate with fur collar and spiked pauldrons, heavy blue steel legs, enormous armored boots"},
	"tank_legendary": {"title": "Сет Невмирущого Титана", "class": "tank", "rarity": "legendary", "pieces": ["tank_legendary_helmet", "tank_legendary_chest", "tank_legendary_legs", "tank_legendary_boots"],
		"bonus": {2: {"armor": 18}, 3: {"hp": 60}, 4: {"thorns": 75, "damage_reduction": 9}}, "look": "legendary immortal titan armor: golden titan helm with glowing eyes slit, colossal gold and bronze breastplate with a glowing sun core, golden leg plates, golden armored boots, divine glow"},
	"mage_common": {"title": "Сет Учня магії", "class": "mage", "rarity": "common", "pieces": ["mage_cowl", "mage_robe", "mage_pants", "mage_shoes"],
		"bonus": {2: {"mana": 15}, 3: {"cooldown": 4}, 4: {"chain_lightning": 5, "crit_damage": 10}}, "look": "apprentice mage robes: simple purple pointed hood, purple cloth robe with rope belt, purple cloth trousers, soft leather shoes"},
	"mage_uncommon": {"title": "Сет Зоряного Адепта", "class": "mage", "rarity": "uncommon", "pieces": ["mage_uncommon_helmet", "mage_uncommon_chest", "mage_uncommon_legs", "mage_uncommon_boots"],
		"bonus": {2: {"mana": 22.5}, 3: {"cooldown": 6}, 4: {"chain_lightning": 7.5, "crit_damage": 15}}, "look": "starry adept robes: deep blue wizard hat with silver stars, blue robe embroidered with stars and a silver sash, blue trousers, blue cloth shoes"},
	"mage_rare": {"title": "Сет Сапфірового Мага", "class": "mage", "rarity": "rare", "pieces": ["mage_rare_helmet", "mage_rare_chest", "mage_rare_legs", "mage_rare_boots"],
		"bonus": {2: {"mana": 30}, 3: {"cooldown": 8}, 4: {"chain_lightning": 10, "crit_damage": 20}}, "look": "sapphire mage outfit: tall white and sapphire hood with a crystal, white robe with sapphire panels and gold trim, white trousers, white boots with sapphire buckles"},
	"mage_epic": {"title": "Сет Вогню Безодні", "class": "mage", "rarity": "epic", "pieces": ["mage_epic_helmet", "mage_epic_chest", "mage_epic_legs", "mage_epic_boots"],
		"bonus": {2: {"mana": 37.5}, 3: {"cooldown": 10}, 4: {"chain_lightning": 12.5, "crit_damage": 25}}, "look": "abyssal fire warlock robes: black hood with burning orange runes, black and crimson robe with flame patterns, dark trousers with ember trim, black boots with fire glow"},
	"mage_legendary": {"title": "Сет Архімага Рун", "class": "mage", "rarity": "legendary", "pieces": ["mage_legendary_helmet", "mage_legendary_chest", "mage_legendary_legs", "mage_legendary_boots"],
		"bonus": {2: {"mana": 45}, 3: {"cooldown": 12}, 4: {"chain_lightning": 15, "crit_damage": 30}}, "look": "legendary archmage robes: ornate violet and gold archmage crown-hood with floating runes, rich violet robe with glowing golden runes and high collar, violet trousers with gold, golden embroidered boots, magical glow"},
	"archer_common": {"title": "Сет Стрільця", "class": "archer", "rarity": "common", "pieces": ["archer_hood", "archer_jacket", "archer_pants", "archer_boots"],
		"bonus": {2: {"attack_speed": 4}, 3: {"crit": 3}, 4: {"multishot": 5, "eagle_eye": 10}}, "look": "simple archer outfit: green cloth hood, green leather jerkin with quiver strap, brown leather trousers, soft leather boots"},
	"archer_uncommon": {"title": "Сет Лісового Слідопита", "class": "archer", "rarity": "uncommon", "pieces": ["archer_uncommon_helmet", "archer_uncommon_chest", "archer_uncommon_legs", "archer_uncommon_boots"],
		"bonus": {2: {"attack_speed": 6}, 3: {"crit": 4.5}, 4: {"multishot": 7.5, "eagle_eye": 15}}, "look": "forest ranger outfit: dark green hood with leaf pattern, green leather armor with leaf shoulder pads, brown trousers with leg wraps, tall forest boots"},
	"archer_rare": {"title": "Сет Яструбиного Ока", "class": "archer", "rarity": "rare", "pieces": ["archer_rare_helmet", "archer_rare_chest", "archer_rare_legs", "archer_rare_boots"],
		"bonus": {2: {"attack_speed": 8}, 3: {"crit": 6}, 4: {"multishot": 10, "eagle_eye": 20}}, "look": "hawk-eye hunter outfit: brown hood with hawk feathers, light brown leather armor with feather pauldrons, leather trousers, feathered boots"},
	"archer_epic": {"title": "Сет Грозового Мисливця", "class": "archer", "rarity": "epic", "pieces": ["archer_epic_helmet", "archer_epic_chest", "archer_epic_legs", "archer_epic_boots"],
		"bonus": {2: {"attack_speed": 10}, 3: {"crit": 7.5}, 4: {"multishot": 12.5, "eagle_eye": 25}}, "look": "storm hunter outfit: dark blue hood with lightning streaks, blue leather armor with silver lightning bolts, dark trousers, blue boots crackling with lightning"},
	"archer_legendary": {"title": "Сет Драконячого Вогню", "class": "archer", "rarity": "legendary", "pieces": ["archer_legendary_helmet", "archer_legendary_chest", "archer_legendary_legs", "archer_legendary_boots"],
		"bonus": {2: {"attack_speed": 12}, 3: {"crit": 9}, 4: {"multishot": 15, "eagle_eye": 30}}, "look": "legendary dragonfire archer outfit: red dragon-scale hood with small horns, red and gold dragon scale armor, scaled trousers, dragon claw boots, fiery glow"},
	"druid_common": {"title": "Сет Хранителя лісу", "class": "druid", "rarity": "common", "pieces": ["druid_hood", "druid_mantle", "druid_pants", "druid_boots"],
		"bonus": {2: {"hp": 15}, 3: {"regen": 1}, 4: {"beast_spirit": 6, "lifesteal": 2}}, "look": "simple forest keeper outfit: brown hood, earthy brown and green tunic with leaf sash, brown trousers, leather boots"},
	"druid_uncommon": {"title": "Сет Мохового Шамана", "class": "druid", "rarity": "uncommon", "pieces": ["druid_uncommon_helmet", "druid_uncommon_chest", "druid_uncommon_legs", "druid_uncommon_boots"],
		"bonus": {2: {"hp": 22.5}, 3: {"regen": 1.5}, 4: {"beast_spirit": 9, "lifesteal": 3}}, "look": "moss shaman outfit: hood covered in moss with small antlers, mossy green robe with wooden beads, green trousers, wrapped root boots"},
	"druid_rare": {"title": "Сет Терновий", "class": "druid", "rarity": "rare", "pieces": ["druid_rare_helmet", "druid_rare_chest", "druid_rare_legs", "druid_rare_boots"],
		"bonus": {2: {"hp": 30}, 3: {"regen": 2}, 4: {"beast_spirit": 12, "lifesteal": 4}}, "look": "thorn druid outfit: wooden helmet wrapped in thorny vines, bark armor with red thorns, bark leg guards, thorny vine boots"},
	"druid_epic": {"title": "Сет Місячного Вовка", "class": "druid", "rarity": "epic", "pieces": ["druid_epic_helmet", "druid_epic_chest", "druid_epic_legs", "druid_epic_boots"],
		"bonus": {2: {"hp": 37.5}, 3: {"regen": 2.5}, 4: {"beast_spirit": 15, "lifesteal": 5}}, "look": "moon wolf druid outfit: wolf skull hood with pale fur, grey fur and leather armor with moon crescent, fur trousers, wolf paw boots, pale blue glow"},
	"druid_legendary": {"title": "Сет Світового Дерева", "class": "druid", "rarity": "legendary", "pieces": ["druid_legendary_helmet", "druid_legendary_chest", "druid_legendary_legs", "druid_legendary_boots"],
		"bonus": {2: {"hp": 45}, 3: {"regen": 3}, 4: {"beast_spirit": 18, "lifesteal": 6}}, "look": "legendary world tree druid outfit: crown of golden branches and leaves, golden bark armor with glowing green leaves and a tiny tree, golden bark leg guards, root boots, nature glow"},
}

## Заготовки речей. parts — частини на персонажі (CharacterBuilder),
## base — числа сірої речі, class — до кого тяжіє.
const BASES := {
	"peasant_shirt": {"slot": "chest", "title": "Лляна сорочка", "parts": ["Peasant_Body", "Peasant_Arms"],
		"class": "any", "base": {"armor": 3, "hp": 8}},
	"ranger_jacket": {"slot": "chest", "title": "Шкіряна куртка", "parts": ["Ranger_Body", "Ranger_Arms"],
		"class": "archer", "base": {"armor": 6, "hp": 12, "attack_speed": 2}},
	"ranger_pauldron": {"slot": "chest", "title": "Куртка з наплічником", "parts": ["Ranger_Body", "Ranger_Arms", "Ranger_Acc_Pauldron"],
		"class": "knight", "base": {"armor": 9, "hp": 16}},
	"druid_robe": {"slot": "chest", "title": "Мантія мандрівника", "parts": ["Peasant_Body", "Ranger_Arms"],
		"class": "druid", "base": {"armor": 4, "hp": 10, "mana": 12}},
	"peasant_pants": {"slot": "legs", "title": "Лляні штани", "parts": ["Peasant_Legs"],
		"class": "any", "base": {"armor": 2, "hp": 6}},
	"ranger_pants": {"slot": "legs", "title": "Шкіряні штани", "parts": ["Ranger_Legs"],
		"class": "archer", "base": {"armor": 4, "hp": 9, "move_speed": 1}},
	"peasant_shoes": {"slot": "boots", "title": "Постоли", "parts": ["Peasant_Feet"],
		"class": "any", "base": {"armor": 1, "move_speed": 2}},
	"ranger_boots": {"slot": "boots", "title": "Чоботи слідопита", "parts": ["Ranger_Feet_Boots"],
		"class": "archer", "base": {"armor": 3, "move_speed": 3}},
	"ranger_hood": {"slot": "helmet", "title": "Каптур слідопита", "parts": ["Ranger_Head_Hood"],
		"class": "archer", "base": {"armor": 3, "crit": 2}},
	"mage_hood": {"slot": "helmet", "title": "Каптур чарівника", "parts": ["Ranger_Head_Hood"],
		"class": "mage", "base": {"armor": 2, "mana": 14, "cooldown": 2}},
	# --- ЗБРОЯ: у кожної своя рідкість (rarity) і з синьої — своє вміння
	# (unique: ефекти бою, ті самі ключі, що в талантах). weapon — шаблон
	# бою з WeaponPool (анімації, стиль); model — модель із
	# assets/models/weapons/items/<model>.scn; offhand — щит у ліву руку.
	# Мечник.
	"iron_sword": {"slot": "weapon", "title": "Залізний меч", "weapon": "war_blade", "model": "iron_sword", "class": "knight",
		"rarity": "common", "base": {"damage": 10}},
	"woodcutter_axe": {"slot": "weapon", "title": "Сокира лісоруба", "weapon": "war_blade", "model": "woodcutter_axe", "class": "knight",
		"rarity": "common", "base": {"damage": 11, "attack_speed": 2}},
	"steel_blade": {"slot": "weapon", "title": "Сталевий клинок", "weapon": "war_blade", "model": "steel_blade", "class": "knight",
		"rarity": "uncommon", "base": {"damage": 12, "crit": 2}},
	"talwar": {"slot": "weapon", "title": "Тальвар", "weapon": "talwar", "model": "talwar_blade", "class": "knight",
		"rarity": "uncommon", "base": {"damage": 12, "attack_speed": 3}},
	"battle_axe": {"slot": "weapon", "title": "Бойова сокира", "weapon": "battle_axe", "model": "battle_axe_m", "class": "knight",
		"rarity": "rare", "base": {"damage": 15}, "unique": {"double_strike": 8},
		"unique_text": "Шанс 8%, що удар влучить двічі."},
	"cleaver": {"slot": "weapon", "title": "Різник", "weapon": "cleaver", "model": "cleaver_m", "class": "knight",
		"rarity": "rare", "base": {"damage": 15, "crit": 2}, "unique": {"crit_bleed": 30},
		"unique_text": "Критичний удар відкриває рану: ворог втрачає ще 30% цієї шкоди за 3 с."},
	"great_sword": {"slot": "weapon", "title": "Дворучний меч героя", "weapon": "war_blade", "model": "great_sword", "class": "knight",
		"rarity": "rare", "base": {"damage": 16, "hp": 10}, "unique": {"first_strike": 30},
		"unique_text": "Удар по ворогу з повним здоров'ям сильніший на 30%."},
	"harpoon_glaive": {"slot": "weapon", "title": "Гарпун-глефа", "weapon": "harpoon_glaive", "model": "glaive_m", "class": "knight",
		"rarity": "epic", "base": {"damage": 18, "attack_speed": 3}, "unique": {"lifesteal": 5},
		"unique_text": "5% завданої шкоди повертається здоров'ям."},
	"twin_daggers": {"slot": "weapon", "title": "Парні клинки", "weapon": "twin_daggers", "model": "dagger_m", "class": "knight",
		"rarity": "epic", "base": {"damage": 16, "attack_speed": 6}, "unique": {"double_strike": 15},
		"unique_text": "Шанс 15% вдарити двічі."},
	"war_axe": {"slot": "weapon", "title": "Сокира Кривавого Місяця", "weapon": "war_blade", "model": "war_axe", "class": "knight",
		"rarity": "epic", "base": {"damage": 20}, "unique": {"low_hp_damage": 35, "crit_bleed": 25},
		"unique_text": "Нижче 35% здоров'я удари сильніші на 35%; крит відкриває рану."},
	"devils_axe": {"slot": "weapon", "title": "Диявольська сокира", "weapon": "devils_axe", "model": "devils_axe_m", "class": "knight",
		"rarity": "legendary", "base": {"damage": 24, "hp": 15}, "unique": {"lifesteal": 6, "double_strike": 12},
		"unique_text": "6% шкоди повертається здоров'ям, шанс 12% вдарити двічі."},
	"blade_storm": {"slot": "weapon", "title": "Буря клинків", "weapon": "blade_storm", "model": "blade_storm_m", "class": "knight",
		"rarity": "legendary", "base": {"damage": 22, "attack_speed": 8}, "unique": {"crit": 6, "crit_bleed": 40},
		"unique_text": "+6% криту; крит відкриває глибоку рану (40% шкоди за 3 с)."},
	# Танк (зброя + щит).
	"guard_sword": {"slot": "weapon", "title": "Меч і щит вартового", "weapon": "guard_sword", "model": "guard_blade", "offhand": "Shield_Wooden",
		"class": "tank", "rarity": "common", "base": {"damage": 7, "armor": 8, "hp": 15}},
	"guard_mace": {"slot": "weapon", "title": "Булава й гербовий щит", "weapon": "guard_sword", "model": "guard_mace", "offhand": "shield_kite",
		"class": "tank", "rarity": "uncommon", "base": {"damage": 8, "armor": 10, "hp": 18}},
	"tower_hammer": {"slot": "weapon", "title": "Молот і баштовий щит", "weapon": "guard_sword", "model": "tower_hammer", "offhand": "shield_tower",
		"class": "tank", "rarity": "rare", "base": {"damage": 9, "armor": 14, "hp": 24}, "unique": {"thorns": 40},
		"unique_text": "Коли тебе б'ють, найближчий ворог отримує 40% твоєї шкоди."},
	"knight_aegis": {"slot": "weapon", "title": "Клинок і Егіда лицаря", "weapon": "guard_sword", "model": "aegis_blade", "offhand": "shield_heraldic",
		"class": "tank", "rarity": "epic", "base": {"damage": 10, "armor": 18, "hp": 30}, "unique": {"counter": 12, "damage_reduction": 5},
		"unique_text": "Шанс 12% відповісти ударом щита всім поруч; −5% отриманої шкоди."},
	"mountain_bulwark": {"slot": "weapon", "title": "Молот Гори й Сонячний щит", "weapon": "guard_sword", "model": "bulwark_hammer", "offhand": "shield_round",
		"class": "tank", "rarity": "legendary", "base": {"damage": 12, "armor": 24, "hp": 40}, "unique": {"thorns": 60, "damage_reduction": 8, "kill_heal": 2},
		"unique_text": "Шипи 60%, −8% отриманої шкоди, кожна перемога лікує 2%."},
	# Маг.
	"apprentice_wand": {"slot": "weapon", "title": "Жезл учня", "weapon": "arcane_staff", "model": "apprentice_wand", "class": "mage",
		"rarity": "common", "base": {"damage": 7, "mana": 8}},
	"oak_staff": {"slot": "weapon", "title": "Дубовий посох", "weapon": "arcane_staff", "model": "oak_staff", "class": "mage",
		"rarity": "common", "base": {"damage": 8, "mana": 10}},
	"sapphire_staff": {"slot": "weapon", "title": "Сапфіровий посох", "weapon": "arcane_staff", "model": "sapphire_staff", "class": "mage",
		"rarity": "rare", "base": {"damage": 11, "mana": 16}, "unique": {"chain_lightning": 8},
		"unique_text": "Шанс 8%, що закляття перескочить блискавкою ще на 3 ворогів."},
	"ice_staff": {"slot": "weapon", "title": "Крижаний посох", "weapon": "ice_staff", "model": "ice_staff_m", "class": "mage",
		"rarity": "rare", "base": {"damage": 11, "mana": 14, "cooldown": 4}, "unique": {"cooldown": 8},
		"unique_text": "Прийоми перезаряджаються на 8% швидше."},
	"venom_staff": {"slot": "weapon", "title": "Посох трясовини", "weapon": "venom_staff", "model": "venom_staff_m", "class": "mage",
		"rarity": "epic", "base": {"damage": 13, "mana": 18}, "unique": {"overload": 1},
		"unique_text": "Кожне п'яте закляття вилітає подвійним."},
	"moon_staff": {"slot": "weapon", "title": "Місячний посох", "weapon": "moon_staff", "model": "moon_staff_m", "class": "mage",
		"rarity": "legendary", "base": {"damage": 16, "mana": 24}, "unique": {"chain_lightning": 12, "crit_damage": 30},
		"unique_text": "Ланцюгова блискавка 12%, критичні чари сильніші на 30%."},
	# Лучник.
	"hunter_bow": {"slot": "weapon", "title": "Мисливський лук", "weapon": "hunter_bow", "model": "hunter_bow", "class": "archer",
		"rarity": "common", "base": {"damage": 9, "crit": 2}},
	"ash_bow": {"slot": "weapon", "title": "Ясеневий лук", "weapon": "hunter_bow", "model": "ash_bow", "class": "archer",
		"rarity": "uncommon", "base": {"damage": 10, "crit": 4}},
	"hawk_bow": {"slot": "weapon", "title": "Лук Яструба", "weapon": "hunter_bow", "model": "hawk_bow", "class": "archer",
		"rarity": "rare", "base": {"damage": 12, "crit": 4}, "unique": {"multishot": 8},
		"unique_text": "Шанс 8%, що вилетить одразу три стріли."},
	"storm_bow": {"slot": "weapon", "title": "Грозовий лук", "weapon": "hunter_bow", "model": "storm_bow", "class": "archer",
		"rarity": "epic", "base": {"damage": 14, "attack_speed": 5}, "unique": {"multishot": 12, "eagle_eye": 20},
		"unique_text": "Мультипостріл 12%; постріли далі за 7 м сильніші на 20%."},
	"dragon_bow": {"slot": "weapon", "title": "Лук Драконячого Вогню", "weapon": "hunter_bow", "model": "dragon_bow", "class": "archer",
		"rarity": "legendary", "base": {"damage": 17, "attack_speed": 8, "crit": 4}, "unique": {"multishot": 15, "crit_bleed": 30},
		"unique_text": "Мультипостріл 15%; крит підпалює рану (30% шкоди за 3 с)."},
	# Друїд.
	"grove_staff": {"slot": "weapon", "title": "Посох гаю", "weapon": "druid_staff", "model": "grove_staff", "class": "druid",
		"rarity": "common", "base": {"damage": 7, "hp": 8, "mana": 10}},
	"druid_staff": {"slot": "weapon", "title": "Посох друїда", "weapon": "druid_staff", "model": "venom_staff_m", "class": "druid",
		"rarity": "uncommon", "base": {"damage": 8, "hp": 10, "mana": 12}},
	"thorn_staff": {"slot": "weapon", "title": "Терновий посох", "weapon": "druid_staff", "model": "thorn_staff", "class": "druid",
		"rarity": "rare", "base": {"damage": 10, "hp": 14, "mana": 14}, "unique": {"beast_spirit": 10},
		"unique_text": "У звірячій подобі +10% шкоди й +5% швидкості."},
	"moonwolf_staff": {"slot": "weapon", "title": "Посох Місячного Вовка", "weapon": "druid_staff", "model": "moonwolf_staff", "class": "druid",
		"rarity": "epic", "base": {"damage": 12, "hp": 18, "mana": 18}, "unique": {"fenrir_stacks": 2, "beast_spirit": 10},
		"unique_text": "Серія укусів Фенріра довша на 2; дух звіра +10%."},
	"world_tree_staff": {"slot": "weapon", "title": "Посох Світового Дерева", "weapon": "druid_staff", "model": "world_tree_staff", "class": "druid",
		"rarity": "legendary", "base": {"damage": 15, "hp": 25, "mana": 24}, "unique": {"beast_spirit": 20, "lifesteal": 5, "bear_hp": 15},
		"unique_text": "Дух звіра +20%, вампіризм 5%, ведмідь міцніший на 15%."},
	# --- Стартові сети класів (Наставниця Дарина) ---
	# set — назва сету (пізніше: бонуси за 2/3/4 речі), tint — свій колір
	# сету поверх рідкості, icon — картинка з наявних, поки немає своєї.
	"knight_hood": {"slot": "helmet", "title": "Шолом мечника", "parts": ["Sword1_Head"], "class": "knight",
		"set": "knight_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_hood", "base": {"armor": 3, "hp": 6, "damage": 2}},
	"knight_coat": {"slot": "chest", "title": "Стьобанка мечника", "parts": ["Sword1_Body"],
		"class": "knight", "set": "knight_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_pauldron", "base": {"armor": 8, "hp": 14, "damage": 3}},
	"knight_legs": {"slot": "legs", "title": "Штани мечника з наколінниками", "parts": ["Sword1_Legs"], "class": "knight",
		"set": "knight_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_pants", "base": {"armor": 5, "hp": 8}},
	"knight_boots": {"slot": "boots", "title": "Чоботи мечника", "parts": ["Sword1_Feet"], "class": "knight",
		"set": "knight_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_boots", "base": {"armor": 3, "move_speed": 2, "attack_speed": 2}},
	"tank_hood": {"slot": "helmet", "title": "Залізний шолом вартового", "parts": ["Tank1_Head"], "class": "tank",
		"set": "tank_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_hood", "base": {"armor": 5, "hp": 12}},
	"tank_coat": {"slot": "chest", "title": "Латна куртка вартового", "parts": ["Tank1_Body"],
		"class": "tank", "set": "tank_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_pauldron", "base": {"armor": 12, "hp": 24}},
	"tank_legs": {"slot": "legs", "title": "Важкі поножі вартового", "parts": ["Tank1_Legs"], "class": "tank",
		"set": "tank_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_pants", "base": {"armor": 8, "hp": 14}},
	"tank_boots": {"slot": "boots", "title": "Окуті чоботи вартового", "parts": ["Tank1_Feet"], "class": "tank",
		"set": "tank_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_boots", "base": {"armor": 5, "hp": 6}},
	"mage_cowl": {"slot": "helmet", "title": "Каптур учня магії", "parts": ["Mage1_Head"], "class": "mage",
		"set": "mage_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_mage_hood", "base": {"armor": 2, "mana": 14, "cooldown": 2}},
	"mage_robe": {"slot": "chest", "title": "Мантія учня магії", "parts": ["Mage1_Body"], "class": "mage",
		"set": "mage_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_druid_robe", "base": {"armor": 3, "mana": 16, "mana_regen": 1}},
	"mage_pants": {"slot": "legs", "title": "Шаровари учня магії", "parts": ["Mage1_Legs"], "class": "mage",
		"set": "mage_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_peasant_pants", "base": {"armor": 2, "mana": 10}},
	"mage_shoes": {"slot": "boots", "title": "Черевики учня магії", "parts": ["Mage1_Feet"], "class": "mage",
		"set": "mage_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_peasant_shoes", "base": {"armor": 1, "move_speed": 2, "mana": 6}},
	"archer_hood": {"slot": "helmet", "title": "Каптур стрільця", "parts": ["Archer1_Head"], "class": "archer",
		"set": "archer_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_hood", "base": {"armor": 3, "crit": 2}},
	"archer_jacket": {"slot": "chest", "title": "Куртка стрільця", "parts": ["Archer1_Body"], "class": "archer",
		"set": "archer_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_jacket", "base": {"armor": 5, "hp": 8, "attack_speed": 3}},
	"archer_pants": {"slot": "legs", "title": "Штани стрільця", "parts": ["Archer1_Legs"], "class": "archer",
		"set": "archer_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_pants", "base": {"armor": 4, "hp": 6, "move_speed": 1}},
	"archer_boots": {"slot": "boots", "title": "Чоботи стрільця", "parts": ["Archer1_Feet"], "class": "archer",
		"set": "archer_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_boots", "base": {"armor": 3, "move_speed": 3}},
	"druid_hood": {"slot": "helmet", "title": "Каптур хранителя лісу", "parts": ["Druid1_Head"], "class": "druid",
		"set": "druid_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_hood", "base": {"armor": 3, "hp": 6, "mana": 8}},
	"druid_mantle": {"slot": "chest", "title": "Мантія хранителя лісу", "parts": ["Druid1_Body"], "class": "druid",
		"set": "druid_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_druid_robe", "base": {"armor": 6, "hp": 12, "mana": 12}},
	"druid_pants": {"slot": "legs", "title": "Штани хранителя лісу", "parts": ["Druid1_Legs"], "class": "druid",
		"set": "druid_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_peasant_pants", "base": {"armor": 4, "hp": 8}},
	"druid_boots": {"slot": "boots", "title": "Чоботи хранителя лісу", "parts": ["Druid1_Feet"], "class": "druid",
		"set": "druid_common", "rarity": "common", "tint": Color.WHITE, "icon": "item_ranger_boots", "base": {"armor": 2, "move_speed": 2, "regen": 1}},
	# --- Сети класів, рідкості від зеленої до легендарної (генеровано) ---
	"knight_uncommon_helmet": {"slot": "helmet", "title": "Шолом Вартового Брами", "parts": ["Ranger_Head_Hood"], "class": "knight",
		"set": "knight_uncommon", "rarity": "uncommon", "tint": Color(0.85, 0.95, 1.1), "base": {"armor": 3, "hp": 6, "damage": 2}},
	"knight_uncommon_chest": {"slot": "chest", "title": "Нагрудник Вартового Брами", "parts": ["Ranger_Body", "Ranger_Arms", "Ranger_Acc_Pauldron"], "class": "knight",
		"set": "knight_uncommon", "rarity": "uncommon", "tint": Color(0.85, 0.95, 1.1), "base": {"armor": 8, "hp": 14, "damage": 3}},
	"knight_uncommon_legs": {"slot": "legs", "title": "Поножі Вартового Брами", "parts": ["Ranger_Legs"], "class": "knight",
		"set": "knight_uncommon", "rarity": "uncommon", "tint": Color(0.85, 0.95, 1.1), "base": {"armor": 5, "hp": 8}},
	"knight_uncommon_boots": {"slot": "boots", "title": "Чоботи Вартового Брами", "parts": ["Ranger_Feet_Boots"], "class": "knight",
		"set": "knight_uncommon", "rarity": "uncommon", "tint": Color(0.85, 0.95, 1.1), "base": {"armor": 3, "move_speed": 2, "attack_speed": 2}},
	"knight_rare_helmet": {"slot": "helmet", "title": "Шолом Сталевого Лева", "parts": ["Ranger_Head_Hood"], "class": "knight",
		"set": "knight_rare", "rarity": "rare", "tint": Color(1.1, 1.0, 0.8), "base": {"armor": 3, "hp": 6, "damage": 2}},
	"knight_rare_chest": {"slot": "chest", "title": "Нагрудник Сталевого Лева", "parts": ["Ranger_Body", "Ranger_Arms", "Ranger_Acc_Pauldron"], "class": "knight",
		"set": "knight_rare", "rarity": "rare", "tint": Color(1.1, 1.0, 0.8), "base": {"armor": 8, "hp": 14, "damage": 3}},
	"knight_rare_legs": {"slot": "legs", "title": "Поножі Сталевого Лева", "parts": ["Ranger_Legs"], "class": "knight",
		"set": "knight_rare", "rarity": "rare", "tint": Color(1.1, 1.0, 0.8), "base": {"armor": 5, "hp": 8}},
	"knight_rare_boots": {"slot": "boots", "title": "Чоботи Сталевого Лева", "parts": ["Ranger_Feet_Boots"], "class": "knight",
		"set": "knight_rare", "rarity": "rare", "tint": Color(1.1, 1.0, 0.8), "base": {"armor": 3, "move_speed": 2, "attack_speed": 2}},
	"knight_epic_helmet": {"slot": "helmet", "title": "Шолом Кривавого Місяця", "parts": ["Ranger_Head_Hood"], "class": "knight",
		"set": "knight_epic", "rarity": "epic", "tint": Color(1.15, 0.6, 0.6), "base": {"armor": 3, "hp": 6, "damage": 2}},
	"knight_epic_chest": {"slot": "chest", "title": "Нагрудник Кривавого Місяця", "parts": ["Ranger_Body", "Ranger_Arms", "Ranger_Acc_Pauldron"], "class": "knight",
		"set": "knight_epic", "rarity": "epic", "tint": Color(1.15, 0.6, 0.6), "base": {"armor": 8, "hp": 14, "damage": 3}},
	"knight_epic_legs": {"slot": "legs", "title": "Поножі Кривавого Місяця", "parts": ["Ranger_Legs"], "class": "knight",
		"set": "knight_epic", "rarity": "epic", "tint": Color(1.15, 0.6, 0.6), "base": {"armor": 5, "hp": 8}},
	"knight_epic_boots": {"slot": "boots", "title": "Чоботи Кривавого Місяця", "parts": ["Ranger_Feet_Boots"], "class": "knight",
		"set": "knight_epic", "rarity": "epic", "tint": Color(1.15, 0.6, 0.6), "base": {"armor": 3, "move_speed": 2, "attack_speed": 2}},
	"knight_legendary_helmet": {"slot": "helmet", "title": "Шолом Короля Клинків", "parts": ["Ranger_Head_Hood"], "class": "knight",
		"set": "knight_legendary", "rarity": "legendary", "tint": Color(1.2, 1.05, 0.7), "base": {"armor": 3, "hp": 6, "damage": 2}},
	"knight_legendary_chest": {"slot": "chest", "title": "Нагрудник Короля Клинків", "parts": ["Ranger_Body", "Ranger_Arms", "Ranger_Acc_Pauldron"], "class": "knight",
		"set": "knight_legendary", "rarity": "legendary", "tint": Color(1.2, 1.05, 0.7), "base": {"armor": 8, "hp": 14, "damage": 3}},
	"knight_legendary_legs": {"slot": "legs", "title": "Поножі Короля Клинків", "parts": ["Ranger_Legs"], "class": "knight",
		"set": "knight_legendary", "rarity": "legendary", "tint": Color(1.2, 1.05, 0.7), "base": {"armor": 5, "hp": 8}},
	"knight_legendary_boots": {"slot": "boots", "title": "Чоботи Короля Клинків", "parts": ["Ranger_Feet_Boots"], "class": "knight",
		"set": "knight_legendary", "rarity": "legendary", "tint": Color(1.2, 1.05, 0.7), "base": {"armor": 3, "move_speed": 2, "attack_speed": 2}},
	"tank_uncommon_helmet": {"slot": "helmet", "title": "Шолом Залізної Стіни", "parts": ["Ranger_Head_Hood"], "class": "tank",
		"set": "tank_uncommon", "rarity": "uncommon", "tint": Color(0.8, 0.85, 0.95), "base": {"armor": 5, "hp": 12}},
	"tank_uncommon_chest": {"slot": "chest", "title": "Нагрудник Залізної Стіни", "parts": ["Ranger_Body", "Ranger_Arms", "Ranger_Acc_Pauldron"], "class": "tank",
		"set": "tank_uncommon", "rarity": "uncommon", "tint": Color(0.8, 0.85, 0.95), "base": {"armor": 12, "hp": 24}},
	"tank_uncommon_legs": {"slot": "legs", "title": "Поножі Залізної Стіни", "parts": ["Ranger_Legs"], "class": "tank",
		"set": "tank_uncommon", "rarity": "uncommon", "tint": Color(0.8, 0.85, 0.95), "base": {"armor": 8, "hp": 14}},
	"tank_uncommon_boots": {"slot": "boots", "title": "Чоботи Залізної Стіни", "parts": ["Ranger_Feet_Boots"], "class": "tank",
		"set": "tank_uncommon", "rarity": "uncommon", "tint": Color(0.8, 0.85, 0.95), "base": {"armor": 5, "hp": 6}},
	"tank_rare_helmet": {"slot": "helmet", "title": "Шолом Кам'яного Бастіону", "parts": ["Ranger_Head_Hood"], "class": "tank",
		"set": "tank_rare", "rarity": "rare", "tint": Color(0.85, 0.82, 0.75), "base": {"armor": 5, "hp": 12}},
	"tank_rare_chest": {"slot": "chest", "title": "Нагрудник Кам'яного Бастіону", "parts": ["Ranger_Body", "Ranger_Arms", "Ranger_Acc_Pauldron"], "class": "tank",
		"set": "tank_rare", "rarity": "rare", "tint": Color(0.85, 0.82, 0.75), "base": {"armor": 12, "hp": 24}},
	"tank_rare_legs": {"slot": "legs", "title": "Поножі Кам'яного Бастіону", "parts": ["Ranger_Legs"], "class": "tank",
		"set": "tank_rare", "rarity": "rare", "tint": Color(0.85, 0.82, 0.75), "base": {"armor": 8, "hp": 14}},
	"tank_rare_boots": {"slot": "boots", "title": "Чоботи Кам'яного Бастіону", "parts": ["Ranger_Feet_Boots"], "class": "tank",
		"set": "tank_rare", "rarity": "rare", "tint": Color(0.85, 0.82, 0.75), "base": {"armor": 5, "hp": 6}},
	"tank_epic_helmet": {"slot": "helmet", "title": "Шолом Гірського Велетня", "parts": ["Ranger_Head_Hood"], "class": "tank",
		"set": "tank_epic", "rarity": "epic", "tint": Color(0.75, 0.9, 1.15), "base": {"armor": 5, "hp": 12}},
	"tank_epic_chest": {"slot": "chest", "title": "Нагрудник Гірського Велетня", "parts": ["Ranger_Body", "Ranger_Arms", "Ranger_Acc_Pauldron"], "class": "tank",
		"set": "tank_epic", "rarity": "epic", "tint": Color(0.75, 0.9, 1.15), "base": {"armor": 12, "hp": 24}},
	"tank_epic_legs": {"slot": "legs", "title": "Поножі Гірського Велетня", "parts": ["Ranger_Legs"], "class": "tank",
		"set": "tank_epic", "rarity": "epic", "tint": Color(0.75, 0.9, 1.15), "base": {"armor": 8, "hp": 14}},
	"tank_epic_boots": {"slot": "boots", "title": "Чоботи Гірського Велетня", "parts": ["Ranger_Feet_Boots"], "class": "tank",
		"set": "tank_epic", "rarity": "epic", "tint": Color(0.75, 0.9, 1.15), "base": {"armor": 5, "hp": 6}},
	"tank_legendary_helmet": {"slot": "helmet", "title": "Шолом Невмирущого Титана", "parts": ["Ranger_Head_Hood"], "class": "tank",
		"set": "tank_legendary", "rarity": "legendary", "tint": Color(1.15, 0.95, 0.7), "base": {"armor": 5, "hp": 12}},
	"tank_legendary_chest": {"slot": "chest", "title": "Нагрудник Невмирущого Титана", "parts": ["Ranger_Body", "Ranger_Arms", "Ranger_Acc_Pauldron"], "class": "tank",
		"set": "tank_legendary", "rarity": "legendary", "tint": Color(1.15, 0.95, 0.7), "base": {"armor": 12, "hp": 24}},
	"tank_legendary_legs": {"slot": "legs", "title": "Поножі Невмирущого Титана", "parts": ["Ranger_Legs"], "class": "tank",
		"set": "tank_legendary", "rarity": "legendary", "tint": Color(1.15, 0.95, 0.7), "base": {"armor": 8, "hp": 14}},
	"tank_legendary_boots": {"slot": "boots", "title": "Чоботи Невмирущого Титана", "parts": ["Ranger_Feet_Boots"], "class": "tank",
		"set": "tank_legendary", "rarity": "legendary", "tint": Color(1.15, 0.95, 0.7), "base": {"armor": 5, "hp": 6}},
	"mage_uncommon_helmet": {"slot": "helmet", "title": "Шолом Зоряного Адепта", "parts": ["Ranger_Head_Hood"], "class": "mage",
		"set": "mage_uncommon", "rarity": "uncommon", "tint": Color(0.6, 0.75, 1.15), "base": {"armor": 2, "mana": 14, "cooldown": 2}},
	"mage_uncommon_chest": {"slot": "chest", "title": "Нагрудник Зоряного Адепта", "parts": ["Peasant_Body", "Ranger_Arms"], "class": "mage",
		"set": "mage_uncommon", "rarity": "uncommon", "tint": Color(0.6, 0.75, 1.15), "base": {"armor": 3, "mana": 16, "mana_regen": 1}},
	"mage_uncommon_legs": {"slot": "legs", "title": "Поножі Зоряного Адепта", "parts": ["Peasant_Legs"], "class": "mage",
		"set": "mage_uncommon", "rarity": "uncommon", "tint": Color(0.6, 0.75, 1.15), "base": {"armor": 2, "mana": 10}},
	"mage_uncommon_boots": {"slot": "boots", "title": "Чоботи Зоряного Адепта", "parts": ["Peasant_Feet"], "class": "mage",
		"set": "mage_uncommon", "rarity": "uncommon", "tint": Color(0.6, 0.75, 1.15), "base": {"armor": 1, "move_speed": 2, "mana": 6}},
	"mage_rare_helmet": {"slot": "helmet", "title": "Шолом Сапфірового Мага", "parts": ["Ranger_Head_Hood"], "class": "mage",
		"set": "mage_rare", "rarity": "rare", "tint": Color(0.75, 0.85, 1.2), "base": {"armor": 2, "mana": 14, "cooldown": 2}},
	"mage_rare_chest": {"slot": "chest", "title": "Нагрудник Сапфірового Мага", "parts": ["Peasant_Body", "Ranger_Arms"], "class": "mage",
		"set": "mage_rare", "rarity": "rare", "tint": Color(0.75, 0.85, 1.2), "base": {"armor": 3, "mana": 16, "mana_regen": 1}},
	"mage_rare_legs": {"slot": "legs", "title": "Поножі Сапфірового Мага", "parts": ["Peasant_Legs"], "class": "mage",
		"set": "mage_rare", "rarity": "rare", "tint": Color(0.75, 0.85, 1.2), "base": {"armor": 2, "mana": 10}},
	"mage_rare_boots": {"slot": "boots", "title": "Чоботи Сапфірового Мага", "parts": ["Peasant_Feet"], "class": "mage",
		"set": "mage_rare", "rarity": "rare", "tint": Color(0.75, 0.85, 1.2), "base": {"armor": 1, "move_speed": 2, "mana": 6}},
	"mage_epic_helmet": {"slot": "helmet", "title": "Шолом Вогню Безодні", "parts": ["Ranger_Head_Hood"], "class": "mage",
		"set": "mage_epic", "rarity": "epic", "tint": Color(1.2, 0.65, 0.5), "base": {"armor": 2, "mana": 14, "cooldown": 2}},
	"mage_epic_chest": {"slot": "chest", "title": "Нагрудник Вогню Безодні", "parts": ["Peasant_Body", "Ranger_Arms"], "class": "mage",
		"set": "mage_epic", "rarity": "epic", "tint": Color(1.2, 0.65, 0.5), "base": {"armor": 3, "mana": 16, "mana_regen": 1}},
	"mage_epic_legs": {"slot": "legs", "title": "Поножі Вогню Безодні", "parts": ["Peasant_Legs"], "class": "mage",
		"set": "mage_epic", "rarity": "epic", "tint": Color(1.2, 0.65, 0.5), "base": {"armor": 2, "mana": 10}},
	"mage_epic_boots": {"slot": "boots", "title": "Чоботи Вогню Безодні", "parts": ["Peasant_Feet"], "class": "mage",
		"set": "mage_epic", "rarity": "epic", "tint": Color(1.2, 0.65, 0.5), "base": {"armor": 1, "move_speed": 2, "mana": 6}},
	"mage_legendary_helmet": {"slot": "helmet", "title": "Шолом Архімага Рун", "parts": ["Ranger_Head_Hood"], "class": "mage",
		"set": "mage_legendary", "rarity": "legendary", "tint": Color(1.0, 0.9, 1.25), "base": {"armor": 2, "mana": 14, "cooldown": 2}},
	"mage_legendary_chest": {"slot": "chest", "title": "Нагрудник Архімага Рун", "parts": ["Peasant_Body", "Ranger_Arms"], "class": "mage",
		"set": "mage_legendary", "rarity": "legendary", "tint": Color(1.0, 0.9, 1.25), "base": {"armor": 3, "mana": 16, "mana_regen": 1}},
	"mage_legendary_legs": {"slot": "legs", "title": "Поножі Архімага Рун", "parts": ["Peasant_Legs"], "class": "mage",
		"set": "mage_legendary", "rarity": "legendary", "tint": Color(1.0, 0.9, 1.25), "base": {"armor": 2, "mana": 10}},
	"mage_legendary_boots": {"slot": "boots", "title": "Чоботи Архімага Рун", "parts": ["Peasant_Feet"], "class": "mage",
		"set": "mage_legendary", "rarity": "legendary", "tint": Color(1.0, 0.9, 1.25), "base": {"armor": 1, "move_speed": 2, "mana": 6}},
	"archer_uncommon_helmet": {"slot": "helmet", "title": "Шолом Лісового Слідопита", "parts": ["Ranger_Head_Hood"], "class": "archer",
		"set": "archer_uncommon", "rarity": "uncommon", "tint": Color(0.7, 0.9, 0.65), "base": {"armor": 3, "crit": 2}},
	"archer_uncommon_chest": {"slot": "chest", "title": "Нагрудник Лісового Слідопита", "parts": ["Ranger_Body", "Ranger_Arms"], "class": "archer",
		"set": "archer_uncommon", "rarity": "uncommon", "tint": Color(0.7, 0.9, 0.65), "base": {"armor": 5, "hp": 8, "attack_speed": 3}},
	"archer_uncommon_legs": {"slot": "legs", "title": "Поножі Лісового Слідопита", "parts": ["Ranger_Legs"], "class": "archer",
		"set": "archer_uncommon", "rarity": "uncommon", "tint": Color(0.7, 0.9, 0.65), "base": {"armor": 4, "hp": 6, "move_speed": 1}},
	"archer_uncommon_boots": {"slot": "boots", "title": "Чоботи Лісового Слідопита", "parts": ["Ranger_Feet_Boots"], "class": "archer",
		"set": "archer_uncommon", "rarity": "uncommon", "tint": Color(0.7, 0.9, 0.65), "base": {"armor": 3, "move_speed": 3}},
	"archer_rare_helmet": {"slot": "helmet", "title": "Шолом Яструбиного Ока", "parts": ["Ranger_Head_Hood"], "class": "archer",
		"set": "archer_rare", "rarity": "rare", "tint": Color(0.95, 0.9, 0.75), "base": {"armor": 3, "crit": 2}},
	"archer_rare_chest": {"slot": "chest", "title": "Нагрудник Яструбиного Ока", "parts": ["Ranger_Body", "Ranger_Arms"], "class": "archer",
		"set": "archer_rare", "rarity": "rare", "tint": Color(0.95, 0.9, 0.75), "base": {"armor": 5, "hp": 8, "attack_speed": 3}},
	"archer_rare_legs": {"slot": "legs", "title": "Поножі Яструбиного Ока", "parts": ["Ranger_Legs"], "class": "archer",
		"set": "archer_rare", "rarity": "rare", "tint": Color(0.95, 0.9, 0.75), "base": {"armor": 4, "hp": 6, "move_speed": 1}},
	"archer_rare_boots": {"slot": "boots", "title": "Чоботи Яструбиного Ока", "parts": ["Ranger_Feet_Boots"], "class": "archer",
		"set": "archer_rare", "rarity": "rare", "tint": Color(0.95, 0.9, 0.75), "base": {"armor": 3, "move_speed": 3}},
	"archer_epic_helmet": {"slot": "helmet", "title": "Шолом Грозового Мисливця", "parts": ["Ranger_Head_Hood"], "class": "archer",
		"set": "archer_epic", "rarity": "epic", "tint": Color(0.65, 0.8, 1.15), "base": {"armor": 3, "crit": 2}},
	"archer_epic_chest": {"slot": "chest", "title": "Нагрудник Грозового Мисливця", "parts": ["Ranger_Body", "Ranger_Arms"], "class": "archer",
		"set": "archer_epic", "rarity": "epic", "tint": Color(0.65, 0.8, 1.15), "base": {"armor": 5, "hp": 8, "attack_speed": 3}},
	"archer_epic_legs": {"slot": "legs", "title": "Поножі Грозового Мисливця", "parts": ["Ranger_Legs"], "class": "archer",
		"set": "archer_epic", "rarity": "epic", "tint": Color(0.65, 0.8, 1.15), "base": {"armor": 4, "hp": 6, "move_speed": 1}},
	"archer_epic_boots": {"slot": "boots", "title": "Чоботи Грозового Мисливця", "parts": ["Ranger_Feet_Boots"], "class": "archer",
		"set": "archer_epic", "rarity": "epic", "tint": Color(0.65, 0.8, 1.15), "base": {"armor": 3, "move_speed": 3}},
	"archer_legendary_helmet": {"slot": "helmet", "title": "Шолом Драконячого Вогню", "parts": ["Ranger_Head_Hood"], "class": "archer",
		"set": "archer_legendary", "rarity": "legendary", "tint": Color(1.2, 0.7, 0.5), "base": {"armor": 3, "crit": 2}},
	"archer_legendary_chest": {"slot": "chest", "title": "Нагрудник Драконячого Вогню", "parts": ["Ranger_Body", "Ranger_Arms"], "class": "archer",
		"set": "archer_legendary", "rarity": "legendary", "tint": Color(1.2, 0.7, 0.5), "base": {"armor": 5, "hp": 8, "attack_speed": 3}},
	"archer_legendary_legs": {"slot": "legs", "title": "Поножі Драконячого Вогню", "parts": ["Ranger_Legs"], "class": "archer",
		"set": "archer_legendary", "rarity": "legendary", "tint": Color(1.2, 0.7, 0.5), "base": {"armor": 4, "hp": 6, "move_speed": 1}},
	"archer_legendary_boots": {"slot": "boots", "title": "Чоботи Драконячого Вогню", "parts": ["Ranger_Feet_Boots"], "class": "archer",
		"set": "archer_legendary", "rarity": "legendary", "tint": Color(1.2, 0.7, 0.5), "base": {"armor": 3, "move_speed": 3}},
	"druid_uncommon_helmet": {"slot": "helmet", "title": "Шолом Мохового Шамана", "parts": ["Ranger_Head_Hood"], "class": "druid",
		"set": "druid_uncommon", "rarity": "uncommon", "tint": Color(0.75, 0.95, 0.65), "base": {"armor": 3, "hp": 6, "mana": 8}},
	"druid_uncommon_chest": {"slot": "chest", "title": "Нагрудник Мохового Шамана", "parts": ["Peasant_Body", "Ranger_Arms"], "class": "druid",
		"set": "druid_uncommon", "rarity": "uncommon", "tint": Color(0.75, 0.95, 0.65), "base": {"armor": 6, "hp": 12, "mana": 12}},
	"druid_uncommon_legs": {"slot": "legs", "title": "Поножі Мохового Шамана", "parts": ["Peasant_Legs"], "class": "druid",
		"set": "druid_uncommon", "rarity": "uncommon", "tint": Color(0.75, 0.95, 0.65), "base": {"armor": 4, "hp": 8}},
	"druid_uncommon_boots": {"slot": "boots", "title": "Чоботи Мохового Шамана", "parts": ["Ranger_Feet_Boots"], "class": "druid",
		"set": "druid_uncommon", "rarity": "uncommon", "tint": Color(0.75, 0.95, 0.65), "base": {"armor": 2, "move_speed": 2, "regen": 1}},
	"druid_rare_helmet": {"slot": "helmet", "title": "Шолом Терновий", "parts": ["Ranger_Head_Hood"], "class": "druid",
		"set": "druid_rare", "rarity": "rare", "tint": Color(0.8, 1.0, 0.7), "base": {"armor": 3, "hp": 6, "mana": 8}},
	"druid_rare_chest": {"slot": "chest", "title": "Нагрудник Терновий", "parts": ["Peasant_Body", "Ranger_Arms"], "class": "druid",
		"set": "druid_rare", "rarity": "rare", "tint": Color(0.8, 1.0, 0.7), "base": {"armor": 6, "hp": 12, "mana": 12}},
	"druid_rare_legs": {"slot": "legs", "title": "Поножі Терновий", "parts": ["Peasant_Legs"], "class": "druid",
		"set": "druid_rare", "rarity": "rare", "tint": Color(0.8, 1.0, 0.7), "base": {"armor": 4, "hp": 8}},
	"druid_rare_boots": {"slot": "boots", "title": "Чоботи Терновий", "parts": ["Ranger_Feet_Boots"], "class": "druid",
		"set": "druid_rare", "rarity": "rare", "tint": Color(0.8, 1.0, 0.7), "base": {"armor": 2, "move_speed": 2, "regen": 1}},
	"druid_epic_helmet": {"slot": "helmet", "title": "Шолом Місячного Вовка", "parts": ["Ranger_Head_Hood"], "class": "druid",
		"set": "druid_epic", "rarity": "epic", "tint": Color(0.8, 0.9, 1.15), "base": {"armor": 3, "hp": 6, "mana": 8}},
	"druid_epic_chest": {"slot": "chest", "title": "Нагрудник Місячного Вовка", "parts": ["Peasant_Body", "Ranger_Arms"], "class": "druid",
		"set": "druid_epic", "rarity": "epic", "tint": Color(0.8, 0.9, 1.15), "base": {"armor": 6, "hp": 12, "mana": 12}},
	"druid_epic_legs": {"slot": "legs", "title": "Поножі Місячного Вовка", "parts": ["Peasant_Legs"], "class": "druid",
		"set": "druid_epic", "rarity": "epic", "tint": Color(0.8, 0.9, 1.15), "base": {"armor": 4, "hp": 8}},
	"druid_epic_boots": {"slot": "boots", "title": "Чоботи Місячного Вовка", "parts": ["Ranger_Feet_Boots"], "class": "druid",
		"set": "druid_epic", "rarity": "epic", "tint": Color(0.8, 0.9, 1.15), "base": {"armor": 2, "move_speed": 2, "regen": 1}},
	"druid_legendary_helmet": {"slot": "helmet", "title": "Шолом Світового Дерева", "parts": ["Ranger_Head_Hood"], "class": "druid",
		"set": "druid_legendary", "rarity": "legendary", "tint": Color(1.1, 1.05, 0.65), "base": {"armor": 3, "hp": 6, "mana": 8}},
	"druid_legendary_chest": {"slot": "chest", "title": "Нагрудник Світового Дерева", "parts": ["Peasant_Body", "Ranger_Arms"], "class": "druid",
		"set": "druid_legendary", "rarity": "legendary", "tint": Color(1.1, 1.05, 0.65), "base": {"armor": 6, "hp": 12, "mana": 12}},
	"druid_legendary_legs": {"slot": "legs", "title": "Поножі Світового Дерева", "parts": ["Peasant_Legs"], "class": "druid",
		"set": "druid_legendary", "rarity": "legendary", "tint": Color(1.1, 1.05, 0.65), "base": {"armor": 4, "hp": 8}},
	"druid_legendary_boots": {"slot": "boots", "title": "Чоботи Світового Дерева", "parts": ["Ranger_Feet_Boots"], "class": "druid",
		"set": "druid_legendary", "rarity": "legendary", "tint": Color(1.1, 1.05, 0.65), "base": {"armor": 2, "move_speed": 2, "regen": 1}},
}

static var _counter := 0

## Нова річ заготовки base потрібної рідкості (числа — випадкові в межах).
static func roll(base_id: String, rarity: String = "common", level: int = 1) -> Dictionary:
	var base: Dictionary = BASES[base_id]
	# У зброї рідкість своя, назавжди.
	rarity = String(base.get("rarity", rarity))
	var power: float = RARITY_POWER.get(rarity, 1.0) * (1.0 + 0.08 * (level - 1))
	var stats := {}
	for stat: String in base.base:
		stats[stat] = maxi(1, roundi(float(base.base[stat]) * power * randf_range(0.9, 1.1)))
	var pool := AFFIX_RANGES.keys()
	pool.shuffle()
	var extra: int = RARITY_AFFIXES.get(rarity, 0)
	for stat: String in pool:
		if extra <= 0:
			break
		var range_: Array = AFFIX_RANGES[stat]
		var value := roundi(randf_range(range_[0], range_[1]) * power)
		stats[stat] = int(stats.get(stat, 0)) + maxi(1, value)
		extra -= 1
	_counter += 1
	return {"uid": "i%d%d" % [Time.get_ticks_msec(), _counter], "base": base_id, "rarity": rarity, "stats": stats, "level": level}

## Унікальне вміння речі (зброя з синьої рідкості): ефекти бою.
static func unique_effects(item: Dictionary) -> Dictionary:
	return base_of(item).get("unique", {})

const WEAPON_ITEM_DIR := "res://assets/models/weapons/items/"
const OFFHAND_PROPS := "res://assets/models/haven/props/"
static var _weapon_defs := {}
const STAFF_GRIP := Vector3(90, 30, 0)

## Бойовий опис зброї для речі: шаблон із WeaponPool (анімації, бій) +
## своя модель і щит. Кешується за заготовкою.
static func weapon_def(item: Dictionary) -> WeaponDef:
	var base := base_of(item)
	if not base.has("weapon"):
		return null
	var key := String(item.get("base", ""))
	if _weapon_defs.has(key):
		return _weapon_defs[key]
	var template := WeaponPool.get_def(StringName(base.weapon))
	if template == null:
		return null
	var def := template
	if base.has("model") or base.has("offhand"):
		def = template.duplicate() as WeaponDef
		if base.has("model"):
			var path := WEAPON_ITEM_DIR + String(base.model) + ".scn"
			if ResourceLoader.exists(path):
				def.model_scene = load(path)
				def.model_scale = 1.0
				def.grip_rotation_deg = Vector3.ZERO
				def.grip_offset = Vector3.ZERO
				# Посох у кулаці, рівно вгору збоку героя (без «вертикального
				# хвату», що на новому тілі ховав посох за спину).
				if def.upright_3d:
					def.upright_3d = false
				if def.style_3d == "staff":
					def.muzzle_offset = Vector3(0, _model_top(def.model_scene) * 0.95, 0)
		if base.has("offhand"):
			var shield := WEAPON_ITEM_DIR + String(base.offhand) + ".scn"
			if not ResourceLoader.exists(shield):
				shield = OFFHAND_PROPS + String(base.offhand) + ".gltf"
			if ResourceLoader.exists(shield):
				def.offhand_model = load(shield)
				def.offhand_rotation_deg = Vector3(0, -90, 0)
				def.offhand_scale = 1.0
	_weapon_defs[key] = def
	return def

## Верхня точка моделі (м) — звідки летять чари посоха.
static func _model_top(scene: PackedScene) -> float:
	var node: Node3D = scene.instantiate()
	var top := 0.0
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = mesh
		while n != null and n != node:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		top = maxf(top, (xf * mesh.get_aabb()).end.y)
	node.free()
	return top

static func base_of(item: Dictionary) -> Dictionary:
	return BASES.get(String(item.get("base", "")), {})

static func slot_of(item: Dictionary) -> String:
	return String(base_of(item).get("slot", ""))

## "Рідкісна Шкіряна куртка" — назва з рідкістю (сіра — без префікса).
static func title_of(item: Dictionary) -> String:
	var title := String(base_of(item).get("title", "Річ"))
	return title + (" +%d" % plus_of(item) if plus_of(item) > 0 else "")

static func color_of(item: Dictionary) -> Color:
	return RARITY_COLORS.get(item.get("rarity", "common"), Color.WHITE)

## Іконка речі: своя (kit/icons/item_<заготовка>), зброя — з WeaponPool,
## інакше — значок слота.
static func icon_of(item: Dictionary) -> Texture2D:
	var own := ArtSlots.kit_icon("item_" + String(item.get("base", "")))
	if own != null:
		return own
	var base := base_of(item)
	if base.has("icon"):
		var shared := ArtSlots.kit_icon(String(base.icon))
		if shared != null:
			return shared
	if base.has("weapon"):
		var def := WeaponPool.get_def(StringName(base.weapon))
		if def != null:
			var icon := ArtSlots.weapon_icon(def.id, def.icon)
			if icon != null:
				return icon
	return slot_icon(String(base.get("slot", "")))

static func slot_icon(slot: String) -> Texture2D:
	var names := {"helmet": "menu_heroes", "chest": "stat_armor", "legs": "stat_armor", "boots": "stat_speed",
		"weapon": "stat_damage", "amulet": "boon_potion", "ring1": "meta_luck", "ring2": "meta_luck"}
	return ArtSlots.kit_icon(names.get(slot, "stat_armor"))

## Що надіто: слот -> річ (лише ті, що справді є в торбі/надіті).
static func equipped_items() -> Dictionary:
	var result := {}
	for slot: String in GameState.equipment:
		var item := find(String(GameState.equipment[slot]))
		if not item.is_empty():
			result[slot] = item
	return result

static func find(uid: String) -> Dictionary:
	for item: Dictionary in GameState.equipped_store:
		if item.uid == uid:
			return item
	for item: Dictionary in GameState.inventory:
		if item.uid == uid:
			return item
	return {}

## Вигляд надітого для CharacterBuilder: слот -> {parts, rarity}.
static func gear_look(items: Dictionary = {}) -> Dictionary:
	if items.is_empty():
		items = equipped_items()
	var gear := {}
	for slot: String in items:
		var base := base_of(items[slot])
		if base.has("parts"):
			gear[slot] = {"parts": base.parts, "rarity": items[slot].rarity}
			if base.has("tint"):
				gear[slot]["tint"] = (base.tint as Color) * CharacterBuilder.RARITY_TINTS.get(items[slot].rarity, Color.WHITE)
	return gear

## Сума характеристик усіх надітих речей.
static func total_stats(items: Dictionary = {}) -> Dictionary:
	if items.is_empty():
		items = equipped_items()
	var total := {}
	for slot: String in items:
		var stats: Dictionary = items[slot].get("stats", {})
		for stat: String in stats:
			total[stat] = int(total.get(stat, 0)) + int(stats[stat])
	return total

## Чи можна вдягти: прикраси — з JEWELRY_LEVEL.
static func can_equip(item: Dictionary) -> bool:
	var slot := slot_of(item)
	if slot in ["amulet", "ring1", "ring2"]:
		return GameState.hero_level >= JEWELRY_LEVEL
	return slot != ""

## Вдягти річ із торби: попередня в цьому слоті повертається в торбу.
static func equip(uid: String) -> void:
	var item: Dictionary = {}
	for candidate: Dictionary in GameState.inventory:
		if candidate.uid == uid:
			item = candidate
	if item.is_empty() or not can_equip(item):
		return
	var slot := slot_of(item)
	unequip(slot)
	GameState.inventory.erase(item)
	GameState.equipped_store.append(item)
	GameState.equipment[slot] = uid
	GameState.equipment_changed.emit()
	if slot == "weapon" and String(base_of(item).get("class", "")) != "":
		QuestBook.report("equip")
	SaveManager.save_game()

## Зняти річ зі слоту в торбу.
static func unequip(slot: String) -> void:
	var uid := String(GameState.equipment.get(slot, ""))
	if uid == "":
		return
	for item: Dictionary in GameState.equipped_store.duplicate():
		if item.uid == uid:
			GameState.equipped_store.erase(item)
			GameState.inventory.append(item)
	GameState.equipment.erase(slot)
	GameState.equipment_changed.emit()
	SaveManager.save_game()

## Покласти річ у торбу (нагорода, здобич).
static func give(item: Dictionary) -> void:
	discover(String(item.get("base", "")))
	GameState.inventory.append(item)
	GameState.equipment_changed.emit()
	SaveManager.save_game()

# --- КУЗНЯ: відкриття, ціни, покращення, сети ---

## Річ хоч раз потрапила до героя — у Коваля вона відкрита назавжди.
static func discover(base_id: String) -> void:
	if base_id != "" and not GameState.discovered.has(base_id):
		GameState.discovered[base_id] = true

static func is_discovered(base_id: String) -> bool:
	return GameState.discovered.has(base_id)

const BUY_PRICE := {"common": 120, "uncommon": 350, "rare": 900, "epic": 2200, "legendary": 5000}
const MAX_PLUS := 10
## Кожен рівень покращення: +8% до всіх чисел речі.
const PLUS_STEP := 0.08

static func rarity_of_base(base_id: String) -> String:
	return String(BASES.get(base_id, {}).get("rarity", "common"))

## Ціна в Коваля (зброя дорожча за броню на третину).
static func buy_price(base_id: String) -> int:
	var price: int = BUY_PRICE.get(rarity_of_base(base_id), 120)
	if String(BASES.get(base_id, {}).get("slot", "")) == "weapon":
		price = int(price * 1.3)
	return price

## Продаж: третина ціни, але вкладене в покращення повертається на 70% —
## прокачана річ продається дорожче, ніж нова коштує.
static func sell_price(item: Dictionary) -> int:
	var base_price := buy_price(String(item.get("base", "")))
	if not BASES.has(String(item.get("base", ""))):
		base_price = BUY_PRICE.get(String(item.get("rarity", "common")), 120)
	return int(base_price * 0.35) + int(int(item.get("upgrade_spent", 0)) * 0.7)

static func plus_of(item: Dictionary) -> int:
	return int(item.get("plus", 0))

## Скільки коштує наступне покращення.
static func upgrade_cost(item: Dictionary) -> int:
	var base_price := buy_price(String(item.get("base", "")))
	return int(base_price * 0.3 * (plus_of(item) + 1))

## Покращити річ на +1 (числа ростуть від початкових на PLUS_STEP).
static func upgrade(uid: String) -> bool:
	var item := find(uid)
	if item.is_empty() or plus_of(item) >= MAX_PLUS:
		return false
	var cost := upgrade_cost(item)
	if GameState.gold < cost:
		return false
	GameState.gold -= cost
	if not item.has("raw"):
		item["raw"] = (item.get("stats", {}) as Dictionary).duplicate()
	item["plus"] = plus_of(item) + 1
	item["upgrade_spent"] = int(item.get("upgrade_spent", 0)) + cost
	var raw: Dictionary = item.raw
	var stats := {}
	for stat: String in raw:
		stats[stat] = maxi(int(raw[stat]) + 1, roundi(float(raw[stat]) * (1.0 + PLUS_STEP * item.plus)))
	item["stats"] = stats
	GameState.equipment_changed.emit()
	SaveManager.save_game()
	return true

## Купити в Коваля: завжди нова річ 1-го рівня, без покращень.
static func buy(base_id: String) -> Dictionary:
	if not is_discovered(base_id):
		return {}
	var price := buy_price(base_id)
	if GameState.gold < price:
		return {}
	GameState.gold -= price
	var item := roll(base_id, rarity_of_base(base_id), 1)
	give(item)
	return item

static func sell(uid: String) -> int:
	var item := find(uid)
	if item.is_empty():
		return 0
	for slot: String in GameState.equipment.keys():
		if String(GameState.equipment[slot]) == uid:
			unequip(slot)
	var price := sell_price(item)
	GameState.inventory.erase(item)
	GameState.gold += price
	GameState.equipment_changed.emit()
	SaveManager.save_game()
	return price

## Скільки речей кожного сету надіто: set_id -> кількість.
static func worn_sets(items: Dictionary = {}) -> Dictionary:
	if items.is_empty():
		items = equipped_items()
	var counts := {}
	for slot: String in items:
		var set_id := String(base_of(items[slot]).get("set", ""))
		if set_id != "":
			counts[set_id] = int(counts.get(set_id, 0)) + 1
	return counts

## Ефекти активних бонусів сетів (за 2, 3 і 4 надіті речі).
static func set_effects(items: Dictionary = {}) -> Dictionary:
	var total := {}
	var counts := worn_sets(items)
	for set_id: String in counts:
		var bonus: Dictionary = SETS.get(set_id, {}).get("bonus", {})
		for need: int in bonus:
			if int(counts[set_id]) >= need:
				for key: String in bonus[need]:
					total[key] = float(total.get(key, 0.0)) + float(bonus[need][key])
	return total

const EFFECT_TITLES := {"double_strike": "шанс подвійного удару %s%%", "crit_bleed": "крит відкриває рану (%s%% шкоди)",
	"thorns": "шипи %s%%", "damage_reduction": "−%s%% отриманої шкоди", "chain_lightning": "ланцюгова блискавка %s%%",
	"crit_damage": "+%s%% до криту", "multishot": "мультипостріл %s%%", "eagle_eye": "+%s%% пострілам здалеку",
	"beast_spirit": "дух звіра +%s%%", "lifesteal": "вампіризм %s%%"}

## "+5% шкоди, шипи 25%" — опис бонусу.
static func describe_effects(effects: Dictionary) -> String:
	var parts := PackedStringArray()
	for key: String in effects:
		var value := str(snappedf(float(effects[key]), 0.1)).trim_suffix(".0")
		if STATS.has(key):
			parts.append("+%s%s %s" % [value, STATS[key].suffix, String(STATS[key].title).to_lower()])
		elif EFFECT_TITLES.has(key):
			parts.append(String(EFFECT_TITLES[key]) % value)
	return ", ".join(parts)

## Порівняння: стат -> різниця (нова мінус надіта в тому ж слоті).
static func compare(item: Dictionary) -> Dictionary:
	var current := find(String(GameState.equipment.get(slot_of(item), "")))
	var keys := {}
	for stat: String in item.get("stats", {}):
		keys[stat] = true
	for stat: String in current.get("stats", {}):
		keys[stat] = true
	var diff := {}
	for stat: String in keys:
		diff[stat] = int(item.get("stats", {}).get(stat, 0)) - int(current.get("stats", {}).get(stat, 0))
	return diff
