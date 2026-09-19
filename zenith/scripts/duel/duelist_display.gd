class_name DuelistDisplay
extends Node3D
## Persistent, camera-facing resource fixture anchored in the playspace.
## Accepts only the public seat view and the same event snapshots used by the table.

signal clicked(uid: int)
signal inspected(uid: int)
signal hovered(uid: int, on: bool)

@export var reduced_motion: bool = false
@export var interactive: bool = true
var duelist_uid: int = -1
var _hovering: bool = false
@onready var surface: Sprite3D = $Surface
@onready var viewport: SubViewport = $ReadoutViewport
@onready var readout: DuelistReadout = $ReadoutViewport/Readout


func _ready() -> void:
	surface.texture = viewport.get_texture()


func refresh(view: SeatView, player_index: int, viewer: int, live: Dictionary = {}) -> void:
	if not is_node_ready() or player_index >= view.players.size():
		return
	if duelist_uid != view.player(player_index).duelist and _hovering:
		_hovering = false
		hovered.emit(duelist_uid, false)
	duelist_uid = view.player(player_index).duelist
	readout.reduced_motion = reduced_motion
	readout.refresh(view, player_index, viewer, live)


## Preview only: outlined Energy segments distinguish projected spending from resolution.
func preview_energy(cost: int = 0) -> void:
	readout.preview_cost = maxi(0, cost)
	readout.queue_redraw()


func status_text() -> String:
	return readout.status_text() if is_node_ready() else ""


## Measure the animated face itself, including perspective, hover lift and camera zoom.
## The canvas stays legible while its components move outside these projected edges.
func anchor_to_card(card: Card3D, camera: Camera3D) -> void:
	var center: Vector2 = camera.unproject_position(global_position)
	var pixel_scale: float = surface.pixel_size * global_basis.get_scale().x
	var unit: float = center.distance_to(camera.unproject_position(global_position + camera.global_basis.x * pixel_scale))
	if unit <= 0.0:
		return
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for x: float in [-0.315, 0.315]:
		for z: float in [-0.44, 0.44]:
			var point: Vector2 = (camera.unproject_position(card.front.to_global(Vector3(x, 0, z))) - center) / unit
			if first:
				bounds = Rect2(point, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	if not readout.card_bounds.is_equal_approx(bounds):
		readout.card_bounds = bounds
		readout.update_layout()
		readout.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not interactive or not visible or duelist_uid < 0:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	if event is InputEventMouseMotion:
		var inside: bool = hit_test((event as InputEventMouseMotion).position, camera)
		if inside != _hovering:
			_hovering = inside
			hovered.emit(duelist_uid, inside)
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and hit_test(button.position, camera):
			if button.button_index == MOUSE_BUTTON_LEFT:
				clicked.emit(duelist_uid)
				get_viewport().set_input_as_handled()
			elif button.button_index == MOUSE_BUTTON_RIGHT:
				inspected.emit(duelist_uid)
				get_viewport().set_input_as_handled()


## Only the flanking stat crests are interactive. The center belongs to the actual card.
func hit_test(point: Vector2, camera: Camera3D) -> bool:
	if camera.is_position_behind(global_position):
		return false
	var pixel_scale: float = surface.pixel_size * global_basis.get_scale().x
	var center_screen: Vector2 = camera.unproject_position(global_position)
	var edge_screen: Vector2 = camera.unproject_position(global_position + camera.global_basis.x * pixel_scale)
	var scale_pixels: float = center_screen.distance_to(edge_screen)
	if scale_pixels <= 0.0:
		return false
	var local: Vector2 = (point - center_screen) / scale_pixels
	for rect: Rect2 in readout.stat_hit_rects:
		if rect.has_point(local):
			return true
	return false
