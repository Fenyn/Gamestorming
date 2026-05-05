extends Node
class_name SparkManager

signal sparks_changed(total: float)

var total_sparks: float = 0.0

func earn(amount: float) -> void:
	total_sparks += amount
	sparks_changed.emit(total_sparks)

func spend(amount: float) -> bool:
	if total_sparks < amount:
		return false
	total_sparks -= amount
	sparks_changed.emit(total_sparks)
	return true

func can_afford(amount: float) -> bool:
	return total_sparks >= amount

func reset() -> void:
	total_sparks = 0.0
	sparks_changed.emit(total_sparks)
