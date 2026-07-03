class_name StanceManager
extends Node

signal stance_changed(new_direction: StanceDirection.Direction)

var current_stance: StanceDirection.Direction = StanceDirection.Direction.TOP


func set_stance(direction: StanceDirection.Direction) -> void:
	if direction != current_stance:
		current_stance = direction
		stance_changed.emit(direction)
		EventBus.stance_changed.emit(owner, direction)


func matches(attack_direction: StanceDirection.Direction) -> bool:
	return current_stance == attack_direction


func update_from_input(input: FighterInput) -> void:
	set_stance(input.get_stance_direction())
