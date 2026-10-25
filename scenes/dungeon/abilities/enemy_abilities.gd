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
