extends Camera3D

@export var target: Vector3 = Vector3(3, 0, 1)
@export var distance: float = 20.0
@export var min_distance: float = 8.0
@export var max_distance: float = 40.0
@export var pitch: float = -60.0
@export var yaw: float = 45.0
@export var orbit_speed: float = 0.005
@export var zoom_speed: float = 2.0
@export var pan_speed: float = 0.05

var _dragging_orbit: bool = false
var _dragging_pan: bool = false


func _ready() -> void:
	_update_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_dragging_orbit = mouse_event.pressed
			MOUSE_BUTTON_RIGHT:
				_dragging_pan = mouse_event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mouse_event.pressed:
					distance = maxf(min_distance, distance - zoom_speed)
					_update_transform()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mouse_event.pressed:
					distance = minf(max_distance, distance + zoom_speed)
					_update_transform()

	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _dragging_orbit:
			yaw -= motion.relative.x * orbit_speed * 100.0
			pitch -= motion.relative.y * orbit_speed * 100.0
			pitch = clampf(pitch, -89.0, -10.0)
			_update_transform()
		elif _dragging_pan:
			var right: Vector3 = global_transform.basis.x
			var forward: Vector3 = Vector3(right.z, 0, -right.x).normalized()
			target += right * (-motion.relative.x * pan_speed)
			target += forward * (motion.relative.y * pan_speed)
			_update_transform()


func _update_transform() -> void:
	var pitch_rad: float = deg_to_rad(pitch)
	var yaw_rad: float = deg_to_rad(yaw)

	var offset: Vector3 = Vector3(
		cos(pitch_rad) * sin(yaw_rad),
		-sin(pitch_rad),
		cos(pitch_rad) * cos(yaw_rad)
	) * distance

	position = target + offset
	look_at(target, Vector3.UP)
