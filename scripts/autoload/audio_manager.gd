extends Node

## Звук гри в одному місці. Ефекти синтезовані (assets/audio), тому
## важать копійки й не тягнуть чужих ліцензій.
##
## Головна проблема звуку в такій грі — не "як він звучить", а "скільки
## його одночасно". За секунду в бою стається двадцять подій, і якщо
## озвучити кожну, виходить суцільний тріск. Тому тут три механізми:
##
## 1. РОЗРІДЖЕННЯ (min_interval): один і той самий звук не повторюється
##    частіше, ніж дозволено; зайві просто не грають.
## 2. ЛІМІТ ГОЛОСІВ (max_voices): скільки копій одного звуку можуть
##    звучати водночас — навіть у гущі бою удари не складаються в шум.
## 3. ПРИГЛУШЕННЯ (priority): коли лунає щось важливе — левел-ап,
##    смерть героя, покупка — бойові звуки на мить стають тихішими й
##    поступаються місцем, як у кіно.

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

## Налаштування кожного звуку: гучність (дБ, 0 = як записано),
## мінімальний проміжок між повторами (сек), скільки копій може
## звучати водночас і чи це "важливий" звук, який приглушує решту.
const CONFIG := {
	&"shoot": {"db": -20.0, "gap": 0.14, "voices": 2},
	&"hit": {"db": -24.0, "gap": 0.18, "voices": 2},
	&"explosion": {"db": -17.0, "gap": 0.35, "voices": 2},
	&"enemy_death": {"db": -22.0, "gap": 0.22, "voices": 2},
	&"hero_hurt": {"db": -10.0, "gap": 0.35, "voices": 1, "priority": true},
	&"hero_death": {"db": -6.0, "gap": 0.0, "voices": 1, "priority": true},
	&"pickup": {"db": -22.0, "gap": 0.12, "voices": 2},
	&"gold": {"db": -16.0, "gap": 0.12, "voices": 2},
	&"level_up": {"db": -8.0, "gap": 0.0, "voices": 1, "priority": true},
	&"click": {"db": -18.0, "gap": 0.05, "voices": 2},
	&"purchase": {"db": -10.0, "gap": 0.0, "voices": 1, "priority": true},
}

const VOICE_COUNT := 12
const MUSIC_DB := -26.0

## Наскільки й надовго стишуються звичайні звуки під важливий.
const DUCK_DB := -12.0
const DUCK_TIME := 0.7

var _voices: Array[AudioStreamPlayer] = []
var _voice_sound: Array[StringName] = []   # що саме грає кожен голос
var _next_voice := 0
var _last_played: Dictionary = {}          # StringName -> час останнього запуску
var _duck_until := 0.0
var _music_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # звук грає й на паузі (вибір апгрейду)
	for i in VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_voices.append(player)
		_voice_sound.append(&"")

	_music_player = AudioStreamPlayer.new()
	# Петля задається на самому потоці: WAV без неї грав би один раз.
	# Працюємо з копією, а не з константою — міняти спільний ресурс не можна.
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
	var config: Dictionary = CONFIG.get(id, {})
	var now := Time.get_ticks_msec() / 1000.0

	if now - float(_last_played.get(id, -999.0)) < float(config.get("gap", 0.0)):
		return
	if _count_playing(id) >= int(config.get("voices", 2)):
		return

	var is_priority: bool = config.get("priority", false)
	if is_priority:
		_duck_until = now + DUCK_TIME
		_duck_active_voices()

	var player := _take_voice(id)
	player.stream = SOUNDS[id]
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.volume_db = float(config.get("db", -18.0)) + (0.0 if is_priority else _current_duck())
	player.play()
	_last_played[id] = now

func set_music_enabled(enabled: bool) -> void:
	if enabled and not _music_player.playing:
		_music_player.play()
	elif not enabled:
		_music_player.stop()

func _current_duck() -> float:
	return DUCK_DB if Time.get_ticks_msec() / 1000.0 < _duck_until else 0.0

## Стишує те, що вже звучить, а не лише наступні звуки — інакше
## левел-ап потонув би в уже запущеній черзі ударів.
func _duck_active_voices() -> void:
	for i in VOICE_COUNT:
		if _voices[i].playing and not CONFIG.get(_voice_sound[i], {}).get("priority", false):
			_voices[i].volume_db += DUCK_DB

func _count_playing(id: StringName) -> int:
	var count := 0
	for i in VOICE_COUNT:
		if _voice_sound[i] == id and _voices[i].playing:
			count += 1
	return count

## Вільний голос, а якщо всі зайняті — найдавніший по колу.
func _take_voice(id: StringName) -> AudioStreamPlayer:
	for i in VOICE_COUNT:
		if not _voices[i].playing:
			_voice_sound[i] = id
			return _voices[i]
	var index := _next_voice
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	_voice_sound[index] = id
	return _voices[index]

func _on_node_added(node: Node) -> void:
	if node is Button and not (node as Button).pressed.is_connected(_on_any_button_pressed):
		(node as Button).pressed.connect(_on_any_button_pressed)

func _on_any_button_pressed() -> void:
	play(&"click", 0.05)
