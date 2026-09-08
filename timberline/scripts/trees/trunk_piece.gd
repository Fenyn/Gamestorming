class_name TrunkPiece
extends RigidBody3D
## A cut section of trunk, spanning [start_m, end_m] of the source
## tree. Bucking is manual: chops build cut progress at the hit point
## (a notch ring marks the active cut; moving the aim resets it), and a
## finished cut splits the piece in two, emitting EventBus.log_bucked.
## Pieces at or under MAX_LOG_LENGTH count as finished logs (sell id,
## splitting block), but stay cuttable via can_cut() until further
## subdivision would drop a segment under MIN_SEGMENT_MASS or
## MIN_PIECE — so a heavy butt log can always be cut down to something
## liftable. Every piece is in the "carryable" group; CarrySystem lifts
## the light ones and ground-drags the heavy ones. Axe damage adds
## progress per chop, so faster tools shorten the work later.

## Pieces this short are finished logs.
const MAX_LOG_LENGTH: float = 1.5
## Progress needed to complete a cut (axe damage 1 = 1 per chop).
const CUT_CHOPS: int = 3
## A chop within this distance of the active cut adds to it; farther
## starts a new cut.
const CUT_GROUP_RADIUS: float = 0.35
## Cuts can't land closer than this to either end. Kept short so that
## on thick butt wood the weight floor below, not length, is what ends
## subdivision — dense pieces can always be cut down to liftable.
const MIN_PIECE: float = 0.25
## No cut may produce a segment lighter than this, and pieces that
## can't yield two such segments take no further cuts.
const MIN_SEGMENT_MASS: float = 8.0

var spec: ConiferMeshBuilder.ConiferSpec = null
var start_m: float = 0.0
var end_m: float = 0.0

var _cut_m: float = -1.0
var _cut_progress: int = 0
var _notch: MeshInstance3D = null
var _preview_ring: MeshInstance3D = null
var _preview_labels: Array[Label3D] = []


static func create(p_spec: ConiferMeshBuilder.ConiferSpec, p_start: float, p_end: float) -> TrunkPiece:
	var piece: TrunkPiece = TrunkPiece.new()
	piece.name = "TrunkPiece"
	piece.spec = p_spec
	piece.start_m = p_start
	piece.end_m = p_end

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "LogMesh"
	mesh_instance.mesh = ConiferMeshBuilder.build_log_mesh(rng, p_spec, p_start, p_end)
	piece.add_child(mesh_instance)

	var length: float = p_end - p_start
	var mid_r: float = ConiferMeshBuilder.trunk_radius_at(p_spec, (p_start + length * 0.5) / p_spec.height)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = mid_r
	shape.height = length
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, length * 0.5, 0.0)
	piece.add_child(collision)

	# Mass from wood volume; sub-piece volumes telescope, so however a
	# trunk is subdivided the total mass is conserved.
	piece.mass = maxf(2.0,
		ConiferMeshBuilder.trunk_volume(p_spec, p_start, p_end) * ConiferMeshBuilder.WOOD_DENSITY)
	piece.angular_damp = 1.0
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = 1.0
	mat.bounce = 0.0
	piece.physics_material_override = mat
	# Every piece can at least be grabbed; CarrySystem decides between
	# lifting and ground-dragging by mass. All trunk pieces are solid
	# obstacles on the world layer (only branch debris is walk-through);
	# they see the debris layer so shed limbs can rest against them.
	piece.add_to_group("carryable")
	piece.collision_layer = 0b001
	piece.collision_mask = 0b101
	return piece


func piece_length() -> float:
	return end_m - start_m


## Local grain direction; CarrySystem holds the log lying along this.
func carry_axis() -> Vector3:
	return Vector3.UP


func is_log() -> bool:
	return piece_length() <= MAX_LOG_LENGTH + 0.01


## Whether another cut is possible: both would-be segments must clear
## MIN_PIECE in length and MIN_SEGMENT_MASS in weight.
func can_cut() -> bool:
	return piece_length() >= 2.0 * MIN_PIECE and mass >= 2.0 * MIN_SEGMENT_MASS


## Cut position along the piece a chop at this point would land on,
## clamped so neither side ends up under MIN_PIECE or MIN_SEGMENT_MASS.
func projected_cut_m(point: Vector3) -> float:
	var length: float = piece_length()
	var low: float = maxf(MIN_PIECE, _min_length_for_mass(true))
	var high: float = minf(length - MIN_PIECE, length - _min_length_for_mass(false))
	if low > high:
		return length * 0.5
	return clampf(to_local(point).y, low, high)


## Shortest segment length from one end whose wood reaches
## MIN_SEGMENT_MASS, by bisection on the volume integral.
func _min_length_for_mass(from_bottom: bool) -> float:
	var length: float = piece_length()
	var lo: float = 0.0
	var hi: float = length
	for i in 20:
		var mid: float = (lo + hi) * 0.5
		var segment_mass: float
		if from_bottom:
			segment_mass = ConiferMeshBuilder.trunk_volume(spec, start_m, start_m + mid) \
				* ConiferMeshBuilder.WOOD_DENSITY
		else:
			segment_mass = ConiferMeshBuilder.trunk_volume(spec, end_m - mid, end_m) \
				* ConiferMeshBuilder.WOOD_DENSITY
		if segment_mass < MIN_SEGMENT_MASS:
			lo = mid
		else:
			hi = mid
	return hi


## Diegetic bucking preview while the axe hovers this piece: an amber
## ring at the projected cut, and the weights of the two would-be
## segments floating over each side. Driven per-frame by the axe.
func show_cut_preview(point: Vector3) -> void:
	if not can_cut():
		return
	_ensure_preview_nodes()
	var cut: float = projected_cut_m(point)
	var r: float = ConiferMeshBuilder.trunk_radius_at(spec, (start_m + cut) / spec.height)
	var ring: CylinderMesh = _preview_ring.mesh as CylinderMesh
	ring.top_radius = r + 0.02
	ring.bottom_radius = r + 0.02
	_preview_ring.visible = true
	_preview_ring.position = Vector3(0.0, cut, 0.0)

	var up_local: Vector3 = (global_basis.inverse() * Vector3.UP).normalized()
	var masses: Array[float] = [
		ConiferMeshBuilder.trunk_volume(spec, start_m, start_m + cut) * ConiferMeshBuilder.WOOD_DENSITY,
		ConiferMeshBuilder.trunk_volume(spec, start_m + cut, end_m) * ConiferMeshBuilder.WOOD_DENSITY,
	]
	var offsets: Array[float] = [-0.45, 0.45]
	for i in 2:
		var label: Label3D = _preview_labels[i]
		label.visible = true
		label.text = "%d kg" % roundi(masses[i])
		label.position = Vector3(0.0, cut + offsets[i], 0.0) + up_local * (r + 0.3)


func has_active_cut() -> bool:
	return _cut_m >= 0.0


## De-buck: abandon the started cut so the line can be moved. Chopping
## far from the notch also restarts it, but this clears it outright.
func clear_cut() -> void:
	_cut_m = -1.0
	_cut_progress = 0
	if _notch != null:
		_notch.queue_free()
		_notch = null


func hide_cut_preview() -> void:
	if _preview_ring != null:
		_preview_ring.visible = false
	for label in _preview_labels:
		label.visible = false


func _ensure_preview_nodes() -> void:
	if _preview_ring != null:
		return
	var ring: CylinderMesh = CylinderMesh.new()
	ring.height = 0.02
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.75, 0.25, 0.85)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material = ring_mat
	_preview_ring = MeshInstance3D.new()
	_preview_ring.name = "CutPreviewRing"
	_preview_ring.mesh = ring
	add_child(_preview_ring)
	for i in 2:
		var label: Label3D = Label3D.new()
		label.name = "CutPreviewLabel%d" % i
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 40
		label.outline_size = 10
		label.pixel_size = 0.004
		label.modulate = Color(1.0, 0.9, 0.7)
		add_child(label)
		_preview_labels.append(label)


func receive_chop(damage: float, point: Vector3, normal: Vector3) -> void:
	# Loaded on a splitting block: the station owns the chop.
	if has_meta("split_station"):
		var station: Object = get_meta("split_station")
		if station != null and is_instance_valid(station):
			station.call("chop_loaded", damage, point, normal)
			return
	apply_impulse(-normal * 8.0, point - global_position)
	if not can_cut():
		return
	var cut: float = projected_cut_m(point)
	if _cut_m >= 0.0 and absf(cut - _cut_m) <= CUT_GROUP_RADIUS:
		_cut_progress += maxi(roundi(damage), 1)
	else:
		_cut_m = cut
		_cut_progress = maxi(roundi(damage), 1)
		_update_notch()
	if _cut_progress >= CUT_CHOPS:
		_split()


## Dark ring marking the active cut.
func _update_notch() -> void:
	if _notch == null:
		_notch = MeshInstance3D.new()
		_notch.name = "Notch"
		add_child(_notch)
	var r: float = ConiferMeshBuilder.trunk_radius_at(spec, (start_m + _cut_m) / spec.height)
	var ring: CylinderMesh = CylinderMesh.new()
	ring.top_radius = r + 0.015
	ring.bottom_radius = r + 0.015
	ring.height = 0.05
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = ConiferMeshBuilder.CUT_WOOD_COLOR.darkened(0.35)
	mat.roughness = 1.0
	ring.material = mat
	_notch.mesh = ring
	_notch.position = Vector3(0.0, _cut_m, 0.0)


func _split() -> void:
	var cut_world: Vector3 = to_global(Vector3(0.0, _cut_m, 0.0))
	var below: TrunkPiece = TrunkPiece.create(spec, start_m, start_m + _cut_m)
	var above: TrunkPiece = TrunkPiece.create(spec, start_m + _cut_m, end_m)
	var parent: Node = get_parent()
	parent.add_child(below)
	parent.add_child(above)
	below.global_transform = global_transform
	above.global_transform = global_transform.translated_local(Vector3(0.0, _cut_m, 0.0))

	# Pieces drift apart along the grain; the upper piece pops slightly.
	var axis: Vector3 = global_basis.y.normalized()
	below.linear_velocity = linear_velocity - axis * 0.3
	below.angular_velocity = angular_velocity
	above.linear_velocity = linear_velocity + axis * 0.3 + Vector3.UP * 0.5
	above.angular_velocity = angular_velocity

	Fx.wood_chips(below, cut_world, Vector3.UP)
	var log_count: int = (1 if below.is_log() else 0) + (1 if above.is_log() else 0)
	EventBus.log_bucked.emit(self, log_count)
	queue_free()
