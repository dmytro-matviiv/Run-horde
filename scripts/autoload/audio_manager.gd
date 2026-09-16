extends Node

## Звук гри в одному місці. Ефекти синтезовані (assets/audio), тому
## важать копійки й не тягнуть ліцензій.
##
## Три речі, заради яких це окремий автозавантажувач:
## 1. Пул програвачів — у бою десятки звуків за секунду, створювати
##    вузол на кожен постріл марно.
## 2. Обмеження частоти: удар по ворогу лунає щокадру, тож однаковий
##    звук не грає частіше, ніж раз на MIN_INTERVAL — інакше виходить
##    суцільний тріск замість пострілів.
## 3. Клацання кнопок: ловимо появу будь-якої кнопки в дереві сцени,
##    а не чіпляємо звук у кожному екрані окремо.

const SOUNDS := {
	&"shoot": preload("res://assets/audio/sfx_shoot.wav"),
	&"hit": preload("res://assets/audio/sfx_hit.wav"),
	&"explosion": preload("res://assets/audio/sfx_explosion.wav"),
	&"enemy_death": preload("res://assets/audio/sfx_enemy_death.wav"),
	&"hero_hurt": preload("res://assets/audio/sfx_hero_hurt.wav"),
	&"hero_death": preload("res://assets/audio/sfx_hero_death.wav"),
	&"pickup": preload("res://assets/audio/sfx_pickup.wav"),
	&"gold": preload("res://assets/audio/sfx_gold.wav"),
	&"level_up": preload("res://assets/audio/sfx_level_up.wav"),
	&"click": preload("res://assets/audio/sfx_click.wav"),
	&"purchase": preload("res://assets/audio/sfx_purchase.wav"),
}

const MUSIC := preload("res://assets/audio/music_dungeon.wav")

## Мінімальний проміжок між повторами одного звуку, сек.
const MIN_INTERVAL := {
	&"shoot": 0.07,
	&"hit": 0.06,
	&"explosion": 0.08,
	&"enemy_death": 0.05,
	&"pickup": 0.04,
	&"gold": 0.05,
}

const VOICE_COUNT := 14
const SFX_DB := -6.0
const MUSIC_DB := -16.0

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played: Dictionary = {}   # StringName -> час останнього запуску, сек
var _music_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # звук грає й на паузі (вибір апгрейду)
	for i in VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		player.volume_db = SFX_DB
		add_child(player)
		_voices.append(player)

	_music_player = AudioStreamPlayer.new()
	# Петля задається на самому потоці: WAV без неї грав би один раз.
	# Працюємо з копією, а не з константою: міняти сам ресурс не можна
	# (він спільний для всієї гри й лежить у пам'яті лише в одному
	# екземплярі).
	var music: AudioStreamWAV = MUSIC.duplicate()
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music_player.stream = music
	_music_player.volume_db = MUSIC_DB
	add_child(_music_player)
	_music_player.play()

	# Будь-яка кнопка, що з'явиться в грі, сама почне клацати.
	get_tree().node_added.connect(_on_node_added)

## pitch_jitter — випадковий розкид висоти; для частих звуків (постріли,
## удари) саме він рятує від відчуття "заїждженої платівки".
func play(id: StringName, pitch_jitter: float = 0.12) -> void:
	if not SOUNDS.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var min_gap: float = MIN_INTERVAL.get(id, 0.0)
	if now - float(_last_played.get(id, -999.0)) < min_gap:
		return
	_last_played[id] = now

	var player := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	player.stream = SOUNDS[id]
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()

func set_music_enabled(enabled: bool) -> void:
	if enabled and not _music_player.playing:
		_music_player.play()
	elif not enabled:
		_music_player.stop()

func _on_node_added(node: Node) -> void:
	if node is Button and not (node as Button).pressed.is_connected(_on_any_button_pressed):
		(node as Button).pressed.connect(_on_any_button_pressed)

func _on_any_button_pressed() -> void:
	play(&"click", 0.05)
