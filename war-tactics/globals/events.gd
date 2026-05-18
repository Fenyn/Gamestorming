extends Node

# Screen flow
signal screen_transition_requested(target: String)

# Battle
signal battle_won
signal battle_lost
signal unit_died(unit: Node)
