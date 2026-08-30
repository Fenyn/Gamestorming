## Timberline game state: money and (later) upgrades, unlocks, save/load.
## Autoload — no class_name; the autoload name "GameManager" is the global ID.

extends Node

var money: int = 0


func _ready() -> void:
	EventBus.item_sold.connect(_on_item_sold)


func add_money(amount: int) -> void:
	money += amount
	EventBus.money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	EventBus.money_changed.emit(money)
	return true


func _on_item_sold(_product_id: String, value: int) -> void:
	add_money(value)
