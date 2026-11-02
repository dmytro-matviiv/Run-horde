# -*- coding: utf-8 -*-
"""Фінальний бос: аура, фазові анімації, черга ударів, рев переходу фази,
живі двійники на окремій темній моделі."""
ROOT = "D:/Claude code/idle survivor_like/"


def patch(rel, reps):
    p = ROOT + rel
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (rel, a[:70])
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8", newline="\n").write(s)


patch("scenes/dungeon/enemy_3d.gd", [
    ("var phases: BossPhases\n", "var phases: BossPhases\n## Аура фінального боса (опис \"aura\") — див. BossAura.\nvar aura: BossAura\n"),
    # двійник — живий, а не стовп
    ('''		"totem":
			kind = Kind.MELEE
			stationary = true
			attack_range = 0.0
			aggro_range = 30.0''', '''		"totem":
			kind = Kind.MELEE
			stationary = true
			attack_range = 0.0
			aggro_range = 30.0
		"decoy":
			# Двійник боса: бігає й б'є, як справжній (слабше), але падає з
			# одного удару. Одразу бачить героя — в залі боса ховатись ніде.
			kind = Kind.MELEE
			attack_range = 2.6
			aggro_range = 40.0'''),
    # аура в боса
    ('''	aggro_range = 18.0
	attack_range = 3.0
	slam_every = 3
''', '''	aggro_range = 18.0
	attack_range = 3.0
	slam_every = 3
	if definition.has("aura"):
		aura = BossAura.new()
		add_child(aura)
		aura.configure(definition.aura, target_height)
'''),
    # аура ховається разом із моделлю (мерехтіння)
    ('''	_hidden = hidden
	_model.visible = not hidden''', '''	_hidden = hidden
	_model.visible = not hidden
	if aura != null:
		aura.visible = not hidden'''),
    # смерть: аура згасає
    ('''	_fuse_left = -1.0
	_charge_state = 0
	_dying = true''', '''	_fuse_left = -1.0
	_charge_state = 0
	_dying = true
	if aura != null:
		aura.collapse()
		aura = null'''),
    # удари по черзі
    ('''	velocity.x = 0.0
	velocity.z = 0.0
	_play_once(["Punch", "Bite_Front", "Headbutt", "Weapon"])
''', '''	velocity.x = 0.0
	velocity.z = 0.0
	# Свої удари по черзі ("attack_anims": правою, лівою...), інакше — що є.
	var attack_anims: Array = definition.get("attack_anims", [])
	if not attack_anims.is_empty():
		_play_once([attack_anims[_attack_counter % attack_anims.size()]] + ["Punch", "Weapon"])
	else:
		_play_once(["Punch", "Bite_Front", "Headbutt", "Weapon"])
'''),
    # фазові стійка й біг
    ('''	if wanted == "Idle" and _turning:
		candidates = ["Turn", "Idle"]''', '''	if wanted == "Idle" and _turning:
		candidates = ["Turn", "Idle"]
	# Фінальний бос у фазах 2-3 стоїть у хижій стійці, а в нестямі — біжить.
	elif wanted == "Idle" and phases != null and phases.phase >= 2:
		candidates = ["Idle_Rage", "Idle"]
	if wanted == "Walk" and phases != null and phases.phase >= 3:
		candidates = ["Run", "Walk"]'''),
])

patch("scenes/dungeon/boss_phases.gd", [
    ('''	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.3)
	AudioManager.play(&"explosion")''', '''	# Свій рев переходу фази (модель має "Roar"): бос завмирає й реве, аура
	# густішає й набирає колір люті, з неба б'є стовп світла.
	_boss.play_once(["Roar"])
	if _boss.aura != null:
		_boss.hold_still(1.5)
		_boss.aura.set_phase(phase)
		CombatVfx.sky_beam(parent, _boss.global_position, style.color)
		CombatVfx.shockwave(parent, _boss.global_position, 11.0, style.color.lerp(Color.WHITE, 0.4), 0.9)
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig != null:
		rig.shake(0.3)
	AudioManager.play(&"explosion")'''),
])

patch("scenes/dungeon/abilities/mirror_split_ability.gd", [
    ('''## ДЗЕРКАЛЬНИЙ РОЗКОЛ (лише мега-боси). Бос розколюється на кілька
## примар-двійників — той самий вигляд, та сама поза, розставлені по
## залі. Двійники не б'ють і падають з одного удару (kind "totem":
## не рухаються, attack_range 0) — і тьмяніші, без сяйва, тож зблизька
## видно різницю, а на бігу від справжнього боса не відрізниш. У
## нестямі (фаза 3) двійників троє замість двох — гадати важче.''', '''## ДЗЕРКАЛЬНИЙ РОЗКОЛ (лише мега-боси). Бос розколюється на кілька
## примар-двійників, розставлених по залі. Якщо в описі боса є
## "clone_model" (фінальний бос: справжній — білий, двійники — темні),
## двійники ЖИВІ (kind "decoy"): біжать до героя й б'ють (слабше за боса),
## але падають з одного удару. Без неї — як раніше: тьмяні нерухомі
## примари, що не б'ють (kind "totem"). У нестямі (фаза 3) двійників
## троє замість двох.'''),
    ('''	var decoy := enemy.definition.duplicate(true)
	decoy.kind = "totem"
	decoy.hp = 1.0
	decoy.damage = 0.0
	decoy.no_elite = true
	decoy.xp = 0
	decoy.tint = DIM_TINT
	decoy.glow = Color.BLACK''', '''	var decoy := enemy.definition.duplicate(true)
	decoy.hp = 1.0
	decoy.no_elite = true
	decoy.xp = 0
	if decoy.has("clone_model"):
		decoy.model = decoy.clone_model
		decoy.kind = "decoy"
		decoy.damage = float(decoy.get("damage", 10.0)) * CLONE_DAMAGE_SHARE
		decoy.speed = float(decoy.get("speed", 3.0)) * 0.9
		decoy.tint = Color.WHITE
		decoy.glow = Color.BLACK
	else:
		decoy.kind = "totem"
		decoy.damage = 0.0
		decoy.tint = DIM_TINT
		decoy.glow = Color.BLACK
	decoy.erase("aura")
	decoy.erase("transform_tints")
	decoy.erase("transform_glows")'''),
    ('''const DIM_TINT := Color(0.5, 0.5, 0.62)''', '''const DIM_TINT := Color(0.5, 0.5, 0.62)
## Скільки шкоди від боса б'є живий двійник.
const CLONE_DAMAGE_SHARE := 0.3'''),
])

patch("scenes/dungeon/dungeon_levels.gd", [
    ('''		"boss": {"name": "Тіньовий Володар", "model": "res://assets/models/monsters/Ninja.glb", "style": "shadow",
			"hp": 1600.0, "damage": 32.0, "speed": 3.6, "height": 3.6, "xp": 600,
			"tint": Color(0.3, 0.15, 0.45), "glow": Color(0.5, 0.1, 0.8),
			"transform_tints": [Color(0.2, 0.08, 0.35), Color(0.08, 0.02, 0.2)],
			"transform_glows": [Color(0.6, 0.15, 0.9), Color(0.85, 0.2, 1.0)],''', '''		# Тіньовий Володар — моделі гравця: біла (сам бос) і темна (двійники),
		# скелет і анімації — D:/RuneHorde_work/scripts/blender/rig_final.py:
		# Idle, Idle_Rage (фази 2-3), Walk, Run (фаза 3), Turn, Weapon/Weapon2
		# (удари по черзі), Cast (промені), Summon (розкол), Roar (перехід
		# фази), Jump, HitReact, Death. Аура (BossAura) — рунне коло й іскри.
		"boss": {"name": "Тіньовий Володар", "model": "res://assets/models/monsters/shadow_lord.glb", "style": "shadow",
			"clone_model": "res://assets/models/monsters/shadow_lord_clone.glb",
			"hp": 1600.0, "damage": 32.0, "speed": 3.6, "height": 3.6, "xp": 600,
			"attack_anims": ["Weapon", "Weapon2"],
			"special_anims": {"mirror_split": ["Summon"], "beams": ["Cast"]},
			"aura": {"color": Color(0.75, 0.55, 1.0), "rage_color": Color(1.0, 0.25, 0.85), "radius": 3.2},
			"transform_tints": [Color(0.95, 0.9, 1.0), Color(0.9, 0.82, 1.0)],
			"transform_glows": [Color(0.35, 0.1, 0.6), Color(0.6, 0.15, 0.9)],'''),
    ('''		"subtitle": "Фінальний мега-бос. Двійники не б'ють, та відрізнити їх від справжнього можна лише зблизька.",''',
     '''		"subtitle": "Фінальний мега-бос. Його темні двійники нападають, та падають з одного удару.",'''),
])
print("patched")
