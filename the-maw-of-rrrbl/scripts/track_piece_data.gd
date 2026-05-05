extends Resource
class_name TrackPieceData

enum PieceCategory {
	STRAIGHT,
	CURVE,
	BEND,
	S_CURVE,
	WAVE,
	SPLIT,
	RAMP,
	HELIX,
	BUMP,
	TUNNEL,
	FUNNEL,
	END_CAP,
	CORNER,
	CROSS,
	DECORATIVE,
}

@export var piece_id: String
@export var display_name: String
@export var category: PieceCategory
@export var model_path: String
@export var spark_cost: float = 0.0
@export var connections: Array[ConnectionPoint]
