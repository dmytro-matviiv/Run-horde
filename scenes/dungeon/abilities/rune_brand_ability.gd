extends EnemyAbility

## КЛЕЙМО РУНИ (Володар Рун). Поки Володар чаклує, над героєм і під ним
## крутиться руна — це знак, що закляття вже на ньому. Каст скінчився —
## руна падає згори на місце героя: коло знаку на підлозі ширшає (warn),
## а герой тим часом обважнілий (slow). Тоді руна вибухає. Встиг вийти з
## кола чи перекотитись — ціла голова.
## Налаштування: windup, warn, radius, slow, damage.

const COLOR := Color(0.6, 0.35, 1.0)

var _marks: Array = []

func _init() -> void:
	id = "rune_brand"
	cooldown = 9.0

func try_use(_distance: float) -> bool:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return false
	start_cooldown()
	var windup := float(config.get("windup", 1.1))
	enemy.begin_special(id, windup, Color(COLOR, 0.0), 0.1)
	BossFx.hero_rune_mark(hero, COLOR, windup)
	return true

func resolve() -> void:
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var radius := float(config.get("radius", 2.3))
	var spot := hero.global_position
	spot.y = DungeonBuilder.FLOOR_TOP + 0.04
	if hero.has_method("apply_slow"):
		hero.apply_slow(float(config.get("slow", 0.6)), float(config.get("warn", 1.1)))
	# Знак на підлозі: велика руна, що наливається світлом.
	var glyph := BossFx.rune_glyph(Color(COLOR, 0.25), radius * 2.0)
	world().add_child(glyph)
	glyph.global_position = spot
	var material := glyph.material_override as StandardMaterial3D
	var tween := glyph.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.95, float(config.get("warn", 1.1)))
	# Згори падає світна руна-куля.
	var orb := Fx.make_sprite("magic_03", Color(0.85, 0.7, 1.0, 0.9), false, true)
	orb.scale = Vector3.ONE * 0.9
	world().add_child(orb)
	orb.global_position = spot + Vector3.UP * 7.0
	var fall := orb.create_tween()
	fall.tween_property(orb, "global_position", spot + Vector3.UP * 0.4, float(config.get("warn", 1.1))).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_marks.append({"spot": spot, "left": float(config.get("warn", 1.1)), "glyph": glyph, "orb": orb})

func tick(delta: float) -> void:
	super.tick(delta)
	for i in range(_marks.size() - 1, -1, -1):
		var m: Dictionary = _marks[i]
		m.left = float(m.left) - delta
		if float(m.left) > 0.0:
			continue
		_marks.remove_at(i)
		_explode(m)

func _explode(m: Dictionary) -> void:
	var spot: Vector3 = m.spot
	var radius := float(config.get("radius", 2.3))
	for key in ["glyph", "orb"]:
		if is_instance_valid(m[key]):
			(m[key] as Node).queue_free()
	Fx.bloom(world(), spot, "magic_03", radius * 2.4, Color(0.75, 0.5, 1.0), 0.5, true, true, 0.4, 1.2)
	CombatVfx.shockwave(world(), spot, radius, COLOR, 0.35)
	BossFx.dark_effect(world(), BossFx.DARK_AREA, spot, radius * 0.5, 0.8)
	var hero := player()
	if hero == null or not is_instance_valid(hero):
		return
	var off: Vector3 = hero.global_position - spot
	off.y = 0.0
	if off.length() <= radius and hero.take_damage(damage()):
		CombatVfx.impact(world(), hero.global_position + Vector3.UP * 0.8, COLOR, true)

func on_death() -> void:
	for m: Dictionary in _marks:
		for key in ["glyph", "orb"]:
			if is_instance_valid(m[key]):
				(m[key] as Node).queue_free()
	_marks.clear()
