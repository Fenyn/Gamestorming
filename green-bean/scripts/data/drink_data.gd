class_name DrinkData
extends Resource

enum DrinkType { POUR_OVER, AMERICANO, LATTE, CAPPUCCINO, RED_EYE, MACCHIATO, MOCHA }
enum CupSize { SMALL, MEDIUM, LARGE, EXTRA_LARGE }
enum GrindLevel { COARSE, FINE }
enum Step { GRIND_COARSE, GRIND_FINE, POUR_OVER_BREW, SHOT_PRESS_BREW, HOT_WATER, STEAM_MILK, ADD_SYRUP, ADD_SAUCE, LID }
enum SyrupType { VANILLA, CARAMEL, HAZELNUT, TOFFEE_NUT }
enum SauceType { MOCHA, CARAMEL_SAUCE, WHITE_MOCHA }

const SIZE_CODES := { CupSize.SMALL: "S", CupSize.MEDIUM: "M", CupSize.LARGE: "L", CupSize.EXTRA_LARGE: "XL" }

const SIZE_MULTIPLIERS := {
	CupSize.SMALL: 1.0,
	CupSize.MEDIUM: 1.2,
	CupSize.LARGE: 1.5,
	CupSize.EXTRA_LARGE: 1.8,
}

const PRICE_MULTIPLIERS := {
	CupSize.SMALL: 1.0,
	CupSize.MEDIUM: 1.15,
	CupSize.LARGE: 1.3,
	CupSize.EXTRA_LARGE: 1.5,
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
		"steps": [Step.GRIND_FINE, Step.SHOT_PRESS_BREW, Step.HOT_WATER],
	},
	DrinkType.LATTE: {
		"name": "Latte",
		"code": "L",
		"base_price": 5.50,
		"steps": [Step.GRIND_FINE, Step.SHOT_PRESS_BREW, Step.STEAM_MILK],
	},
	DrinkType.CAPPUCCINO: {
		"name": "Cappuccino",
		"code": "CAP",
		"base_price": 5.00,
		"steps": [Step.GRIND_FINE, Step.SHOT_PRESS_BREW, Step.STEAM_MILK],
	},
	DrinkType.RED_EYE: {
		"name": "Red Eye",
		"code": "RE",
		"base_price": 6.50,
		"steps": [Step.GRIND_COARSE, Step.POUR_OVER_BREW, Step.GRIND_FINE, Step.SHOT_PRESS_BREW],
	},
	DrinkType.MACCHIATO: {
		"name": "Macchiato",
		"code": "EM",
		"base_price": 3.00,
		"steps": [Step.GRIND_FINE, Step.SHOT_PRESS_BREW],
	},
	DrinkType.MOCHA: {
		"name": "Mocha",
		"code": "MO",
		"base_price": 6.00,
		"steps": [Step.ADD_SAUCE, Step.GRIND_FINE, Step.SHOT_PRESS_BREW, Step.STEAM_MILK],
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
	# Whole cents, so the register total and the change owed always agree.
	return roundi(RECIPES[drink_type]["base_price"] * PRICE_MULTIPLIERS[cup_size] * 100.0) / 100.0

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
		CupSize.SMALL: return "Small"
		CupSize.MEDIUM: return "Medium"
		CupSize.LARGE: return "Large"
		CupSize.EXTRA_LARGE: return "Extra Large"
	return ""

static func get_all_drink_types() -> Array:
	return RECIPES.keys()

static func get_all_drink_names() -> Array[String]:
	var names: Array[String] = []
	for dt in RECIPES:
		names.append(RECIPES[dt]["name"])
	return names

const DEFAULT_FOAM_TARGET := 0.5

const FOAM_TARGETS := {
	DrinkType.LATTE: 0.35,
	DrinkType.CAPPUCCINO: 0.75,
}

static func get_foam_target(drink_type: DrinkType) -> float:
	if drink_type in FOAM_TARGETS:
		return FOAM_TARGETS[drink_type]
	return DEFAULT_FOAM_TARGET

const SYRUP_UPCHARGE := 0.60

const SYRUP_PUMPS_BY_SIZE := {
	CupSize.SMALL: 2,
	CupSize.MEDIUM: 3,
	CupSize.LARGE: 4,
	CupSize.EXTRA_LARGE: 5,
}

const SYRUP_NAMES := {
	SyrupType.VANILLA: "Vanilla",
	SyrupType.CARAMEL: "Caramel",
	SyrupType.HAZELNUT: "Hazelnut",
	SyrupType.TOFFEE_NUT: "Toffee Nut",
}

const SYRUP_CODES := {
	SyrupType.VANILLA: "V",
	SyrupType.CARAMEL: "C",
	SyrupType.HAZELNUT: "H",
	SyrupType.TOFFEE_NUT: "TN",
}

const SYRUP_COLORS := {
	SyrupType.VANILLA: Color(0.85, 0.75, 0.4),
	SyrupType.CARAMEL: Color(0.6, 0.4, 0.15),
	SyrupType.HAZELNUT: Color(0.5, 0.35, 0.2),
	SyrupType.TOFFEE_NUT: Color(0.65, 0.5, 0.25),
}

static func get_syrup_name(syrup: SyrupType) -> String:
	return SYRUP_NAMES[syrup]

static func get_syrup_code(syrup: SyrupType) -> String:
	return SYRUP_CODES[syrup]

static func get_target_pumps(cup_size: CupSize) -> int:
	return SYRUP_PUMPS_BY_SIZE[cup_size]

static func get_syrup_color(syrup: SyrupType) -> Color:
	return SYRUP_COLORS[syrup]

const SAUCE_UPCHARGE := 0.80

const SAUCE_NAMES := {
	SauceType.MOCHA: "Mocha",
	SauceType.CARAMEL_SAUCE: "Caramel",
	SauceType.WHITE_MOCHA: "White Mocha",
}

const SAUCE_CODES := {
	SauceType.MOCHA: "MO",
	SauceType.CARAMEL_SAUCE: "CR",
	SauceType.WHITE_MOCHA: "WM",
}

const SAUCE_COLORS := {
	SauceType.MOCHA: Color(0.25, 0.15, 0.08),
	SauceType.CARAMEL_SAUCE: Color(0.65, 0.4, 0.1),
	SauceType.WHITE_MOCHA: Color(0.9, 0.85, 0.75),
}

static func get_sauce_name(sauce: SauceType) -> String:
	return SAUCE_NAMES[sauce]

static func get_sauce_code(sauce: SauceType) -> String:
	return SAUCE_CODES[sauce]

static func get_sauce_color(sauce: SauceType) -> Color:
	return SAUCE_COLORS[sauce]

const STEP_DISPLAY := {
	Step.POUR_OVER_BREW: "Pour over, coarse grind",
	Step.SHOT_PRESS_BREW: "Shot, fine grind",
	Step.HOT_WATER: "Hot water",
	Step.STEAM_MILK: "Steam milk",
	Step.ADD_SAUCE: "Sauce",
}

## Names of the etched lines inside the pitcher, for drinks that have one.
const FOAM_LINE_NAMES := {
	DrinkType.LATTE: "latte",
	DrinkType.CAPPUCCINO: "cap",
}

const STEP_TOOLTIPS := {
	Step.POUR_OVER_BREW:
		"Grind coarse into the dripper, set it on the stand over the cup, then bloom pour with a full kettle. Come back for the main pour once the bloom settles.",
	Step.SHOT_PRESS_BREW:
		"Grind fine into the shot press, set it on the cup, pour to the FILL line and stir. Press when the timer flashes, keeping the bubble in the ring.",
	Step.HOT_WATER:
		"Hold the cup with its shot at the hot water tower and pour to the ring inside the cup.",
	Step.STEAM_MILK:
		"Milk from the fridge into the pitcher, pitcher on the steamer. Keep the wand tip just under the surface until it stops stretching, then come back before the dial goes red.",
	Step.ADD_SAUCE:
		"Cup and bottle at the drizzle station, then squeeze and draw across the whole cup.",
}

static func get_step_name(step: Step, drink: DrinkType = DrinkType.POUR_OVER) -> String:
	if step not in STEP_DISPLAY:
		return ""
	var base: String = STEP_DISPLAY[step]
	if step == Step.STEAM_MILK and drink in FOAM_LINE_NAMES:
		base += " to the %s line" % FOAM_LINE_NAMES[drink]
	return base

static func get_step_tooltip(step: Step) -> String:
	if step in STEP_TOOLTIPS:
		return STEP_TOOLTIPS[step]
	return ""
