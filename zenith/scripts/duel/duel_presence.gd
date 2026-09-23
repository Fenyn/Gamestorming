class_name DuelPresence
extends Node3D
## The other online player's pointer on the table, and the pacing of our own presence messages.
## The ring is scene content (`Pointer` under this node); this script only colours, moves and
## fades it. The table (`duel_view.gd`) works out what the state means for its cards and HUD.

const SEND_INTERVAL_MS: int = 50      # at most 20 messages a second
const STALE_MS: int = 1000            # no word for this long and the pointer fades out
const KEEPALIVE_MS: int = 400         # an unchanged state is re-sent this often, well inside STALE_MS
const FADE_SPEED: float = 4.0         # alpha per second, in and out
const FOLLOW: float = 14.0            # how quickly the ring closes on the latest point, per second
const HEIGHT: float = 0.06            # above the cards on the felt

@onready var pointer: MeshInstance3D = $Pointer
@onready var dot: MeshInstance3D = $Pointer/Dot

var reduced_motion: bool = false
var _ring_mat: StandardMaterial3D = null
var _dot_mat: StandardMaterial3D = null
var _color: Color = Color.WHITE
var _sent: Dictionary = {}
var _last_send_ms: int = -SEND_INTERVAL_MS
var _target: Vector3 = Vector3.ZERO
var _showing: bool = false        # the latest word put the pointer on the table
var _heard_ms: int = 0
var _alpha: float = 0.0


func _ready() -> void:
	_ring_mat = (pointer.material_override as StandardMaterial3D).duplicate()
	_dot_mat = (dot.material_override as StandardMaterial3D).duplicate()
	pointer.material_override = _ring_mat
	dot.material_override = _dot_mat
	pointer.visible = false


func set_color(color: Color) -> void:
	_color = color
	_apply_alpha()


## Our own state this frame. Sent when it differs from what was last sent and the interval has
## passed. An unchanged state is repeated every KEEPALIVE_MS, so a pointer resting on a card does
## not go stale and fade on the other side.
func offer(state: Dictionary) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_send_ms < SEND_INTERVAL_MS:
		return
	if not PresenceState.differs(state, _sent) and now - _last_send_ms < KEEPALIVE_MS:
		return
	_sent = state
	_last_send_ms = now
	Net.send_presence(state)


## The other player's pointer: a world point on the felt, or null when it is off the table.
func place(point: Variant) -> void:
	_heard_ms = Time.get_ticks_msec()
	if point == null:
		_showing = false
		return
	var p: Vector3 = point
	_target = Vector3(p.x, HEIGHT, p.z)
	if not _showing or _alpha <= 0.0 or reduced_motion:
		pointer.position = _target
	_showing = true


func clear() -> void:
	_showing = false
	_alpha = 0.0
	pointer.visible = false


func _process(delta: float) -> void:
	var fresh: bool = _showing and Time.get_ticks_msec() - _heard_ms < STALE_MS
	if reduced_motion:
		pointer.position = _target
		_alpha = 1.0 if fresh else 0.0
	else:
		pointer.position = pointer.position.lerp(_target, clampf(delta * FOLLOW, 0.0, 1.0))
		_alpha = move_toward(_alpha, 1.0 if fresh else 0.0, delta * FADE_SPEED)
	pointer.visible = _alpha > 0.01
	_apply_alpha()


func _apply_alpha() -> void:
	if _ring_mat == null:
		return
	_ring_mat.albedo_color = Color(_color, 0.85 * _alpha)
	_dot_mat.albedo_color = Color(_color.lightened(0.35), 0.95 * _alpha)
