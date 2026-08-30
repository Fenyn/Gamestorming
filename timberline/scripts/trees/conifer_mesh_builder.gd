## Builds flat-shaded low-poly conifer meshes from a seeded RNG.
##
## All geometry is emitted unindexed so generate_normals() produces one
## normal per face (the faceted look). Coloring is vertex colors on a
## single shared material, so every tree costs 2 draw calls and no
## per-tree materials.
##
## @tool so ConiferTree (a tool script) can build meshes in the editor.

@tool
class_name ConiferMeshBuilder
extends RefCounted


# --- Palette ---

const BARK_COLOR := Color(0.27, 0.20, 0.14)
const CUT_WOOD_COLOR := Color(0.52, 0.42, 0.30)
const FOLIAGE_COLORS: Array[Color] = [
	Color(0.16, 0.30, 0.20),
	Color(0.20, 0.36, 0.23),
	Color(0.26, 0.40, 0.28),
]

# --- Trunk shape ---

const TRUNK_RINGS := 5
# The trunk mesh stops at this fraction of tree height, safely inside
# the canopy, so it can never poke out past the tip cone.
const TRUNK_TOP_T := 0.8
const TRUNK_TAPER_EXPONENT := 0.85
const TOP_RADIUS_FACTOR := 0.3
const RING_CENTER_JITTER := 0.04
const RING_RADIUS_JITTER := 0.08

# --- Branch stubs ---

const STUB_MIN_T := 0.12
const STUB_BASE_HALF_WIDTH := 0.11
const STUB_END_HALF_WIDTH := 0.055
const STUB_LENGTH_RANGE := Vector2(0.25, 0.45)
const STUB_DROOP_DEG_RANGE := Vector2(15.0, 35.0)

# --- Canopy ---

const CANOPY_SIDES := 7
const CANOPY_TIP_RADIUS := 0.25
const CANOPY_OVERLAP := 1.7
const CANOPY_RADIUS_JITTER := 0.12
const CANOPY_RING_Y_JITTER := 0.1
const CANOPY_LATERAL_JITTER := 0.12

# --- Mass ---

## Wood density used for gameplay masses, kg/m^3. Well below real green
## conifer (~700) so a tree cut into small chunks is haulable by hand.
const WOOD_DENSITY := 300.0
const VOLUME_INTEGRATION_STEP := 0.1

static var _shared_material: StandardMaterial3D


## One canopy tier or branch stub, meshed in attachment-local space so
## a felled tree can bend or detach it individually. `transform` places
## part-local space in tree-local space (translation only; the origin
## is the attachment point, which doubles as the bend pivot). `size` is
## a rough bounding radius for debris collision shapes. `mass` is the
## limb's share of the tree's weight (foliage tiers are mostly air, so
## these are gameplay numbers, not volume-derived).
class LimbPart:
	var transform: Transform3D
	var mesh: ArrayMesh
	var size: float
	var mass: float
	## Foliage tiers are destroyed by chops; wood stubs become debris.
	var foliage: bool


## Per-tree shape parameters, rolled once and shared by trunk and limbs
## so both track the same lean and proportions.
class ConiferSpec:
	var height: float
	var base_radius: float
	var top_radius: float
	var trunk_sides: int
	var lean_dir: Vector2
	var lean_amount: float
	var canopy_base_t: float
	var tier_count: int
	var bark_color: Color
	var foliage_color: Color


# --- Public API ---

static func make_spec(rng: RandomNumberGenerator, height_range: Vector2, radius_range: Vector2, tier_range: Vector2i, lean_max: float, color_jitter: float) -> ConiferSpec:
	var spec := ConiferSpec.new()
	spec.height = rng.randf_range(height_range.x, height_range.y)
	spec.base_radius = rng.randf_range(radius_range.x, radius_range.y)
	spec.top_radius = spec.base_radius * TOP_RADIUS_FACTOR
	spec.trunk_sides = rng.randi_range(5, 7)
	var lean_angle := rng.randf_range(0.0, TAU)
	spec.lean_dir = Vector2(cos(lean_angle), sin(lean_angle))
	spec.lean_amount = rng.randf_range(0.0, lean_max) * spec.height
	spec.canopy_base_t = rng.randf_range(0.26, 0.34)
	spec.tier_count = rng.randi_range(tier_range.x, tier_range.y)
	spec.bark_color = _jitter_color(rng, BARK_COLOR, color_jitter)
	var base_green: Color = FOLIAGE_COLORS[rng.randi_range(0, FOLIAGE_COLORS.size() - 1)]
	spec.foliage_color = _jitter_color(rng, base_green, color_jitter)
	return spec


## XZ offset of the tree's spine at normalized height t (0..1).
## Quadratic so the base stays planted and the tip carries the lean.
static func spine_offset(spec: ConiferSpec, t: float) -> Vector3:
	var bend := spec.lean_amount * t * t
	return Vector3(spec.lean_dir.x * bend, 0.0, spec.lean_dir.y * bend)


## Trunk radius at normalized height t (0..1). Shared with future
## bucking code so log meshes can match the standing trunk.
static func trunk_radius_at(spec: ConiferSpec, t: float) -> float:
	return lerpf(spec.base_radius, spec.top_radius, pow(t, TRUNK_TAPER_EXPONENT))


## Wood volume of the trunk between start_m and end_m, in m^3. Defined
## as F(end) - F(start) over a cumulative integral, so sub-segment
## volumes telescope and always sum exactly to their parent's volume,
## no matter how a trunk is subdivided.
static func trunk_volume(spec: ConiferSpec, start_m: float, end_m: float) -> float:
	return _cumulative_trunk_volume(spec, end_m) - _cumulative_trunk_volume(spec, start_m)


## Trapezoid integration of pi*r^2 from the base to to_m on a fixed
## grid, deterministic for a given spec.
static func _cumulative_trunk_volume(spec: ConiferSpec, to_m: float) -> float:
	var total := 0.0
	var steps := int(ceil(to_m / VOLUME_INTEGRATION_STEP))
	for i in steps:
		var a := minf(float(i) * VOLUME_INTEGRATION_STEP, to_m)
		var b := minf(float(i + 1) * VOLUME_INTEGRATION_STEP, to_m)
		var ra := trunk_radius_at(spec, a / spec.height)
		var rb := trunk_radius_at(spec, b / spec.height)
		total += PI * 0.5 * (ra * ra + rb * rb) * (b - a)
	return total


static func build_trunk_mesh(rng: RandomNumberGenerator, spec: ConiferSpec) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(get_shared_material())

	var sides := spec.trunk_sides
	var rings: Array[PackedVector3Array] = []
	var ring_colors: Array[Color] = []
	for i in TRUNK_RINGS:
		var t := TRUNK_TOP_T * float(i) / float(TRUNK_RINGS - 1)
		var center := Vector3(0.0, t * spec.height, 0.0) + spine_offset(spec, t)
		if i > 0:
			var jitter := spec.base_radius * RING_CENTER_JITTER
			center += Vector3(rng.randf_range(-jitter, jitter), 0.0, rng.randf_range(-jitter, jitter))
		var radius := trunk_radius_at(spec, t)
		var ring := PackedVector3Array()
		for j in sides:
			var angle := TAU * float(j) / float(sides)
			var r := radius * (1.0 + rng.randf_range(-RING_RADIUS_JITTER, RING_RADIUS_JITTER))
			ring.append(center + Vector3(cos(angle) * r, 0.0, sin(angle) * r))
		rings.append(ring)
		var shift := rng.randf_range(-0.04, 0.04)
		ring_colors.append(spec.bark_color.lightened(maxf(shift, 0.0)).darkened(maxf(-shift, 0.0)))

	# Skin adjacent rings; bottom ring stays open (buried in the ground).
	for i in TRUNK_RINGS - 1:
		for j in sides:
			var jn := (j + 1) % sides
			var a := rings[i][j]
			var a1 := rings[i][jn]
			var b := rings[i + 1][j]
			var b1 := rings[i + 1][jn]
			_add_tri(st, a, a1, b1, ring_colors[i], ring_colors[i], ring_colors[i + 1])
			_add_tri(st, a, b1, b, ring_colors[i], ring_colors[i + 1], ring_colors[i + 1])

	# Flat fan cap on the top ring; the trunk ends hidden inside the canopy.
	var top_ring := rings[TRUNK_RINGS - 1]
	var top_center := Vector3.ZERO
	for v in top_ring:
		top_center += v
	top_center /= float(sides)
	var cap_color := spec.bark_color.darkened(0.15)
	for j in sides:
		var jn := (j + 1) % sides
		_add_tri(st, top_center, top_ring[j], top_ring[jn], cap_color, cap_color, cap_color)

	# Cut cap just inside the bottom ring: buried while standing, reads
	# as the sawn base once the trunk is felled. Raised 2cm so it never
	# z-fights the ground plane.
	var lift := Vector3(0.0, 0.02, 0.0)
	var bottom_ring := rings[0]
	var bottom_center := Vector3.ZERO
	for v in bottom_ring:
		bottom_center += v
	bottom_center = bottom_center / float(sides) + lift
	for j in sides:
		var jn := (j + 1) % sides
		_add_tri(st, bottom_center, bottom_ring[jn] + lift, bottom_ring[j] + lift,
			CUT_WOOD_COLOR, CUT_WOOD_COLOR, CUT_WOOD_COLOR)

	st.generate_normals()
	return st.commit()


## A straight cut trunk section spanning [start_m, end_m] of the source
## tree, cut caps on both ends. Piece-local: bottom cap at y=0, section
## runs up +Y. Ignores the source tree's lean; cut logs read fine
## straight.
static func build_log_mesh(rng: RandomNumberGenerator, spec: ConiferSpec, start_m: float, end_m: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(get_shared_material())
	var sides := spec.trunk_sides
	var length := end_m - start_m
	var ring_count := maxi(2, int(ceil(length / 1.5)) + 1)
	var rings: Array[PackedVector3Array] = []
	var ring_colors: Array[Color] = []
	for i in ring_count:
		var f := float(i) / float(ring_count - 1)
		var radius := trunk_radius_at(spec, (start_m + length * f) / spec.height)
		var ring := PackedVector3Array()
		for j in sides:
			var angle := TAU * float(j) / float(sides)
			var r := radius * (1.0 + rng.randf_range(-RING_RADIUS_JITTER, RING_RADIUS_JITTER))
			ring.append(Vector3(cos(angle) * r, length * f, sin(angle) * r))
		rings.append(ring)
		var shift := rng.randf_range(-0.04, 0.04)
		ring_colors.append(spec.bark_color.lightened(maxf(shift, 0.0)).darkened(maxf(-shift, 0.0)))
	for i in ring_count - 1:
		for j in sides:
			var jn := (j + 1) % sides
			_add_tri(st, rings[i][j], rings[i][jn], rings[i + 1][jn], ring_colors[i], ring_colors[i], ring_colors[i + 1])
			_add_tri(st, rings[i][j], rings[i + 1][jn], rings[i + 1][j], ring_colors[i], ring_colors[i + 1], ring_colors[i + 1])
	_add_ring_cap(st, rings[ring_count - 1], false, CUT_WOOD_COLOR)
	_add_ring_cap(st, rings[0], true, CUT_WOOD_COLOR)
	st.generate_normals()
	return st.commit()


static func _add_ring_cap(st: SurfaceTool, ring: PackedVector3Array, facing_down: bool, color: Color) -> void:
	var center := Vector3.ZERO
	for v in ring:
		center += v
	center /= float(ring.size())
	for j in ring.size():
		var jn := (j + 1) % ring.size()
		if facing_down:
			_add_tri(st, center, ring[jn], ring[j], color, color, color)
		else:
			_add_tri(st, center, ring[j], ring[jn], color, color, color)


## A short sawn-off stump left behind at the fell site. Slightly flared
## base, jagged cut rim, cut-wood cap.
static func build_stump_mesh(rng: RandomNumberGenerator, spec: ConiferSpec, stump_height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(get_shared_material())
	var sides := spec.trunk_sides
	var top_r := trunk_radius_at(spec, stump_height / spec.height)
	var bottom := PackedVector3Array()
	var top := PackedVector3Array()
	for j in sides:
		var angle := TAU * float(j) / float(sides)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var jitter_b := 1.0 + rng.randf_range(-RING_RADIUS_JITTER, RING_RADIUS_JITTER)
		var jitter_t := 1.0 + rng.randf_range(-RING_RADIUS_JITTER, RING_RADIUS_JITTER)
		bottom.append(dir * (spec.base_radius * 1.08 * jitter_b))
		top.append(dir * (top_r * jitter_t) + Vector3(0.0, stump_height + rng.randf_range(-0.05, 0.03), 0.0))
	for j in sides:
		var jn := (j + 1) % sides
		_add_tri(st, bottom[j], bottom[jn], top[jn], spec.bark_color, spec.bark_color, spec.bark_color)
		_add_tri(st, bottom[j], top[jn], top[j], spec.bark_color, spec.bark_color, spec.bark_color)
	var top_center := Vector3.ZERO
	for v in top:
		top_center += v
	top_center /= float(sides)
	var cut := CUT_WOOD_COLOR.lightened(0.05)
	for j in sides:
		var jn := (j + 1) % sides
		_add_tri(st, top_center, top[j], top[jn], cut, cut, cut)
	st.generate_normals()
	return st.commit()


static func build_limbs_mesh(rng: RandomNumberGenerator, spec: ConiferSpec) -> ArrayMesh:
	return merge_limb_parts(build_limb_parts(rng, spec))


## Builds every branch stub and canopy tier as an individual LimbPart.
## Same rng draw order as the pre-part code, so seeds keep their look.
static func build_limb_parts(rng: RandomNumberGenerator, spec: ConiferSpec) -> Array[LimbPart]:
	var parts: Array[LimbPart] = []
	_add_stub_parts(parts, rng, spec)
	_add_canopy_parts(parts, rng, spec)
	return parts


## Bakes parts into one mesh for the standing tree, keeping the forest
## at two draw calls per tree.
static func merge_limb_parts(parts: Array[LimbPart]) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(get_shared_material())
	for part in parts:
		st.append_from(part.mesh, 0, part.transform)
	return st.commit()


static func get_shared_material() -> StandardMaterial3D:
	if _shared_material == null:
		_shared_material = StandardMaterial3D.new()
		_shared_material.vertex_color_use_as_albedo = true
		# Palette colors are authored in sRGB; without this they render washed out.
		_shared_material.vertex_color_is_srgb = true
		_shared_material.roughness = 0.9
	return _shared_material


# --- Limbs ---

static func _add_stub_parts(parts: Array[LimbPart], rng: RandomNumberGenerator, spec: ConiferSpec) -> void:
	var stub_count := rng.randi_range(3, 5)
	var stub_color := spec.bark_color.darkened(0.1)
	var base_azimuth := rng.randf_range(0.0, TAU)
	for s in stub_count:
		# Evenly spread azimuths with a small wobble keeps stubs >= ~60 deg apart.
		var azimuth := base_azimuth + TAU * float(s) / float(stub_count) + rng.randf_range(-0.3, 0.3)
		var t := rng.randf_range(STUB_MIN_T, spec.canopy_base_t)
		var trunk_r := trunk_radius_at(spec, t)
		var spine_point := Vector3(0.0, t * spec.height, 0.0) + spine_offset(spec, t)
		var out_dir := Vector3(cos(azimuth), 0.0, sin(azimuth))
		var droop := deg_to_rad(rng.randf_range(STUB_DROOP_DEG_RANGE.x, STUB_DROOP_DEG_RANGE.y))
		var axis := (out_dir * cos(droop) + Vector3.DOWN * sin(droop)).normalized()
		# Base sits inside the trunk so jittered trunk faces never show a gap.
		var base_center := spine_point + out_dir * (trunk_r * 0.6)
		var length := rng.randf_range(STUB_LENGTH_RANGE.x, STUB_LENGTH_RANGE.y)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(get_shared_material())
		_add_branch_stub(st, Vector3.ZERO, axis, trunk_r + length, stub_color)
		st.generate_normals()
		var part := LimbPart.new()
		part.mesh = st.commit()
		part.transform = Transform3D(Basis.IDENTITY, base_center)
		part.size = trunk_r + length
		part.mass = maxf(1.0, 3.6 * part.size)
		part.foliage = false
		parts.append(part)


## A truncated square frustum reading as a sawn-off branch: chunky base
## at the trunk, narrower blunt end capped in cut-wood color.
static func _add_branch_stub(st: SurfaceTool, base_center: Vector3, axis: Vector3, length: float, color: Color) -> void:
	var u := axis.cross(Vector3.UP).normalized()
	var v := u.cross(axis).normalized()
	var end_center := base_center + axis * length
	var base_corners: Array[Vector3] = []
	var end_corners: Array[Vector3] = []
	for offset: Vector3 in [u + v, u - v, -u - v, -u + v]:
		base_corners.append(base_center + offset * STUB_BASE_HALF_WIDTH)
		end_corners.append(end_center + offset * STUB_END_HALF_WIDTH)
	for i in 4:
		var i_next := (i + 1) % 4
		var a := base_corners[i]
		var b := base_corners[i_next]
		var c := end_corners[i_next]
		var d := end_corners[i]
		var centroid := (a + b + c + d) / 4.0
		var axis_point := base_center + axis * (centroid - base_center).dot(axis)
		var outward := centroid - axis_point
		_add_tri_facing(st, a, b, c, outward, color)
		_add_tri_facing(st, a, c, d, outward, color)
	_add_tri_facing(st, end_corners[0], end_corners[1], end_corners[2], axis, CUT_WOOD_COLOR)
	_add_tri_facing(st, end_corners[0], end_corners[2], end_corners[3], axis, CUT_WOOD_COLOR)
	# Base cap in cut-wood so a snapped-off branch shows a break face,
	# not a hollow tube. Hidden inside the trunk while attached.
	_add_tri_facing(st, base_corners[0], base_corners[1], base_corners[2], -axis, CUT_WOOD_COLOR)
	_add_tri_facing(st, base_corners[0], base_corners[2], base_corners[3], -axis, CUT_WOOD_COLOR)


static func _add_canopy_parts(parts: Array[LimbPart], rng: RandomNumberGenerator, spec: ConiferSpec) -> void:
	var canopy_bottom := spec.canopy_base_t * spec.height
	var span := spec.height - canopy_bottom
	var spacing := span / float(spec.tier_count)
	var r_max := clampf(spec.height * 0.18, 1.1, 1.8)
	var underside_color := spec.foliage_color.darkened(0.3)
	for i in spec.tier_count:
		var ti := 0.0
		if spec.tier_count > 1:
			ti = float(i) / float(spec.tier_count - 1)
		var base_y := canopy_bottom + spacing * float(i)
		var base_t := clampf(base_y / spec.height, 0.0, 1.0)
		var base_center := Vector3(0.0, base_y, 0.0) + spine_offset(spec, base_t)
		# Fade lateral jitter toward the top so the spire stays on the spine.
		var jitter := CANOPY_LATERAL_JITTER * (1.0 - 0.7 * ti)
		base_center += Vector3(
			rng.randf_range(-jitter, jitter),
			0.0,
			rng.randf_range(-jitter, jitter)
		)
		var base_radius := lerpf(r_max, CANOPY_TIP_RADIUS, pow(ti, 1.2))
		# Tier geometry is part-local around base_center (the tier's
		# attachment on the spine).
		var apex := Vector3(0.0, spacing * CANOPY_OVERLAP, 0.0)
		var rot := rng.randf_range(0.0, TAU)
		var ring := PackedVector3Array()
		for j in CANOPY_SIDES:
			var angle := rot + TAU * float(j) / float(CANOPY_SIDES)
			var r := base_radius * (1.0 + rng.randf_range(-CANOPY_RADIUS_JITTER, CANOPY_RADIUS_JITTER))
			var y := rng.randf_range(-CANOPY_RING_Y_JITTER, CANOPY_RING_Y_JITTER)
			ring.append(Vector3(cos(angle) * r, y, sin(angle) * r))
		var side_shift := lerpf(-0.08, 0.04, ti)
		var side_color := spec.foliage_color.lightened(maxf(side_shift, 0.0)).darkened(maxf(-side_shift, 0.0))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(get_shared_material())
		for j in CANOPY_SIDES:
			var jn := (j + 1) % CANOPY_SIDES
			_add_tri(st, ring[j], ring[jn], apex, side_color, side_color, side_color)
			# Underside cap: the skirt is visible from below.
			_add_tri(st, Vector3.ZERO, ring[jn], ring[j], underside_color, underside_color, underside_color)
		st.generate_normals()
		var part := LimbPart.new()
		part.mesh = st.commit()
		part.transform = Transform3D(Basis.IDENTITY, base_center)
		part.size = base_radius
		part.mass = 2.0 + base_radius * base_radius * 4.0
		part.foliage = true
		parts.append(part)


# --- Triangle emission ---

static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


## Emits a-b-c wound so the face normal points along `outward`
## (Godot front faces are clockwise; normal = (c - a) x (b - a)).
static func _add_tri_facing(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, color: Color) -> void:
	var normal := (c - a).cross(b - a)
	if normal.dot(outward) >= 0.0:
		_add_tri(st, a, b, c, color, color, color)
	else:
		_add_tri(st, a, c, b, color, color, color)


static func _jitter_color(rng: RandomNumberGenerator, base: Color, amount: float) -> Color:
	var h := fposmod(base.h + rng.randf_range(-amount, amount) * 0.25, 1.0)
	var s := clampf(base.s + rng.randf_range(-amount, amount) * 0.5, 0.0, 1.0)
	var v := clampf(base.v + rng.randf_range(-amount, amount), 0.05, 1.0)
	return Color.from_hsv(h, s, v)
