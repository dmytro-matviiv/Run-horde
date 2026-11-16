extends Control

## СТВОРЕННЯ ПЕРСОНАЖА. Персонаж стоїть на рунічному постаменті посеред
## зали (живий, крутиться пальцем), ліворуч — вибір вигляду: ім'я, стать,
## шкіра, зачіска, колір волосся, борода, очі. Зріст і статура в усіх
## однакові — так уся броня сідає однаково (CharacterBuilder).
## "Створити" — новий персонаж з чистим прогресом, одразу в Прихисток.

const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")
const SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const HAVEN_SCENE := "res://scenes/world/haven/haven.tscn"
const PEDESTAL_Y := 0.665
const NAMES_MALE := ["Ярослав", "Богдан", "Остап", "Тарас", "Мирослав", "Святослав", "Захар", "Назар"]
const NAMES_FEMALE := ["Дарина", "Мирослава", "Злата", "Оксана", "Леся", "Яромира", "Ольга", "Соломія"]

var _look := CharacterBuilder.DEFAULT_LOOK.duplicate()
var _preview: ModelPreview
var _name_edit: LineEdit
var _gender_buttons: Array[Button] = []
var _hair_label: Label
var _beard_row: Control
var _beard_button: Button
var _swatch_groups := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.add_background(self, [UiTheme.BG_HEROES])
	_look.gender = "male" if randf() < 0.5 else "female"
	_look.skin = randi() % CharacterBuilder.SKIN_TONES.size()
	_look.hair_color = randi() % 4

	_preview = MODEL_PREVIEW_SCRIPT.new()
	_preview.interactive = true
	_preview.anchor_left = 0.5
	_preview.anchor_right = 0.5
	_preview.anchor_top = PEDESTAL_Y
	_preview.anchor_bottom = PEDESTAL_Y
	_preview.offset_left = -190.0
	_preview.offset_right = 190.0
	_preview.offset_top = -380.0
	_preview.offset_bottom = 22.0
	add_child(_preview)

	var title := OrnateBanner.new("Новий герой", 28)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -210.0
	title.offset_right = 210.0
	title.offset_top = 2.0
	title.offset_bottom = 86.0
	add_child(title)
	if not SaveManager.characters().is_empty():
		var back := _round_button("btn_back.png")
		back.position = Vector2(18, 14)
		back.pressed.connect(func() -> void: get_tree().change_scene_to_file(SELECT_SCENE))
		add_child(back)

	var panel := OrnatePanel.new()
	panel.position = Vector2(18, 86)
	panel.custom_minimum_size = Vector2(380, 0)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Ім'я героя"
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, 42)
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.add_theme_stylebox_override("normal", UiTheme.inset_box())
	_name_edit.add_theme_stylebox_override("focus", UiTheme.inset_box(Color(1.15, 1.1, 0.9)))
	_name_edit.add_theme_color_override("font_color", UiTheme.GOLD)
	column.add_child(_row("Ім'я", _name_edit))

	var genders := HBoxContainer.new()
	genders.add_theme_constant_override("separation", 8)
	for gender: Array in [["male", "Чоловік"], ["female", "Жінка"]]:
		var button := Button.new()
		button.text = gender[1]
		button.custom_minimum_size = Vector2(110, 40)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_set_gender.bind(gender[0]))
		genders.add_child(button)
		_gender_buttons.append(button)
	column.add_child(_row("Стать", genders))

	column.add_child(_row("Шкіра", _swatches("skin", CharacterBuilder.SKIN_TONES)))

	var hair_row := HBoxContainer.new()
	hair_row.add_theme_constant_override("separation", 6)
	var prev := _round_button("btn_back.png", 38.0)
	prev.pressed.connect(_shift_hair.bind(-1))
	hair_row.add_child(prev)
	_hair_label = Label.new()
	_hair_label.custom_minimum_size = Vector2(110, 0)
	_hair_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hair_label.add_theme_font_size_override("font_size", 17)
	hair_row.add_child(_hair_label)
	var next := _round_button("btn_back.png", 38.0)
	next.flip_h = true
	next.pressed.connect(_shift_hair.bind(1))
	hair_row.add_child(next)
	column.add_child(_row("Зачіска", hair_row))

	column.add_child(_row("Волосся", _swatches("hair_color", CharacterBuilder.HAIR_COLORS)))
	_beard_button = Button.new()
	_beard_button.custom_minimum_size = Vector2(110, 40)
	_beard_button.add_theme_font_size_override("font_size", 16)
	_beard_button.pressed.connect(func() -> void:
		_look.beard = not _look.beard
		_refresh())
	_beard_row = _row("Борода", _beard_button)
	column.add_child(_beard_row)
	column.add_child(_row("Очі", _swatches("eyes", CharacterBuilder.EYE_COLORS)))

	var random := Button.new()
	random.text = "Випадково"
	random.custom_minimum_size = Vector2(200, 50)
	random.add_theme_font_size_override("font_size", 18)
	UiTheme.jelly(random, "gold")
	random.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	random.offset_left = -248.0
	random.offset_right = -18.0
	random.offset_top = -146.0
	random.offset_bottom = -94.0
	random.pressed.connect(_randomize)
	add_child(random)

	var create := Button.new()
	create.text = "Створити"
	create.custom_minimum_size = Vector2(230, 58)
	create.add_theme_font_size_override("font_size", 22)
	UiTheme.jelly(create, "green")
	create.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	create.offset_left = -248.0
	create.offset_right = -18.0
	create.offset_top = -80.0
	create.offset_bottom = -20.0
	create.pressed.connect(_on_create)
	add_child(create)

	_name_edit.text = _random_name()
	_refresh()
	var home := panel.position
	panel.position = home - Vector2(420, 0)
	panel.create_tween().tween_property(panel, "position", home, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _row(caption: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(92, 0)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", UiTheme.GOLD)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _round_button(file: String, side: float = 58.0) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = load(UiTheme.KIT_DIR + file)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(side, side)
	button.size = Vector2(side, side)
	return button

## Ряд кольорових кружків; обраний — у золотому обідку.
func _swatches(key: String, colors: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var buttons: Array[Button] = []
	for i in colors.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(34, 34)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.pressed.connect(func() -> void:
			_look[key] = i
			_refresh())
		swatch.set_meta(&"color", colors[i])
		row.add_child(swatch)
		buttons.append(swatch)
	_swatch_groups[key] = buttons
	return row

func _style_swatches() -> void:
	for key: String in _swatch_groups:
		var buttons: Array = _swatch_groups[key]
		for i in buttons.size():
			var swatch := buttons[i] as Button
			var box := UiTheme.make_box(swatch.get_meta(&"color"), 17, 3 if i == int(_look[key]) else 2,
				Color(1.0, 0.84, 0.35) if i == int(_look[key]) else UiTheme.OUTLINE)
			box.content_margin_left = 0
			box.content_margin_right = 0
			for state: String in ["normal", "hover", "pressed"]:
				swatch.add_theme_stylebox_override(state, box)

func _set_gender(gender: String) -> void:
	if _look.gender == gender:
		return
	_look.gender = gender
	if gender == "female":
		_look.beard = false
	_name_edit.text = _random_name()
	_refresh()

func _shift_hair(step: int) -> void:
	_look.hair = posmod(int(_look.hair) + step, CharacterBuilder.HAIRS.size())
	_refresh()

func _randomize() -> void:
	_look.gender = "male" if randf() < 0.5 else "female"
	_look.skin = randi() % CharacterBuilder.SKIN_TONES.size()
	_look.hair = randi() % CharacterBuilder.HAIRS.size()
	_look.hair_color = randi() % CharacterBuilder.HAIR_COLORS.size()
	_look.eyes = randi() % CharacterBuilder.EYE_COLORS.size()
	_look.beard = _look.gender == "male" and randf() < 0.4
	_name_edit.text = _random_name()
	_refresh()
	_preview.play_character_anim("Yes")

func _random_name() -> String:
	var pool: Array = NAMES_FEMALE if _look.gender == "female" else NAMES_MALE
	return pool[randi() % pool.size()]

func _refresh() -> void:
	for i in _gender_buttons.size():
		UiTheme.jelly(_gender_buttons[i], "green" if (["male", "female"][i] == _look.gender) else "blue")
	_hair_label.text = CharacterBuilder.HAIR_TITLES[int(_look.hair)]
	_beard_row.visible = _look.gender == "male"
	_beard_button.text = "Є" if _look.beard else "Немає"
	UiTheme.jelly(_beard_button, "green" if _look.beard else "blue")
	_style_swatches()
	_preview.show_character(_look)

func _on_create() -> void:
	var char_name := _name_edit.text.strip_edges()
	if char_name == "":
		char_name = _random_name()
	SaveManager.create_character(char_name, _look.duplicate())
	SceneLoader.change_scene(HAVEN_SCENE, "Прихисток")
