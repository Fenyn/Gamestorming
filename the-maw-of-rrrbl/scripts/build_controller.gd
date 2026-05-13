extends Node3D
class_name BuildController

signal portal_clicked(portal: DreamerPortal)

@export var track_builder: TrackBuilder
@export var camera: Camera3D
@export var build_plane_y: float = 0.0

var portal_manager: PortalManager

var _last_ray_origin: Vector3 = Vector3.ZERO
var _last_ray_dir: Vector3 = Vector3.DOWN

func _unhandled_input(event: InputEvent) -> void:
	if track_builder == null or camera == null:
		return

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			return
		_last_ray_origin = camera.project_ray_origin(event.position)
		_last_ray_dir = camera.project_ray_normal(event.position)
		var plane_pos: Vector3 = _ray_to_plane(_last_ray_origin, _last_ray_dir)
		track_builder.update_cursor(plane_pos, _last_ray_origin, _last_ray_dir)

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _try_click_portal():
				return
			track_builder.confirm_placement()

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed:
			if key_event.keycode == KEY_Z and key_event.ctrl_pressed:
				track_builder.undo_last()
				return
			match key_event.keycode:
				KEY_R:
					track_builder.rotate_ghost()
				KEY_TAB:
					track_builder.cycle_ghost_connection()
				KEY_ESCAPE:
					track_builder.cancel_selection()

func _try_click_portal() -> bool:
	if portal_manager == null:
		return false
	if track_builder != null and track_builder._ghost != null:
		return false
	var portal: DreamerPortal = portal_manager.find_portal_near_ray(
		_last_ray_origin, _last_ray_dir, 1.5
	)
	if portal == null:
		return false
	portal_clicked.emit(portal)
	return true

func _ray_to_plane(origin: Vector3, dir: Vector3) -> Vector3:
	if absf(dir.y) < 0.001:
		return Vector3.INF
	var t: float = (build_plane_y - origin.y) / dir.y
	if t < 0:
		return Vector3.INF
	return origin + dir * t
