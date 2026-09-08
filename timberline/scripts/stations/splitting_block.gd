class_name SplittingBlock
extends StaticBody3D
## Chopping block: set a bucked log into the LoadZone and it snaps
## lying across the block, frozen. Axe chops on it build progress
## (forwarded here by TrunkPiece via the "split_station" meta); at
## SPLIT_CHOPS the log bursts into Firewood wedges whose masses sum to
## the log's, and item_processed fires. Grabbing the loaded log with E
## takes it back off the block. Axe damage scales progress per chop, so
## better tools split faster later.

const SPLIT_CHOPS: int = 2
## Target mass per firewood wedge; count derives from log mass.
const PIECE_MASS: float = 6.0
const PIECE_COUNT_MAX: int = 12
const SCAN_INTERVAL: float = 0.25
## Height of the block's top face above the station origin.
const BLOCK_TOP: float = 0.55

var _loaded: TrunkPiece = null
var _progress: int = 0
var _scan_accum: float = 0.0

@onready var _zone: Area3D = $LoadZone


func _physics_process(delta: float) -> void:
	if _loaded != null:
		if not is_instance_valid(_loaded):
			_loaded = null
			_progress = 0
		elif bool(_loaded.get_meta("carried", false)):
			# The player lifted the log back off the block.
			_loaded.remove_meta("split_station")
			_loaded = null
			_progress = 0
	if _loaded != null:
		return
	_scan_accum += delta
	if _scan_accum < SCAN_INTERVAL:
		return
	_scan_accum = 0.0
	for node in _zone.get_overlapping_bodies():
		var piece: TrunkPiece = node as TrunkPiece
		if piece == null or not piece.is_log() or bool(piece.get_meta("carried", false)):
			continue
		_load_log(piece)
		break


## Snaps the log lying across the block top, frozen in place.
func _load_log(piece: TrunkPiece) -> void:
	_loaded = piece
	_progress = 0
	piece.freeze = true
	piece.linear_velocity = Vector3.ZERO
	piece.angular_velocity = Vector3.ZERO
	piece.set_meta("split_station", self)
	var length: float = piece.piece_length()
	var mid_r: float = ConiferMeshBuilder.trunk_radius_at(
		piece.spec, (piece.start_m + length * 0.5) / piece.spec.height)
	# Log local Y (the grain) lies along the station's X axis.
	var lying: Basis = global_basis * Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5)
	var center: Vector3 = to_global(Vector3(0.0, BLOCK_TOP + mid_r, 0.0))
	piece.global_transform = Transform3D(lying, center - lying * Vector3(0.0, length * 0.5, 0.0))
	Fx.dust_puff(self, center, 0.4)


## Forwarded from TrunkPiece.receive_chop while the log is loaded.
func chop_loaded(damage: float, point: Vector3, normal: Vector3) -> void:
	if _loaded == null or not is_instance_valid(_loaded):
		return
	_progress += maxi(roundi(damage), 1)
	Fx.wood_chips(self, point, normal)
	if _progress >= SPLIT_CHOPS:
		_split()


## The log bursts into firewood wedges scattered off the block. Wedge
## masses sum to the log's mass, keeping the weight ledger intact.
func _split() -> void:
	var piece: TrunkPiece = _loaded
	_loaded = null
	_progress = 0
	var count: int = clampi(roundi(piece.mass / PIECE_MASS), 2, PIECE_COUNT_MAX)
	var wedge_mass: float = piece.mass / count
	var axis: Vector3 = piece.global_basis.y.normalized()
	var center: Vector3 = piece.to_global(Vector3(0.0, piece.piece_length() * 0.5, 0.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		var wood: Firewood = Firewood.create(wedge_mass)
		get_parent().add_child(wood)
		var t: float = (float(i) + 0.5) / count - 0.5
		wood.global_position = piece.to_global(
			Vector3(0.0, (t + 0.5) * piece.piece_length(), 0.0)) + Vector3.UP * 0.1
		wood.rotation = Vector3(
			rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU))
		# Pop apart: outward from the block, along the log, and up.
		var side: Vector3 = Vector3.UP.cross(axis).normalized()
		wood.linear_velocity = axis * (t * 2.0) \
			+ side * rng.randf_range(-1.2, 1.2) + Vector3.UP * rng.randf_range(1.0, 2.0)
		wood.angular_velocity = Vector3(
			rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
	Fx.wood_chips(self, center, Vector3.UP)
	Fx.dust_puff(self, center, 0.5)
	EventBus.item_processed.emit("splitting_block", "firewood", count)
	piece.queue_free()
