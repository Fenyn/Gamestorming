class_name OrderData
extends RefCounted

var drink_type: DrinkData.DrinkType
var cup_size: DrinkData.CupSize
var ticket_code: String

var grind_quality := -1.0
var brew_quality := -1.0
var steam_quality := -1.0
var pour_quality := -1.0
var correct_grind_level := true

var base_price := 0.0
var completed := false
var handed_off := false

func _init(type: DrinkData.DrinkType = DrinkData.DrinkType.POUR_OVER, size: DrinkData.CupSize = DrinkData.CupSize.TALL) -> void:
	drink_type = type
	cup_size = size
	ticket_code = DrinkData.get_ticket_code(type, size)
	base_price = DrinkData.get_base_price(type, size)

func get_final_quality() -> float:
	var qualities: Array[float] = []

	if grind_quality >= 0.0:
		qualities.append(grind_quality)
	if DrinkData.USES_AEROPRESS[drink_type] and brew_quality >= 0.0:
		qualities.append(brew_quality)
	if DrinkData.USES_POUR_OVER[drink_type] and pour_quality >= 0.0:
		qualities.append(pour_quality)
	if DrinkData.REQUIRES_STEAM[drink_type] and steam_quality >= 0.0:
		qualities.append(steam_quality)
	if DrinkData.REQUIRES_HOT_WATER[drink_type] and pour_quality >= 0.0:
		qualities.append(pour_quality)

	if qualities.is_empty():
		return 0.0

	var total := 0.0
	for q in qualities:
		total += q
	var avg := total / qualities.size()

	if not correct_grind_level:
		avg *= 0.5

	return clampf(avg, 0.0, 1.0)

func get_earned_amount() -> float:
	return base_price * get_final_quality()
