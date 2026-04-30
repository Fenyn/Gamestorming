class_name DrinkData
extends Resource

enum DrinkType { POUR_OVER, AMERICANO, LATTE }
enum CupSize { SHORT, TALL, GRANDE, VENTI }
enum GrindLevel { COARSE, FINE }

const SIZE_CODES := { CupSize.SHORT: "S", CupSize.TALL: "T", CupSize.GRANDE: "G", CupSize.VENTI: "V" }
const DRINK_CODES := { DrinkType.POUR_OVER: "PO", DrinkType.AMERICANO: "A", DrinkType.LATTE: "L" }

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

const BASE_PRICES := {
	DrinkType.POUR_OVER: 3.50,
	DrinkType.AMERICANO: 4.00,
	DrinkType.LATTE: 5.50,
}

const GRIND_LEVELS := {
	DrinkType.POUR_OVER: GrindLevel.COARSE,
	DrinkType.AMERICANO: GrindLevel.FINE,
	DrinkType.LATTE: GrindLevel.FINE,
}

const REQUIRES_STEAM := {
	DrinkType.POUR_OVER: false,
	DrinkType.AMERICANO: false,
	DrinkType.LATTE: true,
}

const REQUIRES_HOT_WATER := {
	DrinkType.POUR_OVER: false,
	DrinkType.AMERICANO: true,
	DrinkType.LATTE: false,
}

const USES_AEROPRESS := {
	DrinkType.POUR_OVER: false,
	DrinkType.AMERICANO: true,
	DrinkType.LATTE: true,
}

const USES_POUR_OVER := {
	DrinkType.POUR_OVER: true,
	DrinkType.AMERICANO: false,
	DrinkType.LATTE: false,
}

static func get_ticket_code(drink_type: DrinkType, cup_size: CupSize) -> String:
	return SIZE_CODES[cup_size] + " " + DRINK_CODES[drink_type]

static func get_base_price(drink_type: DrinkType, cup_size: CupSize) -> float:
	return BASE_PRICES[drink_type] * PRICE_MULTIPLIERS[cup_size]

static func get_size_multiplier(cup_size: CupSize) -> float:
	return SIZE_MULTIPLIERS[cup_size]

static func get_grind_level(drink_type: DrinkType) -> GrindLevel:
	return GRIND_LEVELS[drink_type]
