extends Control
class_name NpcDialog

## Розмова з NPC: панель унизу екрана — ім'я, що він каже, і кнопки дій
## ("Обрати героя", "Взяти завдання", "Здати завдання", "До побачення").
## Хто що каже й які кнопки — вирішує Прихисток (haven.gd).

signal choice_made(id: String)

const BOX_WIDTH := 820.0
const PORTRAIT_SIZE := 132.0
const PORTRAIT_DIR := "res://assets/ui/kit/portraits/"

var _name: Label
var _text: Label
var _buttons: HBoxContainer
var _portrait: TextureRect

## Портрет жителя (знятий із його ж 3D-моделі) у золотому медальйоні.
static func portrait_of(npc_id: StringName) -> Texture2D:
	var path := PORTRAIT_DIR + String(npc_id) + ".png"
	return load(path) if ResourceLoader.exists(path) else null

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Затемнення знизу: розмова — на першому плані, світ — тлом.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.ACCENT))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -BOX_WIDTH * 0.5
	panel.offset_right = BOX_WIDTH * 0.5
	panel.offset_bottom = -18.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_name = Label.new()
	UiTheme.hud_text(_name, 24, UiTheme.GOLD)
	column.add_child(_name)
	_text = Label.new()
	UiTheme.hud_text(_text, 19, UiTheme.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(BOX_WIDTH - 60.0 - PORTRAIT_SIZE - 16.0, 0)
	column.add_child(_text)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_buttons)

## Показати репліку й кнопки: choices — [[id, напис, головна?], ...].
func show_line(speaker: String, text: String, choices: Array, npc_id: StringName = &"") -> void:
	_portrait.texture = portrait_of(npc_id)
	_portrait.visible = _portrait.texture != null
	_name.text = speaker
	_text.text = text
	for child in _buttons.get_children():
		child.queue_free()
	for choice: Array in choices:
		var button := Button.new()
		button.text = choice[1]
		button.custom_minimum_size = Vector2(170, 52)
		button.add_theme_font_size_override("font_size", 18)
		if choice.size() > 2 and choice[2]:
			UiTheme.art_primary(button)
		else:
			UiTheme.art_secondary(button)
		button.pressed.connect(func() -> void: choice_made.emit(String(choice[0])))
		_buttons.add_child(button)
	visible = true
