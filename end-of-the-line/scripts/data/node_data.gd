class_name NodeData
extends Resource

enum NodeType { MINE, FARM, FACTORY, TOWN, PORT }

@export var id: String = ""
@export var display_name: String = ""
@export var type: NodeType = NodeType.TOWN
@export var position: Vector3 = Vector3.ZERO
@export var gold_per_delivery: float = 10.0
@export var description: String = ""
