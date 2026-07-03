class_name HeartEventData
extends Resource

@export_group("Trigger")
@export var event_id: String = ""
@export var crew_id: String = ""
@export var required_hearts: int = 2
@export var required_room: String = ""
@export var required_hour_min: int = 6
@export var required_hour_max: int = 22
@export var required_day_of_week: String = ""

@export_group("Content")
## Each entry: { "speaker": "crew_id or maia", "text": "...", "choices": [{"label": "...", "points": 0}] }
@export var dialogue_sequence: Array[Dictionary] = []
