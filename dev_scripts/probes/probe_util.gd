extends RefCounted

## Спільне для перевірок.

## Обирає першу картку у вікні вибору здібності — так, як це зробив би
## гравець. Які саме здібності випадуть, залежить від героя та його
## зброї, тож id наперед не відомий.
static func press_first_card(choice: Node) -> bool:
	var cards: Node = choice.get("cards_container")
	if cards == null or cards.get_child_count() == 0:
		return false
	(cards.get_child(0) as Button).pressed.emit()
	return true
