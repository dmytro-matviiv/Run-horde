extends Node
## Витягує потрібні кліпи UAL1/UAL2 в assets/animations/character/<назва>.res
## (щоб гра не вантажила весь пак). Запуск у test_env.
const SOURCES := ["res://incoming/anims/UAL1_Standard.glb", "res://incoming/anims/UAL2_Standard.glb"]
const CLIPS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Roll", "Sword_Idle", "Sword_Attack", "Spell_Simple_Shoot",
	"Spell_Simple_Idle", "Hit_Chest", "Death01", "Interact", "PickUp_Table", "Dance", "Idle_Talking", "Jump",
	"Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C", "Sword_Dash", "Idle_Shield", "Shield_Dash", "Yes", "Idle_FoldArms"]
const OUT := "res://assets/animations/character/"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var done := {}
	for src in SOURCES:
		var scene: Node = load(src).instantiate()
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		for clip: String in CLIPS:
			if done.has(clip) or not ap.has_animation(clip):
				continue
			var anim: Animation = ap.get_animation(clip).duplicate(true)
			ResourceSaver.save(anim, OUT + clip + ".res")
			done[clip] = true
		scene.free()
	print("ANIM extracted ", done.size(), " missing ", CLIPS.filter(func(c: String) -> bool: return not done.has(c)))
	get_tree().quit(0)
