extends RefCounted
class_name HeroPool

## Реєстр усіх героїв гри. Як і UpgradePool — новий герой додається
## тут явно (а не скануванням папки), щоб список завжди було видно
## одним поглядом в одному місці.

const ALL_HEROES: Array[HeroDef] = [
	preload("res://data/heroes/runewielder.tres"),
	preload("res://data/heroes/blade_warden.tres"),
	preload("res://data/heroes/ember_priestess.tres"),
]

static func get_def(id: StringName) -> HeroDef:
	for def in ALL_HEROES:
		if def.id == id:
			return def
	return ALL_HEROES[0]
