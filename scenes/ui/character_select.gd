extends Control

## ВИБІР ПЕРСОНАЖА. Ліворуч — список персонажів (ім'я й рівень), обраний
## стоїть на постаменті посеред зали. "Грати" — у Прихисток цим
## персонажем, "Новий герой" — екран створення, "Видалити" — назавжди
## (з підтвердженням). Персонажів немає — одразу створення.

const MODEL_PREVIEW_SCRIPT := preload("res://scenes/ui/model_preview.gd")
const CREATE_SCENE := "res://scenes/ui/character_create.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const HAVEN_SCENE := "res://scenes/world/haven/haven.tscn"
const PEDESTAL_Y := 0.665
const MAX_CHARACTERS := 6

var _preview: ModelPreview
var _list: VBoxContainer
var _selected := ""
var _name_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if SaveManager.characters().is_empty():
		get_tree().change_scene_to_file.call_deferred(CREATE_SCENE)
		return
	UiTheme.add_background(self, [UiTheme.BG_HEROES])
	_selected = SaveManager.active_id()
	if _selected == "":
		_selected = String(SaveManager.characters()[0].id)

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

	var title := OrnateBanner.new("Твої герої", 28)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -210.0
	title.offset_right = 210.0
	title.offset_top = 2.0
	title.offset_bottom = 86.0
	add_child(title)
	var back := TextureButton.new()
	back.texture_normal = load(UiTheme.KIT_DIR + "btn_back.png")
	back.ignore_texture_size = true
	back.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back.size = Vector2(58, 58)
	back.position = Vector2(18, 14)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	add_child(back)

	var panel := OrnatePanel.new()
	panel.position = Vector2(18, 86)
	panel.custom_minimum_size = Vector2(320, 0)
	add_child(panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	panel.add_child(_list)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_name_label.offset_top = -190.0
	_name_label.offset_left = -200.0
	_name_label.offset_right = 200.0
	_name_label.add_theme_font_override("font", UiTheme.font(900))
	_name_label.add_theme_font_size_override("font_size", 30)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	_name_label.add_theme_constant_override("outline_size", 8)
	add_child(_name_label)

	var play := _corner_button("Грати", "green", -80.0, 58.0, 22)
	play.pressed.connect(_on_play)
	var delete := _corner_button("Видалити", "red", -146.0, 50.0, 18)
	delete.pressed.connect(_on_delete)
	_rebuild()

func _corner_button(text: String, color: String, top: float, height: float, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	UiTheme.jelly(button, color)
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -248.0
	button.offset_right = -18.0
	button.offset_top = top
	button.offset_bottom = top + height
	add_child(button)
	return button

func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	for entry: Dictionary in SaveManager.characters():
		var row := Button.new()
		row.custom_minimum_size = Vector2(280, 58)
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "  %s   •   рівень %d" % [entry.get("name", "Герой"), int(entry.get("level", 1))]
		row.add_theme_font_size_override("font_size", 18)
		var selected: bool = String(entry.id) == _selected
		var box := UiTheme.inset_box(Color(1.25, 1.15, 0.8) if selected else Color.WHITE)
		for state: String in ["normal", "hover", "pressed"]:
			row.add_theme_stylebox_override(state, box)
		row.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45) if selected else UiTheme.TEXT)
		row.pressed.connect(_on_pick.bind(String(entry.id)))
		_list.add_child(row)
	if SaveManager.characters().size() < MAX_CHARACTERS:
		var add := Button.new()
		add.text = "+  Новий герой"
		add.custom_minimum_size = Vector2(280, 52)
		add.add_theme_font_size_override("font_size", 18)
		UiTheme.jelly(add, "gold")
		add.pressed.connect(func() -> void: get_tree().change_scene_to_file(CREATE_SCENE))
		_list.add_child(add)
	var entry := _entry(_selected)
	_name_label.text = String(entry.get("name", ""))
	_preview.show_character(entry.get("look", {}))

func _entry(id: String) -> Dictionary:
	for entry: Dictionary in SaveManager.characters():
		if String(entry.id) == id:
			return entry
	return {}

func _on_pick(id: String) -> void:
	if id == _selected:
		return
	_selected = id
	_rebuild()
	_preview.play_character_anim("Yes")

func _on_play() -> void:
	SaveManager.select_character(_selected)
	SceneLoader.change_scene(HAVEN_SCENE, "Прихисток")

func _on_delete() -> void:
	var entry := _entry(_selected)
	var dialog := OrnateDialog.new("Видалити героя?", null, UiTheme.DANGER, 520.0)
	dialog.add_text("%s зникне назавжди разом з усім прогресом. Це не можна скасувати." % entry.get("name", "Герой"))
	dialog.add_button("Видалити", true, func() -> void:
		SaveManager.delete_character(_selected)
		dialog.close()
		if SaveManager.characters().is_empty():
			get_tree().change_scene_to_file(CREATE_SCENE)
			return
		_selected = SaveManager.active_id() if SaveManager.active_id() != "" else String(SaveManager.characters()[0].id)
		_rebuild())
	dialog.add_button("Ні", false)
	add_child(dialog)
