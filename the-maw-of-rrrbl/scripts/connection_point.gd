extends Resource
class_name ConnectionPoint

enum TrackWidth { STANDARD, WIDE }

@export var local_position: Vector3
@export var local_direction: Vector3
@export var height_offset: float = 0.0
@export var width: TrackWidth = TrackWidth.STANDARD
