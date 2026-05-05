extends Node3D
class_name Maw

signal orb_consumed(sparks: float)
signal implosion_started()
signal implosion_finished()

@export var consumption_threshold: float = 100.0

var consumed_sparks: float = 0.0

@onready var _consume_area: Area3D = $ConsumeArea

func _ready() -> void:
	_consume_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Orb:
		_consume_orb(body as Orb)

func _consume_orb(orb: Orb) -> void:
	var sparks: float = orb.get_sparks()
	consumed_sparks += sparks
	orb_consumed.emit(sparks)
	orb.consume()

	if consumed_sparks >= consumption_threshold:
		_trigger_implosion()

func _trigger_implosion() -> void:
	implosion_started.emit()
	await get_tree().create_timer(2.0).timeout
	implosion_finished.emit()

func get_fill_percentage() -> float:
	return clampf(consumed_sparks / consumption_threshold, 0.0, 1.0)

func reset() -> void:
	consumed_sparks = 0.0
