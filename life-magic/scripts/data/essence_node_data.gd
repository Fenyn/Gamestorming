class_name EssenceNodeData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var branch: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var max_level: int = 1
@export var base_cost: int = 5
@export var cost_scaling: int = 0
@export var effect_type: String = ""
@export var effect_value: float = 0.0
@export var prerequisite_ids: Array[String] = []
@export var tier_gate: int = -1
