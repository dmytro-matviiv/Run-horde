extends HeroSkill3D

## ФОРМА ДРУЇДА — кнопка-перемикач: перетворитись на звіра або назад у
## людину. Ведмідь (bear_form) і Фенрір (fenrir_form) — наслідники, що
## лише задають, на кого перетворитись. Уся зміна (модель, числа, нові
## кнопки) — у Player3D.toggle_form.

var form := &""
## Мана не потрібна: перетворення й повернення — завжди доступні.
var free_cast := true

func _init() -> void:
	cooldown = 2.5

func _use(player: Node) -> bool:
	player.toggle_form(form)
	return true
