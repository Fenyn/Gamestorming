class_name DrinkData
extends Resource

enum DrinkType { POUR_OVER, AMERICANO, LATTE }
enum CupSize { SHORT, TALL, GRANDE, VENTI }
enum GrindLevel { COARSE, FINE }
enum Step { GRIND_COARSE, GRIND_FINE, POUR_OVER_BREW, AEROPRESS_BREW, HOT_WATER, STEAM_MILK }

const SIZE_CODES := { CupSize.SHORT: "S", CupSize.TALL: "T", CupSize.GRANDE: "G", CupSize.VENTI: "V" }

const SIZE_MULTIPLIERS := {
	CupSize.SHORT: 1.0,
	CupSize.TALL: 1.2,
	CupSize.GRANDE: 1.5,
	CupSize.VENTI: 1.8,
}

const PRICE_MULTIPLIERS := {
	CupSize.SHORT: 1.0,
	CupSize.TALL: 1.15,
	CupSize.GRANDE: 1.3,
	CupSize.VENTI: 1.5,
}

const RECIPES := {
	DrinkType.POUR_OVER: {
		"name": "Pour Over",
		"code": "PO",
		"base_price": 3.50,
		"steps": [Step.GRIND_COARSE, Step.POUR_OVER_BREW],
	},
	DrinkType.AMERICANO: {
		"name": "Americano",
		"code": "A",
		"base_price": 4.00,
		"steps": [Step.GRIND_FINE, Step.AEROPRESS_BREW, Step.HOT_WATER],
	},
	DrinkType.LATTE: {
		"name": "Latte",
		"code": "L",
		"base_price": 5.50,
		"steps": [Step.GRIND_FINE, Step.AEROPRESS_BREW, Step.STEAM_MILK],
	},
}

static func get_recipe(drink_type: DrinkType) -> Dictionary:
	return RECIPES[drink_type]

static func get_drink_name(drink_type: DrinkType) -> String:
	return RECIPES[drink_type]["name"]

static func get_drink_code(drink_type: DrinkType) -> String:
	return RECIPES[drink_type]["code"]

static func get_ticket_code(drink_type: DrinkType, cup_size: CupSize) -> String:
	return SIZE_CODES[cup_size] + " " + get_drink_code(drink_type)

static func get_base_price(drink_type: DrinkType, cup_size: CupSize) -> float:
	return RECIPES[drink_type]["base_price"] * PRICE_MULTIPLIERS[cup_size]

static func get_size_multiplier(cup_size: CupSize) -> float:
	return SIZE_MULTIPLIERS[cup_size]

static func get_grind_level(drink_type: DrinkType) -> GrindLevel:
	var steps: Array = RECIPES[drink_type]["steps"]
	if steps.has(Step.GRIND_FINE):
		return GrindLevel.FINE
	return GrindLevel.COARSE

static func has_step(drink_type: DrinkType, step: Step) -> bool:
	var steps: Array = RECIPES[drink_type]["steps"]
	return steps.has(step)

static func get_size_name(cup_size: CupSize) -> String:
	match cup_size:
		CupSize.SHORT: return "Short"
		CupSize.TALL: return "Tall"
		CupSize.GRANDE: return "Grande"
		CupSize.VENTI: return "Venti"
	return ""

static func get_all_drink_types() -> Array:
	return RECIPES.keys()

static func get_all_drink_names() -> Array[String]:
	var names: Array[String] = []
	for dt in RECIPES:
		names.append(RECIPES[dt]["name"])
	return names
