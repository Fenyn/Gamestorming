class_name TrackDefinition
extends Resource

@export var track_name: String = ""
@export var checkpoints: Array[Vector3] = []
@export var par_time: float = 60.0
@export var start_transform: Transform3D = Transform3D.IDENTITY

@export_group("Racing Line")
@export var racing_line_points: Array[Vector3] = []
@export var racing_line_speeds: Array[float] = []
