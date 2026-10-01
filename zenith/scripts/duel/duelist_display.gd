class_name DuelistDisplay
extends Node3D
## What a duelist's seat prints on the table around its card (`DuelistReadout`: the Aspect, status
## lines, Seals, the rival's hand and online tab), and the Life count lying on top of the Life
## Deck. Energy, Might and Fervor are on the card (`StatusMarkers`). Accepts only the public seat
## view and the same event snapshots used by the table.

signal clicked(uid: int)
signal inspected(uid: int)
signal hovered(uid: int, on: bool)
## The pointer entered a Resonance sigil (its id and screen rect) or left it (""). `far` is true for
## the rival's seat, and `screen` is then `far_tip_anchor`, which its tip opens over.
signal resonance_hovered(id: String, screen: Rect2, far: bool)

## World units per canvas pixel.
const PIXEL: float = 0.0029
## The Life count's own scale; it lies on the pile and keeps one size for both seats.
const LIFE_PIXEL: float = 0.0044
## The printed canvas lies just over the board and under the cards.
const PRINT_Y: float = 0.006
## The Life count on the pile: the number just past its centre, the caption toward the viewer.
const LIFE_NUMBER_BACK: float = 0.07
const LIFE_CAPTION_FORWARD: float = 0.22

@export var reduced_motion: bool = false
@export var interactive: bool = true
var duelist_uid: int = -1
var _hovering: bool = false
var _hovered_sigil: int = -1
@onready var surface: Sprite3D = $Surface
@onready var viewport: SubViewport = $ReadoutViewport
@onready var readout: DuelistReadout = $ReadoutViewport/Readout
@onready var life_value: Label3D = $LifeValue
@onready var life_caption: Label3D = $LifeCaption
var life_transform: Transform3D = Transform3D.IDENTITY
var flag_row: PackedVector3Array = PackedVector3Array()   # where the status chips print, inner end first
var status_home: Vector3 = Vector3.ZERO   # the seat's status spot on the table, world space
var _anchor_inputs: Array = []
var _life_pulse: Tween = null


func _ready() -> void:
	surface.texture = viewport.get_texture()
	readout.redraw_requested.connect(_request_render)
	_request_render()


## The printed canvas renders only when its readout changed.
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


## Online: the rival's tab (`DuelistReadout.set_tab`), Tab.NONE to clear it.
func set_tab(kind: DuelistReadout.Tab, text: String, warn: bool) -> void:
	if is_node_ready():
		readout.set_tab(kind, text, warn)


## Flashes and pops the Life count for a card lost from the pile.
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


## Lays the fixture out around the card at rest (hover lift ignored), upright for whichever end of
## the table the camera sits at. A no-op until an input changes.
func anchor_to_card(card: Card3D, camera: Camera3D) -> void:
	var toward: float = 1.0 if camera.global_position.z >= 0.0 else -1.0
	var inputs: Array = [global_transform, card.global_transform, life_transform, flag_row, status_home, toward]
	if inputs == _anchor_inputs:
		return
	_anchor_inputs = inputs
	surface.pixel_size = PIXEL
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
	var flat: Basis = yaw * Basis(Vector3.RIGHT, -PI * 0.5)
	var forward: Vector3 = Vector3(0, 0, toward)
	life_value.global_transform = Transform3D(flat, life_transform.origin + Vector3.UP * 0.004 - forward * LIFE_NUMBER_BACK)
	life_caption.global_transform = Transform3D(flat, life_transform.origin + Vector3.UP * 0.004 + forward * LIFE_CAPTION_FORWARD)
	readout.card_bounds = bounds
	readout.status_home = _canvas_point(status_home)
	if flag_row.size() == 2:
		var inner: Vector2 = _canvas_point(flag_row[0])
		var outer: Vector2 = _canvas_point(flag_row[1])
		readout.flag_home = Rect2(Vector2(minf(inner.x, outer.x), inner.y), Vector2(absf(outer.x - inner.x), 0.0))
	for rect: Rect2 in readout.stat_hit_rects + readout.sigil_rects:
		bounds = bounds.merge(rect)
	# Covered even while empty: the canvas regrows only when the card moves.
	if readout.flag_home.size.x > 0.0:
		bounds = bounds.merge(readout.flag_home_area())
	bounds = bounds.merge(readout.tab_rect())
	var extent: Vector2 = Vector2(maxf(absf(bounds.position.x), absf(bounds.end.x)), maxf(absf(bounds.position.y), absf(bounds.end.y))) + Vector2(400, 400)
	var canvas_size: Vector2i = Vector2i(maxi(1600, ceili(extent.x * 2.0 / 128.0) * 128), maxi(1600, ceili(extent.y * 2.0 / 128.0) * 128))
	if viewport.size != canvas_size:
		viewport.size = canvas_size
		readout.size = Vector2(canvas_size)
		readout.request_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not interactive or not visible or duelist_uid < 0:
		if _hovered_sigil >= 0:
			hover_sigil(-1, null)
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	if event is InputEventMouseMotion:
		var point: Vector2 = (event as InputEventMouseMotion).position
		hover_sigil(sigil_at(point, camera), camera)
		var inside: bool = _hovered_sigil < 0 and hit_test(point, camera)
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


## The Resonance sigil under a screen point, -1 for none.
func sigil_at(point: Vector2, camera: Camera3D) -> int:
	if readout.sigil_rects.is_empty() or camera.is_position_behind(global_position):
		return -1
	var on_felt: Variant = _ray_on(surface, camera.project_ray_origin(point), camera.project_ray_normal(point))
	return readout.sigil_at(on_felt as Vector2) if on_felt != null else -1


## Lights sigil `index` (-1 for none) and says which Resonance it is and where it sits on screen.
func hover_sigil(index: int, camera: Camera3D) -> void:
	if index == _hovered_sigil:
		return
	_hovered_sigil = index
	readout.lit_sigil = index
	if index < 0 or index >= readout.resonances.size():
		resonance_hovered.emit("", Rect2(), false)
		return
	if not readout.far_side():
		resonance_hovered.emit(readout.resonances[index], sigil_screen_rect(index, camera), false)
		return
	resonance_hovered.emit(readout.resonances[index], far_tip_anchor(camera), true)


## Where the rival's tip opens from: the whole sigil row, its left edge moved past their hand fan
## when the fan sits over the row's left end, so the tip over the row leaves the hand count readable.
func far_tip_anchor(camera: Camera3D) -> Rect2:
	var row: Rect2 = sigil_screen_rect(0, camera)
	for i in range(1, readout.sigil_rects.size()):
		row = row.merge(sigil_screen_rect(i, camera))
	var fan: Rect2 = screen_rect_of(readout.hand_fan_rect(), camera)
	if fan.end.x > row.position.x and fan.position.x < row.end.x and fan.position.y < row.position.y:
		row = Rect2(Vector2(fan.end.x, row.position.y), Vector2(maxf(0.0, row.end.x - fan.end.x), row.size.y))
	return row


## The screen rectangle sigil `index` covers.
func sigil_screen_rect(index: int, camera: Camera3D) -> Rect2:
	return screen_rect_of(readout.sigil_rects[index], camera)


## The screen rectangle a region of the printed canvas covers.
func screen_rect_of(rect: Rect2, camera: Camera3D) -> Rect2:
	var bounds: Rect2 = Rect2(camera.unproject_position(_world_point(rect.position)), Vector2.ZERO)
	for corner: Vector2 in [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		bounds = bounds.expand(camera.unproject_position(_world_point(corner)))
	return bounds


## Only the printed regions are interactive; the centre belongs to the card.
func hit_test(point: Vector2, camera: Camera3D) -> bool:
	if camera.is_position_behind(global_position):
		return false
	var on_felt: Variant = _ray_on(surface, camera.project_ray_origin(point), camera.project_ray_normal(point))
	if on_felt == null:
		return false
	for rect: Rect2 in readout.stat_hit_rects:
		if rect.has_point(on_felt):
			return true
	return false


## The screen rectangle every printed region covers. The hand keeps below it.
func screen_rect(camera: Camera3D) -> Rect2:
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for rect: Rect2 in readout.stat_hit_rects:
		for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var point: Vector2 = camera.unproject_position(_world_point(corner))
			bounds = Rect2(point, Vector2.ZERO) if first else bounds.expand(point)
			first = false
	return bounds


## A point on the printed canvas (pixels from its centre) in the world, and back.
func _world_point(canvas_point: Vector2) -> Vector3:
	return surface.global_transform * Vector3(canvas_point.x * PIXEL, -canvas_point.y * PIXEL, 0)


func _canvas_point(world: Vector3) -> Vector2:
	var local: Vector3 = surface.global_transform.affine_inverse() * world
	return Vector2(local.x, -local.y) / PIXEL


## Where a screen ray meets a flat sprite, in that sprite's canvas pixels from its centre.
func _ray_on(sprite: Sprite3D, from: Vector3, direction: Vector3) -> Variant:
	var plane: Plane = Plane(sprite.global_basis.z.normalized(), sprite.global_position)
	var hit: Variant = plane.intersects_ray(from, direction)
	if hit == null:
		return null
	# In the sprite's own units: its node scale is undone by the inverse, only pixel_size is left.
	var local: Vector3 = sprite.global_transform.affine_inverse() * (hit as Vector3)
	return Vector2(local.x, -local.y) / sprite.pixel_size
