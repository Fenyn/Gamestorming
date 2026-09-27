class_name DuelistDisplay
extends Node3D
## A duelist's resources as objects on the table. The stat tracker is a plate standing on a
## stone slab in front of the duelist card, leaning back toward the viewer; the rest (status
## lines, Seals, the rival's hand) is printed flat on the felt around the card. The Life count
## lies on top of the Life Deck. Accepts only the public seat view and the same event snapshots
## used by the table.

signal clicked(uid: int)
signal inspected(uid: int)
signal hovered(uid: int, on: bool)

## World units per canvas pixel, for the printed canvas and the plate alike.
## Sized so the near plate fills the gap between Out and the Relic without covering either.
const PIXEL: float = 0.0041
## The Life count's own scale; it lies on the pile and keeps one size for both seats.
const LIFE_PIXEL: float = 0.0044
## The printed canvas lies just over the felt and under the cards.
const PRINT_Y: float = 0.006
## How far each plate leans back from flat. The far one leans further, since it is further off.
const NEAR_TILT: float = deg_to_rad(12.0)
const FAR_TILT: float = deg_to_rad(30.0)
## The far seat's fixture is made this much larger, so across the table it reads about as well
## as the near one. Perspective hides the difference.
const FAR_SCALE: float = 1.25
## The slab's thickness under the plate's face.
const PLATE_DEPTH: float = 0.045
## The Life count on the pile: the number just past its centre, the caption toward the viewer.
const LIFE_NUMBER_BACK: float = 0.07
const LIFE_CAPTION_FORWARD: float = 0.22

@export var reduced_motion: bool = false
@export var interactive: bool = true
var duelist_uid: int = -1
var _hovering: bool = false
@onready var surface: Sprite3D = $Surface
@onready var viewport: SubViewport = $ReadoutViewport
@onready var readout: DuelistReadout = $ReadoutViewport/Readout
@onready var plate_viewport: SubViewport = $PlateViewport
@onready var plate_readout: DuelistReadout = $PlateViewport/Plate
@onready var plate: Node3D = $Plate
@onready var plate_body: MeshInstance3D = $Plate/Body
@onready var plate_face: Sprite3D = $Plate/Face
@onready var life_value: Label3D = $LifeValue
@onready var life_caption: Label3D = $LifeCaption
var life_transform: Transform3D = Transform3D.IDENTITY
var flag_row: PackedVector3Array = PackedVector3Array()   # where the status chips print, inner end first
var _anchor_inputs: Array = []
var _life_pulse: Tween = null
var _pixel: float = PIXEL   # world units per canvas pixel for this seat


func _ready() -> void:
	surface.texture = viewport.get_texture()
	plate_face.texture = plate_viewport.get_texture()
	plate_viewport.size = DuelistReadout.PLATE_CANVAS
	plate_readout.size = Vector2(DuelistReadout.PLATE_CANVAS)
	var extent: Vector2 = Vector2(DuelistReadout.PLATE_CANVAS) * PIXEL
	plate_face.pixel_size = PIXEL
	plate_face.position = Vector3(0, PLATE_DEPTH + 0.002, -extent.y * 0.5)
	(plate_body.mesh as BoxMesh).size = Vector3(extent.x, PLATE_DEPTH, extent.y)
	plate_body.position = Vector3(0, PLATE_DEPTH * 0.5, -extent.y * 0.5)
	surface.pixel_size = PIXEL
	readout.redraw_requested.connect(_request_render)
	plate_readout.redraw_requested.connect(_request_plate_render)
	_request_render()
	_request_plate_render()


## The printed canvas on the felt, the large one, renders only when its own readout changed.
func _request_render() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## The standing plate renders on its own, so its tab counting down re-renders nothing else.
func _request_plate_render() -> void:
	plate_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func refresh(view: SeatView, player_index: int, viewer: int, live: Dictionary = {}) -> void:
	if not is_node_ready() or player_index >= view.players.size():
		return
	if duelist_uid != view.player(player_index).duelist and _hovering:
		_hovering = false
		hovered.emit(duelist_uid, false)
	duelist_uid = view.player(player_index).duelist
	readout.reduced_motion = reduced_motion
	readout.refresh(view, player_index, viewer, live)
	plate_readout.reduced_motion = reduced_motion
	plate_readout.refresh(view, player_index, viewer, live)
	var counts: Array = live.get("zones", [])
	var player_counts: Array = counts[player_index] if player_index < counts.size() else []
	life_value.text = str(int(player_counts[0]) if not player_counts.is_empty() else view.player(player_index).life_deck.size())


## Online: the tab on this seat's plate (`DuelistReadout.set_tab`), PlateTab.NONE to clear it.
func set_tab(kind: DuelistReadout.PlateTab, text: String, warn: bool) -> void:
	if is_node_ready():
		plate_readout.set_tab(kind, text, warn)


## Preview only: outlined Energy segments distinguish projected spending from resolution.
func preview_energy(cost: int = 0) -> void:
	var next_cost: int = maxi(0, cost)
	if plate_readout.preview_cost != next_cost:
		readout.preview_cost = next_cost
		plate_readout.preview_cost = next_cost
		plate_readout.request_redraw()


## The count reacts at the pile the card just left, keeping the visual loss tied to its source.
func pulse_life_loss() -> void:
	if _life_pulse != null:
		_life_pulse.kill()
	life_value.scale = Vector3.ONE * (1.25 if not reduced_motion else 1.0)
	life_value.modulate = ZenithTheme.ATTACK
	_life_pulse = create_tween().set_parallel(true)
	_life_pulse.tween_property(life_value, "modulate", DuelistReadout.TEXT, 0.38)
	if not reduced_motion:
		_life_pulse.tween_property(life_value, "scale", Vector3.ONE, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func status_text() -> String:
	return readout.status_text() if is_node_ready() else ""


## Lay the fixture out around the card where it rests on the table (its hover lift is ignored, so
## the plate never slides). Only which end of the table the camera sits at matters: everything
## reads the right way up for that side.
func anchor_to_card(card: Card3D, camera: Camera3D) -> void:
	# Static fixtures retain their texture and layout until the card, the pile or the side moves.
	var toward: float = 1.0 if camera.global_position.z >= 0.0 else -1.0
	var far: bool = readout._player_index != readout._viewer
	var inputs: Array = [global_transform, card.global_transform, life_transform, flag_row, toward, far, camera.global_position]
	if inputs == _anchor_inputs:
		return
	_anchor_inputs = inputs
	_pixel = PIXEL * (FAR_SCALE if far else 1.0)
	surface.pixel_size = _pixel
	life_value.pixel_size = LIFE_PIXEL
	life_caption.pixel_size = LIFE_PIXEL
	var yaw: Basis = Basis(Vector3.UP, 0.0 if toward > 0.0 else PI)
	var rest: Vector3 = card.global_position
	surface.global_transform = Transform3D(yaw * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(rest.x, PRINT_Y, rest.z))
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for x: float in [-0.315, 0.315]:
		for z: float in [-0.44, 0.44]:
			var point: Vector2 = _canvas_point(card.global_transform * Vector3(x, 0, z))
			if first:
				bounds = Rect2(point, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	readout.duelist_bounds = bounds
	# Reserve the neighbouring Life Deck too; its single counter lives on the pile.
	for x: float in [-0.315, 0.315]:
		for z: float in [-0.44, 0.44]:
			bounds = bounds.expand(_canvas_point(life_transform * Vector3(x, 0, z)))
	var flat: Basis = yaw * Basis(Vector3.RIGHT, -PI * 0.5)
	var forward: Vector3 = Vector3(0, 0, toward)
	life_value.global_transform = Transform3D(flat, life_transform.origin + Vector3.UP * 0.004 - forward * LIFE_NUMBER_BACK)
	life_caption.global_transform = Transform3D(flat, life_transform.origin + Vector3.UP * 0.004 + forward * LIFE_CAPTION_FORWARD)
	readout.card_bounds = bounds
	if flag_row.size() == 2:
		var inner: Vector2 = _canvas_point(flag_row[0])
		var outer: Vector2 = _canvas_point(flag_row[1])
		readout.flag_home = Rect2(Vector2(minf(inner.x, outer.x), inner.y), Vector2(absf(outer.x - inner.x), 0.0))
	_place_plate(yaw, far, camera)
	# Expand the transparent canvas as the cluster grows; fixed textures clip wide zooms.
	for rect: Rect2 in readout.stat_hit_rects:
		bounds = bounds.merge(rect)
	# The status chips' home is covered whether or not anything is printed there yet: the canvas
	# only regrows when the card moves, and a first chip or Seal arrives without that.
	if readout.flag_home.size.x > 0.0:
		bounds = bounds.merge(readout.flag_home_area())
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
	return camera.unproject_position(_world_point(local as Vector2))


## Only the plate and the printed status are interactive. The center belongs to the actual card.
func hit_test(point: Vector2, camera: Camera3D) -> bool:
	if camera.is_position_behind(global_position):
		return false
	var from: Vector3 = camera.project_ray_origin(point)
	var direction: Vector3 = camera.project_ray_normal(point)
	var on_plate: Variant = _ray_on(plate_face, from, direction)
	if on_plate != null and Rect2(-Vector2(DuelistReadout.PLATE_CANVAS) * 0.5, Vector2(DuelistReadout.PLATE_CANVAS)).has_point(on_plate):
		return true
	var on_felt: Variant = _ray_on(surface, from, direction)
	if on_felt == null:
		return false
	for rect: Rect2 in readout.stat_hit_rects:
		if rect.has_point(on_felt):
			return true
	return false


## The screen rectangle the fixture covers: every printed stat region and the standing plate.
## The hand keeps below it.
func screen_rect(camera: Camera3D) -> Rect2:
	var bounds: Rect2 = Rect2(camera.unproject_position(plate_face.global_position), Vector2.ZERO)
	var half: Vector2 = Vector2(DuelistReadout.PLATE_CANVAS) * 0.5 * PIXEL
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		bounds = bounds.expand(camera.unproject_position(plate_face.to_global(Vector3(corner.x * half.x, corner.y * half.y, 0))))
	for rect: Rect2 in readout.stat_hit_rects:
		for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			bounds = bounds.expand(camera.unproject_position(_world_point(corner)))
	return bounds


## Stands the plate on the table at the tracker's place in the printed layout: its edge nearest the
## viewer on the felt, leaning back. The far seat's status lines move past the table it hides.
func _place_plate(yaw: Basis, far: bool, camera: Camera3D) -> void:
	var tracker: Rect2 = readout.update_layout()["tracker"]
	var canvas: Rect2 = Rect2(tracker.position - DuelistReadout.PLATE_PAD, Vector2(DuelistReadout.PLATE_CANVAS))
	var pivot: Vector3 = _world_point(Vector2(canvas.get_center().x, canvas.end.y))
	var tilt: float = FAR_TILT if far else NEAR_TILT
	var grow: float = _pixel / PIXEL
	plate.global_transform = Transform3D((yaw * Basis(Vector3.RIGHT, tilt)).scaled_local(Vector3.ONE * grow), Vector3(pivot.x, 0.003, pivot.z))
	var clearance: float = 0.0
	if far:
		# The plate's top edge, and where the camera's line over it meets the felt beyond.
		var top: Vector3 = plate.global_transform * Vector3(0, PLATE_DEPTH, -canvas.size.y * PIXEL)
		var sight: Vector3 = top - camera.global_position
		if sight.y < -0.001:
			var beyond: Vector3 = top - sight * (top.y / sight.y)
			clearance = maxf(0.0, beyond.distance_to(Vector3(pivot.x, beyond.y, pivot.z)) - canvas.size.y * _pixel) / _pixel
	readout.flag_clearance = roundf(clearance / 8.0) * 8.0


## A point on the printed canvas (pixels from its centre) in the world, and back.
func _world_point(canvas_point: Vector2) -> Vector3:
	return surface.global_transform * Vector3(canvas_point.x * _pixel, -canvas_point.y * _pixel, 0)


func _canvas_point(world: Vector3) -> Vector2:
	var local: Vector3 = surface.global_transform.affine_inverse() * world
	return Vector2(local.x, -local.y) / _pixel


## Where a screen ray meets a flat sprite, in that sprite's canvas pixels from its centre.
func _ray_on(sprite: Sprite3D, from: Vector3, direction: Vector3) -> Variant:
	var plane: Plane = Plane(sprite.global_basis.z.normalized(), sprite.global_position)
	var hit: Variant = plane.intersects_ray(from, direction)
	if hit == null:
		return null
	# In the sprite's own units: its node scale is undone by the inverse, only pixel_size is left.
	var local: Vector3 = sprite.global_transform.affine_inverse() * (hit as Vector3)
	return Vector2(local.x, -local.y) / sprite.pixel_size
