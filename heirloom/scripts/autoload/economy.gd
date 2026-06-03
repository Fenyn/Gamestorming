extends Node

const MONTHLY_BILL := 200.0
const FORECLOSURE_THRESHOLD := 2

var sell_prices: Dictionary = {
	"firewood": 5.0,
	"fish_common": 8.0,
	"fish_uncommon": 15.0,
	"fish_rare": 25.0,
	"egg": 0.33,
	"vegetable": 5.0,
	"smoked_fish": 16.0,
	"refurbished_part": 20.0,
}

var buy_prices: Dictionary = {
	"food_cold": 5.0,
	"food_ingredients": 2.0,
	"water_bottle": 2.0,
	"drink": 2.0,
	"seed_packet": 3.0,
	"wood_plank": 5.0,
	"salvage_part": 8.0,
	"wire_pipe": 10.0,
}


func _ready() -> void:
	EventBus.month_ended.connect(_on_month_ended)


func sell_item(item_id: String, quantity: int = 1) -> float:
	var price_per: float = sell_prices.get(item_id, 0.0) as float
	var total: float = price_per * float(quantity)
	if total <= 0.0:
		return 0.0
	GameState.add_money(total)
	EventBus.item_sold.emit(item_id, total)
	return total


func buy_item(item_id: String, quantity: int = 1) -> bool:
	var price_per: float = buy_prices.get(item_id, 0.0) as float
	var total: float = price_per * float(quantity)
	if not GameState.spend_money(total):
		return false
	EventBus.item_purchased.emit(item_id, total)
	return true


func get_sell_price(item_id: String) -> float:
	return sell_prices.get(item_id, 0.0) as float


func get_buy_price(item_id: String) -> float:
	return buy_prices.get(item_id, 0.0) as float


func get_friendship_discount(npc_id: String) -> float:
	var level: int = GameState.get_friendship(npc_id)
	return float(level) * 0.05


func _on_month_ended(_month: int) -> void:
	EventBus.bill_due.emit(MONTHLY_BILL)
	if GameState.money >= MONTHLY_BILL:
		GameState.spend_money(MONTHLY_BILL)
		GameState.bills_missed = 0
		EventBus.bill_paid.emit(MONTHLY_BILL)
	else:
		GameState.bills_missed += 1
		EventBus.bill_missed.emit(GameState.bills_missed)
		if GameState.bills_missed >= FORECLOSURE_THRESHOLD:
			GameState.game_over = true
