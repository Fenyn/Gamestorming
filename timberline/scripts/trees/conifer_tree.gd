## A standing procedural conifer. Runs as a tool script so trees are
## visible and configurable in the editor; any export change rebuilds
## the tree live. Mesh and collision children are created ownerless at
## generate time, so saving a scene never bakes generated geometry.
##
## Axe chops wear down the Health child; the killing chop hands the
## generated meshes to a FelledTree rigid body that tips away from the
## chopper. The trunk/limbs mesh split anticipates delimbing.

@tool
class_name ConiferTree
extends StaticBody3D


const STUMP_HEIGHT: float = 0.35

@export var tree_seed: int = 0:  ## 0 = random each generate
	set(value):
		tree_seed = value
		_request_regenerate()
@export var height_range: Vector2 = Vector2(6.0, 9.5):
	set(value):
		height_range = value
		_request_regenerate()
@export var trunk_radius_range: Vector2 = Vector2(0.25, 0.4):
	set(value):
		trunk_radius_range = value
		_request_regenerate()
@export var canopy_tier_range: Vector2i = Vector2i(4, 6):
	set(value):
		canopy_tier_range = value
		_request_regenerate()
@export_range(0.0, 0.3) var lean_max: float = 0.12:
	set(value):
		lean_max = value
		_request_regenerate()
@export_range(0.0, 0.3) var color_jitter: float = 0.12:
	set(value):
		color_jitter = value
		_request_regenerate()

var _trunk_mesh: MeshInstance3D
var _limbs_mesh: MeshInstance3D
var _trunk_collision: CollisionShape3D
var _limb_parts: Array[ConiferMeshBuilder.LimbPart] = []
var _spec: ConiferMeshBuilder.ConiferSpec = null
var _felled: bool = false
var _base_rotation: Vector3 = Vector3.ZERO
var _health: HealthComponent = null
var _nudge_tween: Tween = null


func _ready() -> void:
	_health = get_node_or_null("Health") as HealthComponent
	generate()
	_base_rotation = rotation


## Rebuilds the tree from tree_seed. Public so future systems
## (regrowth, plot scattering) can reseed and regenerate in place.
func generate() -> void:
	_clear_generated()

	var rng := RandomNumberGenerator.new()
	if tree_seed == 0:
		rng.randomize()
	else:
		rng.seed = tree_seed

	var spec: ConiferMeshBuilder.ConiferSpec = ConiferMeshBuilder.make_spec(
		rng, height_range, trunk_radius_range, canopy_tier_range, lean_max, color_jitter
	)
	_spec = spec
	if not Engine.is_editor_hint() and _health != null:
		_health.setup(clampi(roundi(spec.height * 0.6), 3, 8))

	_trunk_mesh = MeshInstance3D.new()
	_trunk_mesh.name = "TrunkMesh"
	_trunk_mesh.mesh = ConiferMeshBuilder.build_trunk_mesh(rng, spec)
	add_child(_trunk_mesh)

	_limb_parts = ConiferMeshBuilder.build_limb_parts(rng, spec)
	_limbs_mesh = MeshInstance3D.new()
	_limbs_mesh.name = "LimbsMesh"
	_limbs_mesh.mesh = ConiferMeshBuilder.merge_limb_parts(_limb_parts)
	add_child(_limbs_mesh)

	var shape := CylinderShape3D.new()
	shape.height = spec.height * 0.95
	shape.radius = spec.base_radius * 0.9
	_trunk_collision = CollisionShape3D.new()
	_trunk_collision.name = "TrunkCollision"
	_trunk_collision.shape = shape
	_trunk_collision.position = Vector3(0.0, shape.height * 0.5, 0.0)
	add_child(_trunk_collision)


## Called by the axe. Chops wear the tree down; the killing chop tips
## the tree away from the chopper as a FelledTree rigid body.
func receive_chop(damage: float, _point: Vector3, normal: Vector3) -> void:
	if Engine.is_editor_hint() or _felled or _health == null:
		return
	if not _position_owned():
		EventBus.notification_requested.emit("This isn't your land yet — see the cabin catalog")
		return
	var away: Vector3 = Vector3(-normal.x, 0.0, -normal.z)
	var fall_dir: Vector3
	if away.length_squared() > 0.001:
		fall_dir = away.normalized()
	else:
		fall_dir = -global_basis.z
	_health.take_damage(maxi(roundi(damage), 1))
	if _health.is_alive():
		_chop_nudge(fall_dir)
	else:
		_felled = true
		_fell(fall_dir)


## Chops only land on owned plots; without a ForestManager (tests,
## isolated scenes) everything is fair game.
func _position_owned() -> bool:
	var manager: Node = get_tree().get_first_node_in_group("forest_manager")
	if manager == null:
		return true
	return bool(manager.call("is_position_owned", global_position))


## Small rock in the fall direction so a chop reads without sfx yet.
func _chop_nudge(dir: Vector3) -> void:
	if _nudge_tween != null and _nudge_tween.is_valid():
		_nudge_tween.kill()
	var tip: Vector3 = Vector3.UP.cross(dir) * 0.02
	_nudge_tween = create_tween()
	_nudge_tween.tween_property(self, "rotation", _base_rotation + tip, 0.05) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_nudge_tween.tween_property(self, "rotation", _base_rotation, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Hands the generated meshes and collision to a new FelledTree rigid
## body tipping toward fall_dir, leaves a stump behind, emits
## EventBus.tree_felled, and frees the standing tree.
func _fell(fall_dir: Vector3) -> void:
	if _nudge_tween != null and _nudge_tween.is_valid():
		_nudge_tween.kill()
	_spawn_stump()
	var felled: FelledTree = FelledTree.new()
	felled.name = "FelledTree"
	felled.spec = _spec
	# Trunk and collision move over; the baked limbs mesh stays behind
	# (freed with this node) and is replaced by per-part instances the
	# felled tree can bend and shed individually.
	for node: Node in [_trunk_mesh, _trunk_collision]:
		if is_instance_valid(node):
			remove_child(node)
			felled.add_child(node)
	for i in _limb_parts.size():
		var part: ConiferMeshBuilder.LimbPart = _limb_parts[i]
		var limb: MeshInstance3D = MeshInstance3D.new()
		limb.name = "Limb%d" % i
		limb.mesh = part.mesh
		limb.transform = part.transform
		limb.set_meta("part_size", part.size)
		limb.set_meta("part_mass", part.mass)
		limb.set_meta("foliage", part.foliage)
		felled.add_child(limb)
	_trunk_mesh = null
	_limbs_mesh = null
	_trunk_collision = null
	_limb_parts = []
	get_parent().add_child(felled)
	# The felled trunk starts seated on the stump's cut.
	felled.global_transform = global_transform.translated_local(Vector3(0.0, STUMP_HEIGHT, 0.0))
	felled.fall_axis = Vector3.UP.cross(fall_dir).normalized()
	Fx.wood_chips(felled, felled.global_position, (fall_dir + Vector3.UP).normalized())
	EventBus.tree_felled.emit(felled)
	queue_free()


## Static stump prop left at the fell site.
func _spawn_stump() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var stump: StaticBody3D = StaticBody3D.new()
	stump.name = "Stump"
	stump.add_to_group("stumps")
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = ConiferMeshBuilder.build_stump_mesh(rng, _spec, STUMP_HEIGHT)
	stump.add_child(mesh)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = _spec.base_radius
	shape.height = STUMP_HEIGHT
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, STUMP_HEIGHT * 0.5, 0.0)
	stump.add_child(collision)
	get_parent().add_child(stump)
	stump.global_transform = global_transform


func _request_regenerate() -> void:
	if is_node_ready():
		generate()


func _clear_generated() -> void:
	for node: Node in [_trunk_mesh, _limbs_mesh, _trunk_collision]:
		if is_instance_valid(node):
			node.queue_free()
	_trunk_mesh = null
	_limbs_mesh = null
	_trunk_collision = null
