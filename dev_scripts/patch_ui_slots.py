# -*- coding: utf-8 -*-
# Екрани: 3D-вітрина героя та зброї, слоти під іконки.
import os
os.chdir(r'D:\Claude code\idle survivor_like')


def patch(path, pairs):
    s = open(path, encoding='utf-8').read()
    for a, b in pairs:
        assert a in s, (path, a[:80])
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8', newline='\n').write(s)
    print('patched', path)


# --- Екран вибору героя: 3D-модель замість картинки ---
patch('scenes/ui/heroes.gd', [
    ('''## Екран вибору героя — вітрина, а не список. Гравець гортає героїв по
## одному: у центрі великий живий персонаж (той самий SpriteAnimator, що
## й у бою — дихає, погойдується, підсвічується), під ним опис і три
## іконки здібностей. Натиснув іконку — прочитав, що саме вміє цей клас.''',
     '''## Екран вибору героя — вітрина, а не список. Гравець гортає героїв по
## одному: у центрі 3D-модель, та сама, що й у бою, зі спорядженою
## зброєю в руці; під нею опис і картки здібностей. Натиснув картку —
## прочитав, що саме вміє цей клас.
##
## Якщо моделі героя ще немає, показується тимчасова в його кольорі, і
## екран чесно про це пише. Покладіть файл
## res://assets/models/heroes/<id героя>.glb — і він з'явиться тут сам.'''),
    ('''const ABILITY_ICON_SCRIPT := preload("res://scenes/ui/ability_icon.gd")
const ART_HEIGHT := 300.0
const FLOAT_SPEED := 1.6
const FLOAT_HEIGHT := 8.0''',
     '''const ABILITY_ICON_SCRIPT := preload("res://scenes/ui/ability_icon.gd")
const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")'''),
    ('''var _index := 0
var _animator: SpriteAnimator
var _float_phase := 0.0

func _ready() -> void:
	_animator = SpriteAnimator.new()
	add_child(_animator)
	popup.visible = false''',
     '''var _index := 0
var _preview: ModelPreview
var _placeholder_label: Label

func _ready() -> void:
	_build_preview()
	popup.visible = false'''),
    ('''func _process(delta: float) -> void:
	# Легке "ширяння" поверх дихання аніматора — героя видно живим
	# навіть коли гравець просто роздивляється.
	_float_phase += delta * FLOAT_SPEED
	art_pivot.position = stage.size * 0.5 + Vector2(0, sin(_float_phase) * FLOAT_HEIGHT)
	glow.queue_redraw()''',
     '''## Вітрина кладеться поверх старої "сцени" зі спрайтом: сам спрайт
## ховаємо, а підсвічування знизу лишаємо — воно гарне.
func _build_preview() -> void:
	hero_art.visible = false
	_preview = MODEL_PREVIEW_SCRIPT.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_preview)

	_placeholder_label = Label.new()
	_placeholder_label.text = "Тимчасова модель — справжня буде пізніше"
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.add_theme_font_size_override("font_size", 13)
	_placeholder_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_placeholder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_placeholder_label)

func _process(_delta: float) -> void:
	glow.queue_redraw()'''),
    ('''func _update_art(def: HeroDef) -> void:
	if def.texture == null:
		hero_art.visible = false
		return
	hero_art.visible = true
	hero_art.texture = def.texture
	hero_art.scale = Vector2.ONE * (ART_HEIGHT / float(def.texture.get_height()))
	# Той самий аніматор, що й у бою: герой дихає, а не стоїть картинкою.
	_animator.setup(hero_art, def.texture, def.texture_back)
	_animator.reset()
	_animator.set_move_direction(Vector2.ZERO)''',
     '''func _update_art(def: HeroDef) -> void:
	var weapon := WeaponPool.get_def(GameState.get_equipped_weapon_id(def.id))
	_placeholder_label.visible = _preview.show_hero(def, weapon)'''),
    ('''	var weapons := WeaponPool.get_for_hero(def.id).size()
	stats_label.text = "Здоров'я %d    Швидкість %+d%%    Зброї: %d" % [hp, speed_percent, weapons]''',
     '''	var weapon := WeaponPool.get_def(GameState.get_equipped_weapon_id(def.id))
	stats_label.text = "Здоров'я %d    Швидкість %+d%%    Зброя: %s" % [hp, speed_percent, weapon.title]'''),
    ('''	for card: Dictionary in HeroShowcase.get_cards(def.id):''',
     '''	for card: Dictionary in _cards_for(def):'''),
    ('''func _update_action(def: HeroDef) -> void:''',
     '''## Картки здібностей беремо з того, що герой СПРАВДІ вміє в бою
## (Skills3D), а не з окремого опису — тоді вітрина не бреше. Третьою
## йде картка про арсенал зброї.
func _cards_for(def: HeroDef) -> Array:
	var cards := []
	for entry: Dictionary in Skills3D.describe(def):
		cards.append({
			"kind": &"talent" if entry.kind == &"passive" else &"blade",
			"color": entry.color,
			"title": entry.title,
			"text": entry.text,
		})
	var weapons := WeaponPool.get_for_hero(def.id)
	var lines := []
	for weapon: WeaponDef in weapons:
		lines.append("%s — %s" % [weapon.title, weapon.description])
	cards.append({
		"kind": &"weapon", "color": Color(1.0, 0.85, 0.4),
		"title": "Арсенал",
		"text": "\\n".join(lines),
	})
	return cards

func _update_action(def: HeroDef) -> void:'''),
])

# --- Екран зброї: вітрина обраної зброї + слот під іконку ---
patch('scenes/ui/weapons.gd', [
    ('''const WEAPON_ICON_SCRIPT := preload("res://scenes/ui/weapon_icon.gd")''',
     '''const WEAPON_ICON_SCRIPT := preload("res://scenes/ui/weapon_icon.gd")
const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")'''),
    ('''func _ready() -> void:''',
     '''var _preview: ModelPreview
var _preview_note: Label

## Над списком — 3D-вітрина спорядженої зброї: видно, що саме герой
## візьме в руку. Немає моделі — показуємо тимчасову й пишемо про це.
func _build_preview() -> void:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(0, 190)
	_preview = MODEL_PREVIEW_SCRIPT.new()
	_preview.custom_minimum_size = Vector2(0, 160)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(_preview)
	_preview_note = Label.new()
	_preview_note.text = "Тимчасова модель зброї — справжню підключимо пізніше"
	_preview_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_note.add_theme_font_size_override("font_size", 13)
	_preview_note.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	holder.add_child(_preview_note)
	var column: VBoxContainer = $VBoxContainer
	column.add_child(holder)
	column.move_child(holder, 3)

func _ready() -> void:
	_build_preview()'''),
    ('''func _rebuild() -> void:''',
     '''func _show_equipped() -> void:
	var equipped := GameState.get_equipped_weapon_id(GameState.selected_hero_id)
	var def := WeaponPool.get_def(equipped)
	if def != null and _preview != null:
		_preview_note.visible = _preview.show_weapon(def)

func _rebuild() -> void:
	_show_equipped()'''),
])

# --- Таланти: слоти під іконки ---
patch('scenes/ui/meta_upgrades.gd', [
    ('''	&"talent_bolt_pierce": {"title": "Пробивна Руна", "per_level": "+1 пробиття магічного болта"},
	&"talent_extra_blades": {"title": "Вихор Клинків", "per_level": "+1 орбітальний клинок"},
	&"talent_aura_power": {"title": "Багаття Люті", "per_level": "+радіус і шкода аури"},
	&"talent_shadow_clones": {"title": "Володар Тіней", "per_level": "клони приходять частіше й б'ють сильніше"},''',
     '''	&"talent_bolt_pierce": {"title": "Пробивна Руна", "per_level": "+0.4 м до радіуса Рунної Нови"},
	&"talent_extra_blades": {"title": "Вихор Клинків", "per_level": "+18% шкоди Вихору, -0.4 с перезарядки"},
	&"talent_aura_power": {"title": "Багаття Люті", "per_level": "+15% шкоди й +0.2 м радіуса Вогняного Кола"},
	&"talent_shadow_clones": {"title": "Володар Тіней", "per_level": "+0.5 с Димової Завіси"},'''),
    ('''func _build_row(id: StringName, title: String, per_level: String) -> Control:''',
     '''## Рядок таланту. Ліворуч — місце під іконку: щойно покладете файл
## res://assets/ui/icons/talents/<id таланту>.png, вона з'явиться тут
## замість кольорової заглушки.
func _build_row(id: StringName, title: String, per_level: String) -> Control:'''),
])
