extends Camera3D
class_name GameCamera

@export var target: Vector3 = Vector3.ZERO
@export var distance: float = 15.0
@export var min_distance: float = 5.0
@export var max_distance: float = 40.0
@export var orbit_speed: float = 0.005
@export var zoom_speed: float = 1.0
@export var pitch: float = -55.0
@export var yaw: float = 45.0

var _dragging: bool = false

func _ready() -> void:
	_update_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mouse_event.pressed
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance - zoom_speed, min_distance)
			_update_transform()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(distance + zoom_speed, max_distance)
			_update_transform()

	if event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		yaw -= motion.relative.x * orbit_speed * 100.0
		pitch -= motion.relative.y * orbit_speed * 100.0
		pitch = clampf(pitch, -89.0, -10.0)
		_update_transform()

func _update_transform() -> void:
	var pitch_rad: float = deg_to_rad(pitch)
	var yaw_rad: float = deg_to_rad(yaw)

	var offset: Vector3 = Vector3.ZERO
	offset.x = distance * cos(pitch_rad) * sin(yaw_rad)
	offset.y = -distance * sin(pitch_rad)
	offset.z = distance * cos(pitch_rad) * cos(yaw_rad)

	global_position = target + offset
	look_at(target, Vector3.UP)
