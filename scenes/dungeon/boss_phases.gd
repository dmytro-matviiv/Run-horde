extends Node3D
class_name BossPhases

## ФАЗИ БОСА. На половині здоров'я бос лютує, на чверті — у нестямі.
## З кожною фазою він швидший і б'є частіше, а ще починає "дощ
## небезпек": довкола героя (і просто під ним) спалахують кола, які за
## мить вибухають — вогнем у Демона, отрутою в Грибного Короля, кригою в
## Дракона. Стоїш — отримаєш; перекотився вчасно — ідеальний перекат.
##
## Вузол висить на самому босі; зміну фази повідомляє сигналом —
## данж показує напис.

signal phase_changed(phase: int, title: String)

## Пороги здоров'я фаз (частка від найбільшого).
const THRESHOLDS := [0.5, 0.25]
## У кожній фазі: у скільки разів швидший бос і його замахи.
const SPEED_UP := 1.2
const COOLDOWN_DOWN := 0.8
## Дощ небезпек у фазах 1, 2, 3: як часто, скільки кіл; далі — радіус і
## за скільки коло вибухає.
const HAZARD_INTERVAL := [0.0, 6.5, 4.5]
const HAZARD_COUNT := [0, 3, 5]
const HAZARD_RADIUS := 1.6
const HAZARD_DELAY := 1.1
const HAZARD_SPREAD := 5.0
const HAZARD_DAMAGE_SHARE := 0.8

const STYLES := {
	"demon": {"color": Color(1.0, 0.45, 0.12), "rage": "лютує", "frenzy": "у нестямі"},
	"summoner": {"color": Color(0.55, 1.0, 0.3), "rage": "лютує", "frenzy": "у нестямі"},
	"dragon": {"color": Color(0.55, 0.85, 1.0), "rage": "лютує", "frenzy": "у нестямі"},
	# Мега-боси (лише вони мають "boss_gate" на рівні):
	"doom": {"color": Color(1.0, 0.4, 0.1), "rage": "кличе метеори", "frenzy": "рве небо навпіл"},
	"abyssal": {"color": Color(0.55, 0.2, 0.85), "rage": "розкриває Безодню", "frenzy": "тоне в Безодні"},
	"shadow": {"color": Color(0.35, 0.1, 0.5), "rage": "розколюється", "frenzy": "губиться у тінях"},
}

var phase := 1

var _boss: Enemy3D
var _player: Node3D
var _hazard_left := 0.0
var _rng := RandomNumberGenerator.new()

func attach(boss: Enemy3D, player: Node3D) -> void:
	_boss = boss
	_player = player
	_rng.randomize()

func _style() -> Dictionary:
	return STYLES.get(_boss.boss_style, STYLES.demon)

func _physics_process(delta: float) -> void:
	if _boss == null or not _boss.is_alive():
		return
	var ratio := _boss.current_hp / maxf(_boss.max_hp, 1.0)
	while phase - 1 < THRESHOLDS.size() and ratio <= THRESHOLDS[phase - 1]:
		_enter_phase(phase + 1)
	if phase >= 2 and _boss.is_aggro():
		_hazard_left -= delta
		if _hazard_left <= 0.0:
			_hazard_left = HAZARD_INTERVAL[phase - 1]
			_rain_hazards()

func _enter_phase(next: int) -> void:
	phase = next
	_boss.move_speed *= SPEED_UP
	_boss.attack_cooldown *= COOLDOWN_DOWN
	_hazard_left = 1.5
	var style := _style()
	var parent := _boss.get_parent()
	# Рев: велика хвиля, спалах і трус — видно, що бій змінився.
	CombatVfx.shockwave(parent, _boss.global_position, 6.5, style.color, 0.6)
	CombatVfx.impact(parent, _boss.global_position + Vector3.UP * _boss.target_height * 0.6, style.color, true)
	CombatVfx.flash_model(_boss.get("_model"), style.color, 0.3)
	# Мега-боси (лише вони мають "transform_tints" в описі): фарба лишається
	# назавжди, а не згасає, як звичайний спалах, — бос і справді змінився,
	# а не просто блимнув. Своя анімація нам не по кишені — переродження
	# продає колір і світіння.
	var transform_tints: Array = _boss.definition.get("transform_tints", [])
	var idx := phase - 2
	if idx >= 0 and idx < transform_tints.size():
		var transform_glows: Array = _boss.definition.get("transform_glows", [])
		var tint: Color = transform_tints[idx]
		var glow: Color = transform_glows[idx] if idx < transform_glows.size() else style.color
		Enemy3D.paint_model(_boss.get("_model"), tint, glow)
	# Свій рев переходу фази (модель має "Roar"): бос завмирає й реве, аура
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
	AudioManager.play(&"explosion")
	var mood: String = style.rage if phase == 2 else style.frenzy
	phase_changed.emit(phase, "%s %s!" % [_boss.display_name, mood])

## Кола небезпеки: одне просто під героєм (не стій!), решта довкола.
func _rain_hazards() -> void:
	var style := _style()
	var parent := _boss.get_parent()
	var damage := _boss.damage * HAZARD_DAMAGE_SHARE
	for i in HAZARD_COUNT[phase - 1]:
		var spot := _player.global_position
		if i > 0:
			var angle := _rng.randf() * TAU
			spot += Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(2.0, HAZARD_SPREAD)
		_hazard(parent, spot, style.color, damage, HAZARD_DELAY + 0.12 * i)

func _hazard(parent: Node, spot: Vector3, color: Color, damage: float, delay: float) -> void:
	var marker := CombatVfx.make_telegraph(Color(color, 0.9), HAZARD_RADIUS, PI, true)
	parent.add_child(marker)
	marker.global_position = Vector3(spot.x, DungeonBuilder.FLOOR_TOP + 0.05, spot.z)
	var player := _player
	var boss := _boss
	var tween := marker.create_tween()
	tween.tween_method(func(value: float) -> void:
		marker.set_instance_shader_parameter(&"progress", value), 0.0, 1.0, delay)
	tween.tween_callback(func() -> void:
		var center := marker.global_position
		marker.queue_free()
		CombatVfx.shockwave(parent, center, HAZARD_RADIUS, color, 0.3)
		CombatVfx.impact_decal(parent, center, HAZARD_RADIUS * 0.8, color, 0.3)
		CombatVfx.impact(parent, center + Vector3.UP * 0.5, color, false)
		# Бос уже впав — кола догорають, але не ранять: перемога є перемога.
		if is_instance_valid(player) and is_instance_valid(boss) and boss.is_alive():
			var offset := player.global_position - center
			offset.y = 0.0
			if offset.length() <= HAZARD_RADIUS:
				player.take_damage(damage))
