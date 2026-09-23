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
@onready var life_value: Label3D = $LifeValue
@onready var life_caption: Label3D = $LifeCaption
var life_transform: Transform3D = Transform3D.IDENTITY
var _anchor_inputs: Array = []
var _life_pulse: Tween = null


func _ready() -> void:
	surface.texture = viewport.get_texture()
	readout.redraw_requested.connect(_request_render)
	_request_render()


func _request_render() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func refresh(view: SeatView, player_index: int, viewer: int, live: Dictionary = {}) -> void:
	if not is_node_ready() or player_index >= view.players.size():
		return
	if duelist_uid != view.player(player_index).duelist and _hovering:
		_hovering = false
		hovered.emit(duelist_uid, false)
	duelist_uid = view.player(player_index).duelist
	readout.reduced_motion = reduced_motion
	readout.refresh(view, player_index, viewer, live)
	var counts: Array = live.get("zones", [])
	var player_counts: Array = counts[player_index] if player_index < counts.size() else []
	life_value.text = str(int(player_counts[0]) if not player_counts.is_empty() else view.player(player_index).life_deck.size())


## Preview only: outlined Energy segments distinguish projected spending from resolution.
func preview_energy(cost: int = 0) -> void:
	var next_cost: int = maxi(0, cost)
	if readout.preview_cost != next_cost:
		readout.preview_cost = next_cost
		readout.request_redraw()


## The count reacts at the pile the card just left, keeping the visual loss tied to its source.
func pulse_life_loss() -> void:
	if _life_pulse != null:
		_life_pulse.kill()
	life_value.scale = Vector3.ONE * (1.25 if not reduced_motion else 1.0)
	life_value.modulate = ZenithTheme.ATTACK
	_life_pulse = create_tween().set_parallel(true)
	_life_pulse.tween_property(life_value, "modulate", DuelistReadout.GOLD, 0.38)
	if not reduced_motion:
		_life_pulse.tween_property(life_value, "scale", Vector3.ONE, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func status_text() -> String:
	return readout.status_text() if is_node_ready() else ""


## Measure the animated face itself, including perspective, hover lift and camera zoom.
## The canvas stays legible while its components move outside these projected edges.
func anchor_to_card(card: Card3D, camera: Camera3D) -> void:
	# Static fixtures retain their texture and layout until the camera or card moves.
	var inputs: Array = [global_transform, card.front.global_transform, life_transform,
		camera.global_transform, camera.get_camera_projection(),
		camera.get_viewport().get_visible_rect().size, surface.pixel_size]
	if inputs == _anchor_inputs:
		return
	_anchor_inputs = inputs
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
	readout.duelist_bounds = bounds
	# Reserve the neighbouring Life Deck too; its single counter lives on the pile.
	for x: float in [-0.315, 0.315]:
		for z: float in [-0.44, 0.44]:
			var point: Vector2 = (camera.unproject_position(life_transform * Vector3(x, 0, z)) - center) / unit
			bounds = bounds.expand(point)
	life_value.global_position = life_transform.origin + camera.global_basis.y * (18.0 * pixel_scale)
	life_caption.global_position = life_transform.origin - camera.global_basis.y * (31.0 * pixel_scale)
	life_value.pixel_size = pixel_scale
	life_caption.pixel_size = pixel_scale
	readout.card_bounds = bounds
	# Expand the transparent canvas as the cluster grows; fixed textures clip wide zooms.
	for rect: Rect2 in readout.stat_hit_rects:
		bounds = bounds.merge(rect)
	var extent: Vector2 = Vector2(maxf(absf(bounds.position.x), absf(bounds.end.x)), maxf(absf(bounds.position.y), absf(bounds.end.y))) + Vector2(400, 400)
	var canvas_size: Vector2i = Vector2i(maxi(1600, ceili(extent.x * 2.0 / 128.0) * 128), maxi(1600, ceili(extent.y * 2.0 / 128.0) * 128))
	if viewport.size != canvas_size:
		viewport.size = canvas_size
		readout.size = Vector2(canvas_size)
		readout.request_redraw()


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


## Screen position of the back the rival is reading in the fan (`DuelistReadout.peek_point`), or
## null when this fixture draws no fan.
func peek_screen(slot: int, camera: Camera3D) -> Variant:
	var local: Variant = readout.peek_point(slot)
	if local == null or not visible or camera.is_position_behind(global_position):
		return null
	var pixel_scale: float = surface.pixel_size * global_basis.get_scale().x
	var center_screen: Vector2 = camera.unproject_position(global_position)
	var scale_pixels: float = center_screen.distance_to(camera.unproject_position(global_position + camera.global_basis.x * pixel_scale))
	return center_screen + (local as Vector2) * scale_pixels


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
