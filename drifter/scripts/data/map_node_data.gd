class_name MapNodeData
extends Resource

enum NodeType { ENCOUNTER, ELITE, TRADER, SHELTER, ANOMALY, APEX }

@export var type: NodeType = NodeType.ENCOUNTER
@export var row: int = 0
@export var column: int = 0
@export var connections: Array[Vector2i] = []
@export var visited: bool = false


func get_display_name() -> String:
	match type:
		NodeType.ENCOUNTER:
			return "Encounter"
		NodeType.ELITE:
			return "Elite"
		NodeType.TRADER:
			return "Trader"
		NodeType.SHELTER:
			return "Shelter"
		NodeType.ANOMALY:
			return "Anomaly"
		NodeType.APEX:
			return "Apex"
	return "Unknown"


func get_icon_text() -> String:
	match type:
		NodeType.ENCOUNTER:
			return "E"
		NodeType.ELITE:
			return "!"
		NodeType.TRADER:
			return "$"
		NodeType.SHELTER:
			return "+"
		NodeType.ANOMALY:
			return "?"
		NodeType.APEX:
			return "X"
	return "."


func get_color() -> Color:
	match type:
		NodeType.ENCOUNTER:
			return Color(0.70, 0.70, 0.70)
		NodeType.ELITE:
			return Color(0.90, 0.70, 0.20)
		NodeType.TRADER:
			return Color(0.85, 0.75, 0.30)
		NodeType.SHELTER:
			return Color(0.30, 0.80, 0.40)
		NodeType.ANOMALY:
			return Color(0.70, 0.40, 0.90)
		NodeType.APEX:
			return Color(0.90, 0.20, 0.20)
	return Color.WHITE
