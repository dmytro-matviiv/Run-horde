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
##   pylons       — (бос) пілони: поки стоять, бос невразливий.

const SCRIPTS := {
	"blink": preload("res://scenes/dungeon/abilities/blink_ability.gd"),
	"raise_dead": preload("res://scenes/dungeon/abilities/raise_dead_ability.gd"),
	"lob": preload("res://scenes/dungeon/abilities/lob_ability.gd"),
	"web": preload("res://scenes/dungeon/abilities/web_ability.gd"),
	"burrow": preload("res://scenes/dungeon/abilities/burrow_ability.gd"),
	"split": preload("res://scenes/dungeon/abilities/split_ability.gd"),
	"ward": preload("res://scenes/dungeon/abilities/ward_ability.gd"),
	"leap": preload("res://scenes/dungeon/abilities/leap_ability.gd"),
	"ring_slam": preload("res://scenes/dungeon/abilities/ring_slam_ability.gd"),
	"radial_volley": preload("res://scenes/dungeon/abilities/radial_volley_ability.gd"),
	"beams": preload("res://scenes/dungeon/abilities/beams_ability.gd"),
	"pylons": preload("res://scenes/dungeon/abilities/pylons_ability.gd"),
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
