class_name ImplantData
extends Resource

enum Trigger { ON_MODULE_FIRE, ON_TURN_START, ON_REROLL, PASSIVE, ON_KILL }
enum Effect { BONUS_DAMAGE, FREE_REROLL, HEAL_ON_FIRE, WILD_FIRST_TURN, SHIELD_ON_FIRE }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

@export_group("Mechanics")
@export var trigger: Trigger = Trigger.PASSIVE
@export var effect: Effect = Effect.BONUS_DAMAGE
@export var value: int = 0
