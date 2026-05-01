class_name OrderData
extends RefCounted

var drink_type: DrinkData.DrinkType
var cup_size: DrinkData.CupSize
var ticket_code: String
var requested_syrup: int = -1
var requested_sauce: int = -1

var grind_quality := -1.0
var brew_quality := -1.0
var steam_quality := -1.0
var pour_quality := -1.0
var syrup_quality := -1.0
var sauce_quality := -1.0
var correct_grind_level := true

var base_price := 0.0
var completed := false
var handed_off := false

func _init(type: DrinkData.DrinkType = DrinkData.DrinkType.POUR_OVER, size: DrinkData.CupSize = DrinkData.CupSize.MEDIUM) -> void:
	drink_type = type
	cup_size = size
	ticket_code = _build_ticket_code()
	base_price = _calc_base_price()

func set_syrup(syrup: DrinkData.SyrupType) -> void:
	requested_syrup = syrup
	ticket_code = _build_ticket_code()
	base_price = _calc_base_price()

func clear_syrup() -> void:
	requested_syrup = -1
	ticket_code = _build_ticket_code()
	base_price = _calc_base_price()

func has_syrup() -> bool:
	return requested_syrup >= 0

func set_sauce(sauce: DrinkData.SauceType) -> void:
	requested_sauce = sauce
	ticket_code = _build_ticket_code()
	base_price = _calc_base_price()

func clear_sauce() -> void:
	requested_sauce = -1
	ticket_code = _build_ticket_code()
	base_price = _calc_base_price()

func has_sauce() -> bool:
	return requested_sauce >= 0 or DrinkData.has_step(drink_type, DrinkData.Step.ADD_SAUCE)

func _build_ticket_code() -> String:
	var code := DrinkData.get_ticket_code(drink_type, cup_size)
	if requested_syrup >= 0:
		code += " " + DrinkData.get_syrup_code(requested_syrup as DrinkData.SyrupType)
	if requested_sauce >= 0:
		code += " " + DrinkData.get_sauce_code(requested_sauce as DrinkData.SauceType)
	return code

func _calc_base_price() -> float:
	var price := DrinkData.get_base_price(drink_type, cup_size)
	if requested_syrup >= 0:
		price += DrinkData.SYRUP_UPCHARGE
	if requested_sauce >= 0 and not DrinkData.has_step(drink_type, DrinkData.Step.ADD_SAUCE):
		price += DrinkData.SAUCE_UPCHARGE
	return price

func get_final_quality() -> float:
	var qualities: Array[float] = []

	if grind_quality >= 0.0:
		qualities.append(grind_quality)
	if DrinkData.has_step(drink_type, DrinkData.Step.AEROPRESS_BREW) and brew_quality >= 0.0:
		qualities.append(brew_quality)
	if DrinkData.has_step(drink_type, DrinkData.Step.POUR_OVER_BREW) and pour_quality >= 0.0:
		qualities.append(pour_quality)
	if DrinkData.has_step(drink_type, DrinkData.Step.STEAM_MILK) and steam_quality >= 0.0:
		qualities.append(steam_quality)
	if DrinkData.has_step(drink_type, DrinkData.Step.HOT_WATER) and pour_quality >= 0.0:
		qualities.append(pour_quality)
	if requested_syrup >= 0 and syrup_quality >= 0.0:
		qualities.append(syrup_quality)
	if has_sauce() and sauce_quality >= 0.0:
		qualities.append(sauce_quality)

	if qualities.is_empty():
		return 0.0

	var total := 0.0
	for q in qualities:
		total += q
	var avg := total / qualities.size()

	if not correct_grind_level:
		avg *= 0.5

	return clampf(avg, 0.0, 1.0)

func get_star_rating() -> float:
	return snapped(get_final_quality() * 5.0, 0.5)

func get_earned_amount() -> float:
	return base_price * get_final_quality()
