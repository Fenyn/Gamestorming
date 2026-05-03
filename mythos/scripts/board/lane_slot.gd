class_name LaneSlot
extends Area3D

@export var lane_index: int = 0
@export var owner_player: int = 0

var highlighted: bool = false
var _highlight_color: Color = Color(0.3, 0.85, 0.3, 1.0)
var _default_color: Color = Color.WHITE
var _mesh: MeshInstance3D

func _ready() -> void:
	_mesh = $MeshInstance3D
	if owner_player == 0:
		_default_color = Color(0.3, 0.45, 0.6, 1.0)
	else:
		_default_color = Color(0.6, 0.4, 0.35, 1.0)
	input_event.connect(_on_input_event)
	_set_color(_default_color)

func set_highlighted(value: bool) -> void:
	highlighted = value
	_set_color(_highlight_color if value else _default_color)

func _set_color(color: Color) -> void:
	if _mesh == null:
		return
	var mat: StandardMaterial3D = _mesh.get_surface_override_material(0)
	if mat == null:
		mat = StandardMaterial3D.new()
		_mesh.set_surface_override_material(0, mat)
	mat.albedo_color = color

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not event.is_action_pressed("click"):
		return
	if highlighted:
		EventBus.slot_clicked.emit("lane", lane_index)
	elif owner_player == GameState.current_turn_player and TurnManager.is_interactive_phase():
		var player: PlayerState = GameState.get_player(owner_player)
		var unit: UnitInstance = player.get_lane_unit(lane_index)
		if unit != null and unit.has_keyword(KeywordData.Keyword.MOBILITY):
			EventBus.unit_selected_for_move.emit(owner_player, lane_index)
