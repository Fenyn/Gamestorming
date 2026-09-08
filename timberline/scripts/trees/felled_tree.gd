class_name FelledTree
extends RigidBody3D
## A trunk knocked over by felling. Receives the standing tree's trunk
## mesh, trunk collision, and one MeshInstance3D per limb part (named
## Limb*, carrying part_size meta) at fell time.
##
## The tip-over starts kinematic because the physics solver's
## penetration recovery snaps the flat trunk base upright against any
## starting spin or torque; past TIP_RELEASE_ANGLE the body unfreezes
## with matched velocities and dynamics take over. On landing (a
## contact on the upper trunk) it kills most of its momentum and breaks
## some of the limbs it lands on loose as debris bodies.
##
## detach_limb() is public: the delimbing axe chop reuses it.

## Contact beyond this fraction of tree height from the base counts as
## the canopy/upper trunk hitting the ground.
const LAND_CONTACT_T: float = 0.4
## Chance that a limb in the impact zone snaps off on landing.
const LAND_DETACH_CHANCE: float = 0.6
const LAND_DETACH_MAX: int = 4
## Starting angular speed of the kinematic tip phase, rad/s.
const TIP_START_RATE: float = 0.1
## Tilt angle where the body unfreezes and dynamics take over, rad.
const TIP_RELEASE_ANGLE: float = 0.6

## Spec of the tree this came from, kept for delimb/buck geometry.
var spec: ConiferMeshBuilder.ConiferSpec = null
## World-space axis the fell rotates about, set by ConiferTree.
var fall_axis: Vector3 = Vector3.ZERO

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _tipping: bool = true
var _tip_angle: float = 0.0
var _tip_rate: float = TIP_START_RATE
var _landed: bool = false
var _converted: bool = false
var _limbs: Array[MeshInstance3D] = []
var _hitboxes: Dictionary[MeshInstance3D, LimbHitbox] = {}


func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with("Limb"):
			_limbs.append(child)
	for limb in _limbs:
		_make_limb_hitbox(limb)
	# Total tree mass: trunk wood by volume plus every attached limb.
	# Detaching a limb moves its share onto the debris body, so the sum
	# stays intact through the whole breakdown.
	if spec != null:
		var total: float = ConiferMeshBuilder.trunk_volume(
			spec, 0.0, spec.height * ConiferMeshBuilder.TRUNK_TOP_T) * ConiferMeshBuilder.WOOD_DENSITY
		for limb in _limbs:
			total += float(limb.get_meta("part_mass", 3.0))
		mass = total
	# World layer (a downed trunk blocks the player), and sees debris so
	# it can rest on already-shed limbs.
	collision_layer = 0b001
	collision_mask = 0b101
	contact_monitor = true
	max_contacts_reported = 8
	can_sleep = false
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = 1.0
	mat.bounce = 0.0
	physics_material_override = mat


## Kinematic tip phase: rotate about the base edge with the angular
## acceleration of a rod pivoting at its end, then hand off to dynamics.
func _physics_process(delta: float) -> void:
	if not _tipping or spec == null or fall_axis == Vector3.ZERO:
		return
	var fall_dir: Vector3 = fall_axis.cross(Vector3.UP)
	var pivot: Vector3 = global_position + fall_dir * (spec.base_radius * 0.9)

	_tip_rate += 1.5 * _gravity * sin(maxf(_tip_angle, 0.05)) / spec.height * delta
	var step: float = _tip_rate * delta
	_tip_angle += step

	var rot: Basis = Basis(fall_axis, step)
	global_transform = Transform3D(
		rot * global_basis, pivot + rot * (global_position - pivot)
	)

	if _tip_angle >= TIP_RELEASE_ANGLE:
		_tipping = false
		freeze = false
		angular_velocity = fall_axis * _tip_rate
		linear_velocity = (fall_axis * _tip_rate).cross(to_global(center_of_mass) - pivot)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _tipping or _landed or spec == null:
		return
	var trunk_axis: Vector3 = global_basis.y.normalized()
	var base: Vector3 = global_position
	for i in state.get_contact_count():
		var along: float = (state.get_contact_local_position(i) - base).dot(trunk_axis)
		if along > spec.height * LAND_CONTACT_T:
			_landed = true
			can_sleep = true
			# Limbs crumpling eat most of the impact energy.
			state.linear_velocity = state.linear_velocity * 0.6
			state.angular_velocity = state.angular_velocity * 0.5
			linear_damp = 1.0
			angular_damp = 2.0
			call_deferred("_on_landed")
			break


## An axe chop that lands on the bare trunk just knocks it; delimbing
## goes through the per-limb LimbHitbox areas, which route to chop_limb.
func receive_chop(_damage: float, point: Vector3, normal: Vector3) -> void:
	if _tipping:
		return
	apply_impulse(-normal * 12.0, point - global_position)


## A chop on a limb's own hitbox. Foliage tiers are destroyed outright;
## wood stubs break off as debris. Once the last limb is gone (chopped
## or broken in the fall), tree_delimbed fires and bucking takes over.
func chop_limb(limb: MeshInstance3D, point: Vector3, normal: Vector3) -> void:
	if _tipping or not _limbs.has(limb):
		return
	apply_impulse(-normal * 12.0, point - global_position)
	if bool(limb.get_meta("foliage", false)):
		_destroy_foliage(limb)
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var body: RigidBody3D = detach_limb(limb)
	body.linear_velocity += -normal * 1.0 + Vector3.UP * 0.6
	body.angular_velocity = Vector3(
		rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)
	)
	Fx.needle_burst(self, body.global_position, 0.5)


## Aim-only Area3D matching the limb mesh's AABB, so the axe ray hits
## the branch where it is drawn instead of only the trunk cylinder.
func _make_limb_hitbox(limb: MeshInstance3D) -> void:
	var hitbox: LimbHitbox = LimbHitbox.new()
	hitbox.name = limb.name + "Hitbox"
	hitbox.tree = self
	hitbox.limb = limb
	var aabb: AABB = limb.mesh.get_aabb()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = aabb.size.max(Vector3(0.15, 0.15, 0.15))
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = aabb.get_center()
	hitbox.add_child(collision)
	add_child(hitbox)
	hitbox.transform = limb.transform
	_hitboxes[limb] = hitbox


func _free_limb_hitbox(limb: MeshInstance3D) -> void:
	var hitbox: LimbHitbox = _hitboxes.get(limb, null)
	if hitbox != null and is_instance_valid(hitbox):
		hitbox.queue_free()
	_hitboxes.erase(limb)


## A chopped foliage tier bursts into needles and is simply gone.
func _destroy_foliage(limb: MeshInstance3D) -> void:
	_limbs.erase(limb)
	_free_limb_hitbox(limb)
	Fx.needle_burst(self, limb.global_position, float(limb.get_meta("part_size", 0.8)) * 0.7)
	mass = maxf(mass - float(limb.get_meta("part_mass", 3.0)), 1.0)
	limb.queue_free()
	if _limbs.is_empty() and not _converted:
		_converted = true
		call_deferred("_convert_to_trunk")


## Breaks a limb off this trunk as its own rigid body, carrying its
## actual mesh. Used by the landing impact and the delimbing chop.
## Returns the debris body, already inheriting the trunk's motion at
## the limb's position.
func detach_limb(limb: MeshInstance3D) -> RigidBody3D:
	_limbs.erase(limb)
	_free_limb_hitbox(limb)
	var size: float = 0.5
	if limb.has_meta("part_size"):
		size = float(limb.get_meta("part_size"))

	var limb_mass: float = float(limb.get_meta("part_mass", 3.0))
	var body: LimbDebris = LimbDebris.new()
	body.name = "LimbDebris"
	body.foliage = bool(limb.get_meta("foliage", false))
	body.burst_radius = size * 0.7
	body.mass = limb_mass
	mass = maxf(mass - limb_mass, 1.0)
	var origin: Transform3D = limb.global_transform
	remove_child(limb)
	limb.transform = Transform3D.IDENTITY
	body.add_child(limb)

	# Collider matching the branch's actual extent, so aiming at it and
	# carrying it line up with the visible mesh, and it lies flat
	# instead of rolling like a ball.
	var aabb: AABB = limb.mesh.get_aabb()
	body.carry_axis_local = aabb.get_longest_axis()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = aabb.size.max(Vector3(0.12, 0.12, 0.12))
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = aabb.get_center()
	body.add_child(collision)

	get_parent().add_child(body)
	body.global_transform = origin
	body.linear_velocity = linear_velocity \
		+ angular_velocity.cross(origin.origin - to_global(center_of_mass))
	if _limbs.is_empty() and not _converted:
		_converted = true
		call_deferred("_convert_to_trunk")
	return body


## The bare trunk becomes a TrunkPiece so bucking is one code path.
## The rebuilt mesh drops the standing tree's lean, which reads as the
## delimbed log settling straight.
func _convert_to_trunk() -> void:
	var piece: TrunkPiece = TrunkPiece.create(spec, 0.0, spec.height * ConiferMeshBuilder.TRUNK_TOP_T)
	get_parent().add_child(piece)
	piece.global_transform = global_transform
	piece.linear_velocity = linear_velocity
	piece.angular_velocity = angular_velocity
	EventBus.tree_delimbed.emit(piece)
	queue_free()


func _on_landed() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var detached: int = 0
	for limb in _limbs.duplicate():
		var in_impact_zone: bool = limb.position.y > spec.height * LAND_CONTACT_T
		if in_impact_zone and detached < LAND_DETACH_MAX and rng.randf() < LAND_DETACH_CHANCE:
			var body: RigidBody3D = detach_limb(limb)
			body.linear_velocity += Vector3(
				rng.randf_range(-0.8, 0.8), rng.randf_range(0.2, 0.8), rng.randf_range(-0.8, 0.8)
			)
			body.angular_velocity = Vector3(
				rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5)
			)
			Fx.needle_burst(self, body.global_position, 0.5)
			detached += 1

	# Dust kicked up along the grounded stretch of trunk, needles shaken
	# out of the canopy.
	var trunk_axis: Vector3 = global_basis.y.normalized()
	for i in 4:
		var t: float = lerpf(0.3, 0.95, float(i) / 3.0)
		Fx.dust_puff(self, global_position + trunk_axis * (t * spec.height), 0.7)
	Fx.needle_burst(self, global_position + trunk_axis * (spec.height * 0.7), 1.2)
