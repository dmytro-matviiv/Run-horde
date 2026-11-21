extends EnemyAbility

## ВІДКРИТЕ ГОРНО (Володар Горна, з фази 2). Ґрати на грудях розжарюються
## й розходяться — ядро горна відкрите: бос лютіший (фаза сама пришвидшує),
## але кожен удар по ньому проходить сильніше (factor).

const COLOR := Color(1.0, 0.6, 0.15)

var _opened := false
var _glow: OmniLight3D

func _init() -> void:
	id = "forge_core"
	cooldown = 0.0

func tick(delta: float) -> void:
	super.tick(delta)
	if _opened or enemy.phases == null or enemy.phases.phase < 2:
		return
	_opened = true
	_glow = OmniLight3D.new()
	_glow.light_color = COLOR
	_glow.light_energy = 2.5
	_glow.omni_range = 4.0
	_glow.shadow_enabled = false
	enemy.add_child(_glow)
	_glow.position = Vector3(0.0, enemy.target_height * 0.5, 0.0) + enemy.model_forward() * 0.5
	var flicker := _glow.create_tween().set_loops()
	flicker.tween_property(_glow, "light_energy", 1.8, 0.2)
	flicker.tween_property(_glow, "light_energy", 2.8, 0.25)
	CombatVfx.shockwave(world(), enemy.global_position, 3.0, COLOR, 0.5)

func filter_damage(amount: float, _heavy: bool) -> float:
	return amount * (float(config.get("factor", 1.5)) if _opened else 1.0)
