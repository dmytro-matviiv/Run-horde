extends Node

## Обгортка над рекламним SDK. Зараз — заглушка (mock): rewarded-відео
## "показується" миттєво й завжди успішне, щоб решту гри можна було
## розробляти й тестувати в редакторі без підключеного плагіна.
##
## У Фазі 6 сюди зайде реальний AdMob-плагін (poing-studios/godot-admob-plugin);
## решта коду завжди звертається лише до AdsManager.show_rewarded_ad(),
## тож заміна заглушки на реальний SDK не торкнеться викликів ззовні.

## Показує rewarded-відео. on_reward викликається, якщо гравець
## додивився ролик до кінця; on_skipped — якщо закрив достроково або
## реклама недоступна. Заглушка завжди викликає on_reward.
func show_rewarded_ad(on_reward: Callable, on_skipped: Callable = Callable()) -> void:
	on_reward.call()

## Показує interstitial. Заглушка нічого не робить (немає плагіна) —
## реальний показ з'явиться разом з AdMob у Фазі 6.
func show_interstitial() -> void:
	pass
