# -*- coding: utf-8 -*-
"""Облік шкоди по джерелах (зброя / кожна здібність / пасивка) для екрана підсумків."""
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:80])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/world/player_3d.gd", [
    ('''## Єдине місце, де героєві рахується шкода: сюди приходять і звичайні
## удари, і здібності, і пасивки. Тут же діють мітка ворога, димова
## завіса й критичні удари.
func deal_damage(enemy: Enemy3D, multiplier: float, knockback: Vector3, heavy: bool) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return''', '''## Єдине місце, де героєві рахується шкода: сюди приходять і звичайні
## удари, і здібності, і пасивки. Тут же діють мітка ворога, димова
## завіса й критичні удари.
## source — хто вдарив: &"weapon" (зброя), id здібності чи пасивки. Для
## екрана підсумків данжу (damage_by_source).
func deal_damage(enemy: Enemy3D, multiplier: float, knockback: Vector3, heavy: bool,
		source: StringName = &"weapon") -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	var hp_before := enemy.current_hp'''),
    ('''	enemy.take_damage(amount, knockback * _knockback_factor, crit, heavy)
	hit_landed.emit(amount, crit)''', '''	enemy.take_damage(amount, knockback * _knockback_factor, crit, heavy)
	# Скільки здоров'я ворог справді втратив (щит, тотем і добивання
	# вже враховані).
	var dealt := maxf(hp_before - enemy.current_hp, 0.0)
	damage_by_source[source] = float(damage_by_source.get(source, 0.0)) + dealt
	hit_landed.emit(amount, crit)'''),
    ('''var hero_def: HeroDef
''', '''var hero_def: HeroDef
## Скільки шкоди завдало кожне джерело за похід: {&"weapon": ..., id здібності: ...}.
var damage_by_source: Dictionary = {}
'''),
])

for rel in ["scenes/combat/skills/fire_ring.gd", "scenes/combat/skills/frost_nova.gd",
            "scenes/combat/skills/moon_storm.gd", "scenes/combat/skills/rage_dash.gd",
            "scenes/combat/skills/rune_nova.gd", "scenes/combat/skills/whirlwind.gd",
            "scenes/combat/skills/passive_death_mark.gd", "scenes/combat/skills/passive_phoenix.gd",
            "scenes/combat/skills/passive_rune_charge.gd"]:
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    import re
    calls = re.findall(r"player\.deal_damage\(([^\n]*)\)\n", s)
    assert len(calls) == 1, (rel, calls)
    old = "player.deal_damage(%s)\n" % calls[0]
    new = "player.deal_damage(%s, id)\n" % calls[0]
    s = s.replace(old, new)
    open(p, "w", encoding="utf-8", newline="\n").write(s)

patch("scenes/combat/spell_bolt.gd", [
    ('''var kind := "arcane"
''', '''var kind := "arcane"
## Хто випустив: &"weapon" (посох) чи id здібності — для підсумків походу.
var source: StringName = &"weapon"
'''),
    ('''		_player.deal_damage(enemy, damage_multiplier, push.normalized() * 0.6, false)''',
     '''		_player.deal_damage(enemy, damage_multiplier, push.normalized() * 0.6, false, source)'''),
])
patch("scenes/combat/rune_seal.gd", [
    ('''var radius := 1.7
''', '''var radius := 1.7
## Хто поставив печать: &"weapon" (книга рун) чи id здібності.
var source: StringName = &"weapon"
'''),
    ('''		_player.deal_damage(enemy, damage, push.normalized() * (2.5 if big else 1.2), big)''',
     '''		_player.deal_damage(enemy, damage, push.normalized() * (2.5 if big else 1.2), big, source)'''),
])
patch("scenes/combat/poison_cloud.gd", [
    ('''var radius := 2.0
''', '''var radius := 2.0
## Хто лишив хмару: &"weapon" (посох отрути) чи id здібності.
var source: StringName = &"weapon"
'''),
    ('''		_player.deal_damage(enemy, tick_damage, Vector3.ZERO, false)''',
     '''		_player.deal_damage(enemy, tick_damage, Vector3.ZERO, false, source)'''),
])
patch("scenes/combat/skills/great_seal.gd", [
    ('''	RuneSeal.spawn(player.get_parent(), player, at, RADIUS * sqrt(player.spell_power()), DELAY, DAMAGE, HOLD)''',
     '''	var seal := RuneSeal.spawn(player.get_parent(), player, at, RADIUS * sqrt(player.spell_power()), DELAY, DAMAGE, HOLD)
	seal.source = id'''),
])
patch("scenes/combat/skills/venom_swamp.gd", [
    ('''	PoisonCloud.spawn(player.get_parent(), player, at, RADIUS * sqrt(player.spell_power()), DURATION,
		TICK_DAMAGE, SLOW)''', '''	var cloud := PoisonCloud.spawn(player.get_parent(), player, at, RADIUS * sqrt(player.spell_power()), DURATION,
		TICK_DAMAGE, SLOW)
	cloud.source = id'''),
])
patch("scenes/combat/skills/arcane_barrage.gd", [
    ('''		var bolt := SpellBolt.create(player, "arcane", DAMAGE, color)
''', '''		var bolt := SpellBolt.create(player, "arcane", DAMAGE, color)
		bolt.source = id
'''),
])
patch("scenes/combat/skills/card_storm.gd", [
    ('''		var card := SpellBolt.create(player, "card", DAMAGE * player.spell_power(), color)
''', '''		var card := SpellBolt.create(player, "card", DAMAGE * player.spell_power(), color)
		card.source = id
'''),
])
print("patched")
