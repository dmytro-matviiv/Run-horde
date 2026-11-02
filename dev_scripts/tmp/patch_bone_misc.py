# 4-й данж: дрібниці Enemy3D (анімація смерті, висота виринання), реєстр
# здібностей, стиль фаз боса, прогрів моделей здібностей у данжі.
import sys
ROOT = r"D:\Claude code\idle survivor_like\scenes\dungeon"


def patch(path, pairs):
    s = open(path, encoding="utf-8").read()
    for old, new in pairs:
        n = s.count(old)
        if n != 1:
            sys.exit("NOT FOUND x%d in %s: %r" % (n, path, old[:90]))
        s = s.replace(old, new)
    open(path, "w", encoding="utf-8").write(s)


patch(ROOT + r"\enemy_3d.gd", [
    ("""var untargetable := false
""", """var untargetable := false
## Яку анімацію грати, падаючи (бос, що вже лежить купою кісток, — "Down").
var death_anims: Array = ["Death"]
## Висота моделі в стійці (після _normalize_size) — сюди вертається emerge().
var _model_rest_y := 0.0
"""),
    ("""	paint_model(_model, definition.get("tint", Color.WHITE), definition.get("glow", Color.BLACK))
	_normalize_size()
""", """	paint_model(_model, definition.get("tint", Color.WHITE), definition.get("glow", Color.BLACK))
	_normalize_size()
	_model_rest_y = _model.position.y
"""),
    ("""func emerge(seconds: float) -> void:
	var rest := _model.position.y
	_model.position.y = rest - target_height - 0.3
""", """func emerge(seconds: float) -> void:
	var rest := _model_rest_y
	_model.position.y = rest - target_height - 0.3
"""),
    ("""	tween.tween_property(_model, "position:y", _model.position.y - target_height - 0.3, seconds).set_ease(Tween.EASE_IN)""",
     """	tween.tween_property(_model, "position:y", _model_rest_y - target_height - 0.3, seconds).set_ease(Tween.EASE_IN)"""),
    ("""	_play_once(["Death"])
	# Даємо дограти смерть""", """	_play_once(death_anims)
	# Даємо дограти смерть"""),
])

patch(ROOT + r"\abilities\enemy_abilities.gd", [
    ("""##   mirror_split — (мега-бос) розколюється на тьмяних двійників-приманок.
""", """##   mirror_split — (мега-бос) розколюється на тьмяних двійників-приманок.
## Кістяний Погост (4-й данж):
##   vanish       — привид зникає (видно лише ланцюг) і б'є з-за спини;
##   grave_escape — чаклун тікає в могилу, коли герой надто близько;
##   tunnel       — хробак повзе під землею й вистрибує під героєм;
##   poison_cloud — отруйна хмара довкола; death_blast — гине з вибухом;
##   empower      — тотем: союзники б'ють сильніше й лікуються;
##   scythe_sweep, scythe_throw, army_of_dead, eternal_lord, bone_spikes —
##                  прийоми Кістяного Володаря.
"""),
    ("""	"mirror_split": preload("res://scenes/dungeon/abilities/mirror_split_ability.gd"),
""", """	"mirror_split": preload("res://scenes/dungeon/abilities/mirror_split_ability.gd"),
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
"""),
])

patch(ROOT + r"\boss_phases.gd", [
    ("""	"frost_dragon": {"color": Color(0.55, 0.9, 1.0), "rage": "злітає в небо", "frenzy": "кличе вічну зиму"},
""", """	"frost_dragon": {"color": Color(0.55, 0.9, 1.0), "rage": "злітає в небо", "frenzy": "кличе вічну зиму"},
	"bone_lord": {"color": Color(0.45, 1.0, 0.5), "rage": "кличе армію мертвих", "frenzy": "стає вічним"},
"""),
])

patch(ROOT + r"\dungeon.gd", [
    ("""	models.append(_model(_level.boss.model))
	if _level.boss.has("summon"):
		models.append(_model(_level.boss.summon.model))
""", """	models.append(_model(_level.boss.model))
	if _level.boss.has("summon"):
		models.append(_model(_level.boss.summon.model))
	# Кого кличуть здібності (мерці, тотеми, череп) і що вони кидають (коса):
	# перша поява теж не має смикати кадр.
	var extra: Array[String] = []
	_collect_models(_level.enemies, extra)
	_collect_models(_level.boss.get("abilities", []), extra)
	for path in extra:
		var scene := _model(path)
		if not models.has(scene):
			models.append(scene)
"""),
    ("""## Відстань від героя до найближчої точки шматка на площині.""", """## Шляхи до моделей усередині описів здібностей ("model", "prop", "shell").
func _collect_models(value: Variant, out: Array[String]) -> void:
	if value is Dictionary:
		for key: Variant in value:
			var item: Variant = value[key]
			if key in ["model", "prop", "shell"] and item is String and String(item).ends_with(".glb"):
				if not out.has(item):
					out.append(item)
			else:
				_collect_models(item, out)
	elif value is Array:
		for item: Variant in value:
			_collect_models(item, out)

## Відстань від героя до найближчої точки шматка на площині."""),
])
print("OK misc")
