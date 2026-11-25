extends EnemyAbility

## ЗАТЕМНЕННЯ (Тіньовий Володар, фаза 3). Володар здіймає руки — темрява
## густішає (warn): екран темніє, над героєм напис «У СВІТЛО!», кола
## запалених жаровень спалахують. Тоді на time секунд гасне все: хто не в
## колі світла запаленої жаровні — отримує сильний удар і сліпне. Тримай
## жаровні запаленими — інакше сховатись ніде.
## Налаштування: warn, time, damage.

const SHADOW := Color(0.3, 0.1, 0.55)

var _warn_left := 0.0
var _dark_left := 0.0
var _layer: CanvasLayer
var _rect: ColorRect
var _label: Label3D
var _struck := false

func _init() -> void:
	id = "eclipse"
	cooldown = 16.0

func try_use(_distance: float) -> bool:
	if _warn_left > 0.0 or _dark_left > 0.0:
		return false
	start_cooldown()
	enemy.begin_special(id, float(config.get("windup", 0.5)), Color(SHADOW, 0.0), 0.1)
	return true

func resolve() -> void:
	_warn_left = float(config.get("warn", 1.6))
	_struck = false
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 4
		world().add_child(_layer)
		_rect = ColorRect.new()
		_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(_rect)
	_rect.color = Color(0.02, 0.0, 0.05, 0.0)
	_layer.visible = true
	_label = Label3D.new()
	_label.font_size = 80
	_label.pixel_size = 0.005
	_label.outline_size = 18
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = Color(1.0, 0.7, 0.3)
	world().add_child(_label)

func _braziers() -> EnemyAbility:
	for ability in enemy.abilities:
		if ability.id == "braziers":
			return ability
	return null

func tick(delta: float) -> void:
	super.tick(delta)
	var hero := player()
	if _warn_left > 0.0:
		_warn_left -= delta
		var t := clampf(1.0 - _warn_left / float(config.get("warn", 1.6)), 0.0, 1.0)
		_rect.color.a = 0.55 * t
		if _label != null and hero != null and is_instance_valid(hero):
			_label.global_position = hero.global_position + Vector3.UP * 3.0
			var safe := _lit(hero)
			_label.text = "У світлі — тримайся!" if safe else "У СВІТЛО ЖАРОВНІ!"
			_label.modulate = Color(1.0, 0.85, 0.4) if safe else Color(1.0, 0.35, 0.3)
		if _warn_left <= 0.0:
			_dark_left = float(config.get("time", 2.2))
		return
	if _dark_left <= 0.0:
		return
	_dark_left -= delta
	_rect.color.a = 0.8
	if not _struck and hero != null and is_instance_valid(hero):
		_struck = true
		if not _lit(hero):
			CombatVfx.impact(world(), hero.global_position + Vector3.UP, SHADOW, true)
			hero.take_damage(damage())
			if hero.has_method("blind"):
				hero.blind(0.6, 2.0)
	if _dark_left <= 0.0:
		_finish()

func _lit(hero: Node3D) -> bool:
	var b := _braziers()
	return b != null and bool(b.call("lit_at", hero.global_position))

func _finish() -> void:
	_warn_left = 0.0
	_dark_left = 0.0
	if _rect != null:
		var tween := _rect.create_tween()
		tween.tween_property(_rect, "color:a", 0.0, 0.6)
	if _label != null and is_instance_valid(_label):
		_label.queue_free()
	_label = null

func on_death() -> void:
	_finish()
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
