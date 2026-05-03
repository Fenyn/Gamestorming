class_name GridSlot
extends Area3D

@export var grid_pos: Vector2i = Vector2i.ZERO
@export var owner_player: int = 0

var highlighted: bool = false
var _highlight_color: Color = Color(0.3, 0.85, 0.3, 1.0)
var _default_color: Color = Color.WHITE
var _mesh: MeshInstance3D

func _ready() -> void:
	_mesh = $MeshInstance3D
	if owner_player == 0:
		_default_color = Color(0.35, 0.4, 0.5, 1.0)
	else:
		_default_color = Color(0.5, 0.38, 0.35, 1.0)
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
	if event.is_action_pressed("click") and highlighted:
		EventBus.slot_clicked.emit("grid", grid_pos)
