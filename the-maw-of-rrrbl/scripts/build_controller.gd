extends Node3D
class_name BuildController

## Handles input for the track building mode.
## Raycasts from mouse to a build plane, feeds world position to TrackBuilder.

@export var track_builder: TrackBuilder
@export var camera: Camera3D
@export var build_plane_y: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if track_builder == null or camera == null:
		return

	if event is InputEventMouseMotion:
		var world_pos: Vector3 = _mouse_to_world(event.position)
		if world_pos != Vector3.INF:
			track_builder.update_cursor(world_pos)

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			match mouse_event.button_index:
				MOUSE_BUTTON_LEFT:
					track_builder.confirm_placement()
				MOUSE_BUTTON_RIGHT:
					track_builder.cancel_selection()

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed:
			match key_event.keycode:
				KEY_R:
					track_builder.rotate_ghost()
				KEY_TAB:
					track_builder.cycle_ghost_connection()
				KEY_ESCAPE:
					track_builder.cancel_selection()

func _mouse_to_world(screen_pos: Vector2) -> Vector3:
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)

	if absf(dir.y) < 0.001:
		return Vector3.INF

	var t: float = (build_plane_y - from.y) / dir.y
	if t < 0:
		return Vector3.INF

	return from + dir * t
