extends RefCounted
class_name EnemyAbilities

## Реєстр здібностей ворогів: назва з опису рівня -> клас здібності.
##   blink        — мерехтіння: зникає й виникає за спиною героя, одразу б'є;
##   raise_dead   — підіймає мерців довкола себе ("summon" — хто саме);
##   lob          — кидає бомбу по дузі туди, де стоїть герой ("pool" —
##                  лишає калюжу вогню чи отрути);
##   web          — павутина: снаряд, що сповільнює героя;
##   burrow       — пірнає під землю й виринає просто під героєм;
##   split        — загинувши, розпадається на двох менших;
##   ward         — тотем: захищає сусідів (або боса) світними нитками;
##   leap         — стрибає на героя, приземлення б'є по колу;
##   ring_slam    — (бос) кільце ударної хвилі, що розбігається по підлозі;
##   radial_volley — (бос) коло снарядів навсібіч із проходом для втечі;
##   beams        — (бос) промені, що обертаються довкола нього;
##   pylons       — (бос) пілони: поки стоять, бос невразливий;
##   meteor_storm — (мега-бос) метеоритний дощ по всій залі одразу;
##   void_rift    — (мега-бос) вир, що затягує героя й пече, поки той у ньому;
##   mirror_split — (мега-бос) розколюється на тьмяних двійників-приманок.
## Кістяний Погост (4-й данж):
##   vanish       — привид зникає (видно лише ланцюг) і б'є з-за спини;
##   grave_escape — чаклун тікає в могилу, коли герой надто близько;
##   tunnel       — хробак повзе під землею й вистрибує під героєм;
##   poison_cloud — отруйна хмара довкола; death_blast — гине з вибухом;
##   empower      — тотем: союзники б'ють сильніше й лікуються;
##   scythe_sweep, scythe_throw, army_of_dead, eternal_lord, bone_spikes —
##                  прийоми Кістяного Володаря.
## Кузня Присмерку (6-й данж):
##   hook         — гном кидає гак-ланцюг і підтягує героя до себе;
##   merge        — три іскри, що злиплись, стають Полум'яним ядром;
##   anvil_slam   — ковадло-щит спереду (стріли відбиває) і гупання ним;
##   overheat     — голем: розжарений (міцний, сліди) / перегрітий (вразливий);
##   forge_blades, magnet, molten_channels, forge_core — Володар Горна.
##   (рикошет Гартувальника — "bounces" у "projectile" опису ворога.)
## Скарбниця Тіней (7-й данж):
##   greedy_bite  — мімік-скриня: укус краде золото, смерть повертає вдвічі;
##   debt         — Лихвар: "борг" над героєм, не вдарив за 5 с — стягує;
##   gold_dust    — оса: шари золотого пилу (герой отримує більше шкоди);
##   freeze_tag   — статуя: мчить, поки герой рухається; стоїть — кам'яніє;
##   fate_scale   — ваги: шкода ділиться між усіма пов'язаними ворогами;
##   gold_cage, decoy_chests (+ treasure), rolling_coins — Золотий Скупар.
## Спустошене Село (8-й данж):
##   ignite       — палій: удар підпалює героя (гасне перекатом);
##   disengage    — мисливець відскакує й стріляє (стріли — на випередження);
##   blind_peck   — ворони: клюють в очі, край екрана темніє;
##   boar_rage    — вепр: кожен удар по ньому лютить (швидший і сильніший);
##   smoke_bomb   — димар: вороги в диму не обираються ціллю;
##   fire_ring, bola, riposte — Ватажок розбійників.
## Безодня Рун (9-й данж):
##   swap         — демон міняється з героєм місцями;
##   silence_rune — писар: коло мовчання (без здібностей);
##   mana_bite    — імпи висмоктують ману;
##   confusion_breath — дракон: керування навиворіт;
##   revive       — обеліск воскрешає ворогів, що впали поруч;
##   rune_sequence, void_walls, echo — Володар Рун.

const SCRIPTS := {
	"blink": preload("res://scenes/dungeon/abilities/blink_ability.gd"),
	"raise_dead": preload("res://scenes/dungeon/abilities/raise_dead_ability.gd"),
	"lob": preload("res://scenes/dungeon/abilities/lob_ability.gd"),
	"web": preload("res://scenes/dungeon/abilities/web_ability.gd"),
	"burrow": preload("res://scenes/dungeon/abilities/burrow_ability.gd"),
	"split": preload("res://scenes/dungeon/abilities/split_ability.gd"),
	"ward": preload("res://scenes/dungeon/abilities/ward_ability.gd"),
	"leap": preload("res://scenes/dungeon/abilities/leap_ability.gd"),
	"lunge": preload("res://scenes/dungeon/abilities/lunge_ability.gd"),
	"slime_trail": preload("res://scenes/dungeon/abilities/slime_trail_ability.gd"),
	"grasp": preload("res://scenes/dungeon/abilities/grasp_ability.gd"),
	"crack_lines": preload("res://scenes/dungeon/abilities/crack_lines_ability.gd"),
	"chain_spin": preload("res://scenes/dungeon/abilities/chain_spin_ability.gd"),
	"sarcophagi": preload("res://scenes/dungeon/abilities/sarcophagi_ability.gd"),
	"shatter": preload("res://scenes/dungeon/abilities/shatter_ability.gd"),
	"slide_tackle": preload("res://scenes/dungeon/abilities/slide_tackle_ability.gd"),
	"ice_wall": preload("res://scenes/dungeon/abilities/ice_wall_ability.gd"),
	"ice_armor": preload("res://scenes/dungeon/abilities/ice_armor_ability.gd"),
	"crystal_nova": preload("res://scenes/dungeon/abilities/crystal_nova_ability.gd"),
	"frostbite": preload("res://scenes/dungeon/abilities/frostbite_ability.gd"),
	"arcane_aura": preload("res://scenes/dungeon/abilities/arcane_aura_ability.gd"),
	"freezing_field": preload("res://scenes/dungeon/abilities/freezing_field_ability.gd"),
	"frost_breath": preload("res://scenes/dungeon/abilities/frost_breath_ability.gd"),
	"tail_sweep": preload("res://scenes/dungeon/abilities/tail_sweep_ability.gd"),
	"sky_fall": preload("res://scenes/dungeon/abilities/sky_fall_ability.gd"),
	"eternal_winter": preload("res://scenes/dungeon/abilities/eternal_winter_ability.gd"),
	"wing_gust": preload("res://scenes/dungeon/abilities/wing_gust_ability.gd"),
	"dark_shield": preload("res://scenes/dungeon/abilities/dark_shield_ability.gd"),
	"phase_step": preload("res://scenes/dungeon/abilities/phase_step_ability.gd"),
	"ring_slam": preload("res://scenes/dungeon/abilities/ring_slam_ability.gd"),
	"radial_volley": preload("res://scenes/dungeon/abilities/radial_volley_ability.gd"),
	"beams": preload("res://scenes/dungeon/abilities/beams_ability.gd"),
	"pylons": preload("res://scenes/dungeon/abilities/pylons_ability.gd"),
	"meteor_storm": preload("res://scenes/dungeon/abilities/meteor_storm_ability.gd"),
	"void_rift": preload("res://scenes/dungeon/abilities/void_rift_ability.gd"),
	"mirror_split": preload("res://scenes/dungeon/abilities/mirror_split_ability.gd"),
	"vanish": preload("res://scenes/dungeon/abilities/vanish_ability.gd"),
	"grave_escape": preload("res://scenes/dungeon/abilities/grave_escape_ability.gd"),
	"tunnel": preload("res://scenes/dungeon/abilities/tunnel_ability.gd"),
	"poison_cloud": preload("res://scenes/dungeon/abilities/poison_cloud_ability.gd"),
	"death_blast": preload("res://scenes/dungeon/abilities/death_blast_ability.gd"),
	"empower": preload("res://scenes/dungeon/abilities/empower_ability.gd"),
	"scythe_sweep": preload("res://scenes/dungeon/abilities/scythe_sweep_ability.gd"),
	"scythe_throw": preload("res://scenes/dungeon/abilities/scythe_throw_ability.gd"),
	"army_of_dead": preload("res://scenes/dungeon/abilities/army_of_dead_ability.gd"),
	"eternal_lord": preload("res://scenes/dungeon/abilities/eternal_lord_ability.gd"),
	"bone_spikes": preload("res://scenes/dungeon/abilities/bone_spikes_ability.gd"),
	"hook": preload("res://scenes/dungeon/abilities/hook_ability.gd"),
	"merge": preload("res://scenes/dungeon/abilities/merge_ability.gd"),
	"anvil_slam": preload("res://scenes/dungeon/abilities/anvil_guard_ability.gd"),
	"overheat": preload("res://scenes/dungeon/abilities/overheat_ability.gd"),
	"forge_blades": preload("res://scenes/dungeon/abilities/forge_blades_ability.gd"),
	"magnet": preload("res://scenes/dungeon/abilities/magnet_ability.gd"),
	"molten_channels": preload("res://scenes/dungeon/abilities/molten_channels_ability.gd"),
	"forge_core": preload("res://scenes/dungeon/abilities/forge_core_ability.gd"),
	"greedy_bite": preload("res://scenes/dungeon/abilities/greedy_bite_ability.gd"),
	"debt": preload("res://scenes/dungeon/abilities/debt_ability.gd"),
	"gold_dust": preload("res://scenes/dungeon/abilities/gold_dust_ability.gd"),
	"freeze_tag": preload("res://scenes/dungeon/abilities/freeze_tag_ability.gd"),
	"fate_scale": preload("res://scenes/dungeon/abilities/fate_scale_ability.gd"),
	"gold_cage": preload("res://scenes/dungeon/abilities/gold_cage_ability.gd"),
	"decoy_chests": preload("res://scenes/dungeon/abilities/decoy_chests_ability.gd"),
	"treasure": preload("res://scenes/dungeon/abilities/treasure_ability.gd"),
	"rolling_coins": preload("res://scenes/dungeon/abilities/rolling_coins_ability.gd"),
	"ignite": preload("res://scenes/dungeon/abilities/ignite_ability.gd"),
	"disengage": preload("res://scenes/dungeon/abilities/disengage_ability.gd"),
	"blind_peck": preload("res://scenes/dungeon/abilities/blind_peck_ability.gd"),
	"boar_rage": preload("res://scenes/dungeon/abilities/boar_rage_ability.gd"),
	"smoke_bomb": preload("res://scenes/dungeon/abilities/smoke_bomb_ability.gd"),
	"fire_ring": preload("res://scenes/dungeon/abilities/fire_ring_ability.gd"),
	"bola": preload("res://scenes/dungeon/abilities/bola_ability.gd"),
	"riposte": preload("res://scenes/dungeon/abilities/riposte_ability.gd"),
	"swap": preload("res://scenes/dungeon/abilities/swap_ability.gd"),
	"silence_rune": preload("res://scenes/dungeon/abilities/silence_rune_ability.gd"),
	"mana_bite": preload("res://scenes/dungeon/abilities/mana_bite_ability.gd"),
	"confusion_breath": preload("res://scenes/dungeon/abilities/confusion_breath_ability.gd"),
	"revive": preload("res://scenes/dungeon/abilities/revive_obelisk_ability.gd"),
	"rune_sequence": preload("res://scenes/dungeon/abilities/rune_sequence_ability.gd"),
	"void_walls": preload("res://scenes/dungeon/abilities/void_walls_ability.gd"),
	"echo": preload("res://scenes/dungeon/abilities/echo_ability.gd"),
	"sticky_tongue": preload("res://scenes/dungeon/abilities/sticky_tongue_ability.gd"),
	"leech": preload("res://scenes/dungeon/abilities/leech_ability.gd"),
	"seed_sprout": preload("res://scenes/dungeon/abilities/seed_sprout_ability.gd"),
	"thorns": preload("res://scenes/dungeon/abilities/thorns_ability.gd"),
	"vine_leash": preload("res://scenes/dungeon/abilities/vine_leash_ability.gd"),
	"molt": preload("res://scenes/dungeon/abilities/molt_ability.gd"),
	"flood": preload("res://scenes/dungeon/abilities/flood_ability.gd"),
	"swallow": preload("res://scenes/dungeon/abilities/swallow_ability.gd"),
	"undertow": preload("res://scenes/dungeon/abilities/undertow_ability.gd"),
	"ice_slick": preload("res://scenes/dungeon/abilities/ice_slick_ability.gd"),
	"flank": preload("res://scenes/dungeon/abilities/flank_ability.gd"),
	"numb": preload("res://scenes/dungeon/abilities/numb_ability.gd"),
	"snow_bury": preload("res://scenes/dungeon/abilities/snow_bury_ability.gd"),
	"alarm_horn": preload("res://scenes/dungeon/abilities/alarm_horn_ability.gd"),
	"glacier": preload("res://scenes/dungeon/abilities/glacier_ability.gd"),
	"blizzard": preload("res://scenes/dungeon/abilities/blizzard_ability.gd"),
	"crack_floor": preload("res://scenes/dungeon/abilities/crack_floor_ability.gd"),
	"harden": preload("res://scenes/dungeon/abilities/harden_ability.gd"),
	"sear": preload("res://scenes/dungeon/abilities/sear_ability.gd"),
	"execute": preload("res://scenes/dungeon/abilities/execute_ability.gd"),
	"fire_tether": preload("res://scenes/dungeon/abilities/fire_tether_ability.gd"),
	"sulfur_smog": preload("res://scenes/dungeon/abilities/sulfur_smog_ability.gd"),
	"checker": preload("res://scenes/dungeon/abilities/checker_ability.gd"),
	"orbit_flames": preload("res://scenes/dungeon/abilities/orbit_flames_ability.gd"),
	"molten_skin": preload("res://scenes/dungeon/abilities/molten_skin_ability.gd"),
	"hurl": preload("res://scenes/dungeon/abilities/hurl_ability.gd"),
	"taboo": preload("res://scenes/dungeon/abilities/taboo_ability.gd"),
	"possess": preload("res://scenes/dungeon/abilities/possess_ability.gd"),
	"god_gaze": preload("res://scenes/dungeon/abilities/god_gaze_ability.gd"),
	"martyr": preload("res://scenes/dungeon/abilities/martyr_ability.gd"),
	"rewind": preload("res://scenes/dungeon/abilities/rewind_ability.gd"),
	"god_hand": preload("res://scenes/dungeon/abilities/god_hand_ability.gd"),
	"devotion_orbs": preload("res://scenes/dungeon/abilities/devotion_orbs_ability.gd"),
	"braziers": preload("res://scenes/dungeon/abilities/braziers_ability.gd"),
	"shadow_dash": preload("res://scenes/dungeon/abilities/shadow_dash_ability.gd"),
	"shadow_hands": preload("res://scenes/dungeon/abilities/shadow_hands_ability.gd"),
	"shadow_scythe": preload("res://scenes/dungeon/abilities/shadow_scythe_ability.gd"),
	"shadow_split": preload("res://scenes/dungeon/abilities/shadow_split_ability.gd"),
	"rune_brand": preload("res://scenes/dungeon/abilities/rune_brand_ability.gd"),
	"rune_waves": preload("res://scenes/dungeon/abilities/rune_waves_ability.gd"),
	"abyss_chains": preload("res://scenes/dungeon/abilities/abyss_chains_ability.gd"),
	"abyss_realm": preload("res://scenes/dungeon/abilities/abyss_realm_ability.gd"),
	"frost_charge": preload("res://scenes/dungeon/abilities/frost_charge_ability.gd"),
	"ice_cage": preload("res://scenes/dungeon/abilities/ice_cage_ability.gd"),
	"frost_spears": preload("res://scenes/dungeon/abilities/frost_spears_ability.gd"),
	"cling": preload("res://scenes/dungeon/abilities/cling_ability.gd"),
	"flame_pillar": preload("res://scenes/dungeon/abilities/flame_pillar_ability.gd"),
	"lava_slam": preload("res://scenes/dungeon/abilities/lava_slam_ability.gd"),
	"cleave_leap": preload("res://scenes/dungeon/abilities/cleave_leap_ability.gd"),
	"pack_howl": preload("res://scenes/dungeon/abilities/pack_howl_ability.gd"),
	"wolf_pounce": preload("res://scenes/dungeon/abilities/wolf_pounce_ability.gd"),
	"wolf_circle": preload("res://scenes/dungeon/abilities/wolf_circle_ability.gd"),
	"frost_ward": preload("res://scenes/dungeon/abilities/frost_ward_ability.gd"),
	"frost_nova": preload("res://scenes/dungeon/abilities/frost_nova_ability.gd"),
	"snowball": preload("res://scenes/dungeon/abilities/snowball_ability.gd"),
	"axe_whirl": preload("res://scenes/dungeon/abilities/axe_whirl_ability.gd"),
	"eclipse": preload("res://scenes/dungeon/abilities/eclipse_ability.gd"),
}

## Здібності з опису ворога: рядок ("blink") або словник ({"id": "lob", ...}).
static func create_all(owner: Enemy3D, entries: Array) -> Array[EnemyAbility]:
	var result: Array[EnemyAbility] = []
	for entry: Variant in entries:
		var settings: Dictionary = entry if entry is Dictionary else {"id": String(entry)}
		var script: GDScript = SCRIPTS.get(String(settings.get("id", "")))
		if script == null:
			push_warning("Невідома здібність ворога: %s" % settings)
			continue
		var ability: EnemyAbility = script.new()
		ability.setup(owner, settings)
		result.append(ability)
	return result
