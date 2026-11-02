import io
import os

os.chdir(r"D:\Claude code\idle survivor_like")


def edit(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:80])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(s)


edit('scenes/dungeon/dungeon.gd', [
('''## ВІДЧУТТЯ ВБИВСТВА.''', '''## СЕРІЯ УДАРІВ (ComboMeter): нагороди на порогах 10 / 25 / 50 ударів
## без пропущеного удару по собі.
const COMBO_ATTACK_SPEED := 1.15
const COMBO_DAMAGE := 1.3
const COMBO_HEAL := 0.15
const COMBO_BUFF_TIME := 6.0
const COMBO_COLOR := Color(1.0, 0.86, 0.4)
const PERFECT_DODGE_COLOR := Color(0.5, 0.95, 1.0)

## ВІДЧУТТЯ ВБИВСТВА.'''),
('''var _arena_status := ""
var _banner: Control
''', '''var _arena_status := ""
var _banner: Control
var _callout: Control
var _combo: ComboMeter
var _last_hp := 0.0
'''),
('''	combat_buttons.setup(player)
''', '''	combat_buttons.setup(player)
	# Серія ударів — праворуч над бойовими кнопками.
	_combo = ComboMeter.new()
	hud.add_child(_combo)
	_combo.tier_reached.connect(_on_combo_tier)
	player.hit_landed.connect(func(_amount: float, _crit: bool) -> void: _combo.add_hit())
	player.perfect_dodge.connect(_on_perfect_dodge)
'''),
('''func _on_player_health_changed(current: float, maximum: float) -> void:
	health_label.text = "%d / %d" % [ceili(current), int(maximum)]''', '''func _on_player_health_changed(current: float, maximum: float) -> void:
	# Пропустив удар — серія згорає.
	if _combo != null and current < _last_hp - 0.01:
		_combo.reset()
	_last_hp = current
	health_label.text = "%d / %d" % [ceili(current), int(maximum)]'''),
('''## Великий напис угорі посередині ("Засідка!", "Хвиля 2") — на пару''', '''func _on_combo_tier(tier: int, title: String) -> void:
	var reward := ""
	match tier:
		1:
			player.add_attack_speed(COMBO_ATTACK_SPEED, COMBO_BUFF_TIME)
			reward = "удари швидші"
		2:
			player.add_damage_buff(COMBO_DAMAGE, COMBO_BUFF_TIME)
			reward = "+30% шкоди"
		3:
			player.heal(player.max_hp * COMBO_HEAL)
			reward = "+15% здоров'я"
	_show_callout(title, reward, COMBO_COLOR)

func _on_perfect_dodge() -> void:
	_show_callout("Ідеально!", "2 с усі удари критичні", PERFECT_DODGE_COLOR)

## Короткий напис посеред екрана ("Ідеально!", "Серія!") — вискакує й
## тане за секунду, не заважаючи бою.
func _show_callout(title: String, subtitle: String, color: Color) -> void:
	if _callout != null and is_instance_valid(_callout):
		_callout.queue_free()
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.hud_text(heading, 32, color)
	column.add_child(heading)
	if subtitle != "":
		var line := Label.new()
		line.text = subtitle
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiTheme.hud_text(line, 16)
		column.add_child(line)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	holder.offset_top = -150.0
	holder.offset_bottom = -70.0
	holder.add_child(column)
	hud.add_child(holder)
	_callout = holder
	holder.pivot_offset = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 40)
	holder.scale = Vector2.ONE * 1.35
	var tween := holder.create_tween()
	tween.tween_property(holder, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.7)
	tween.tween_property(holder, "modulate:a", 0.0, 0.35)
	tween.tween_callback(holder.queue_free)

## Великий напис угорі посередині ("Засідка!", "Хвиля 2") — на пару'''),
])
print('ok')
