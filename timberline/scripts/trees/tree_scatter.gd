## Scatters procedural conifers over a rectangular area, leaving a
## circular clearing at the node's origin (the cabin site) and keeping
## a minimum spacing between trees. Placement is deterministic from
## scatter_seed.
##
## Tool script: the forest is visible in the editor and any export
## change rebuilds it. Spawned trees are ownerless, so saving a scene
## never persists them.

@tool
class_name TreeScatter
extends Node3D


const MAX_ATTEMPTS_PER_TREE := 40

@export var tree_scene: PackedScene:
	set(value):
		tree_scene = value
		_request_regenerate()
@export var scatter_seed: int = 1:
	set(value):
		scatter_seed = value
		_request_regenerate()
@export_range(0, 500) var tree_count: int = 110:
	set(value):
		tree_count = value
		_request_regenerate()
@export var area_half_extents: Vector2 = Vector2(38.0, 38.0):
	set(value):
		area_half_extents = value
		_request_regenerate()
@export var clearing_radius: float = 14.0:
	set(value):
		clearing_radius = value
		_request_regenerate()
@export var min_spacing: float = 2.5:
	set(value):
		min_spacing = value
		_request_regenerate()
## Trees are kept out of this Z band (the road corridor).
@export var road_z_range: Vector2 = Vector2(27.5, 32.5):
	set(value):
		road_z_range = value
		_request_regenerate()
## Trees are kept out of this X corridor south of the clearing
## (the path from the cabin to the road).
@export var path_x_range: Vector2 = Vector2(-2.5, 2.5):
	set(value):
		path_x_range = value
		_request_regenerate()
## Additional circular tree-free zones (ponds, props): x/y = XZ
## position, z = radius.
@export var extra_clearings: Array[Vector3] = []:
	set(value):
		extra_clearings = value
		_request_regenerate()

var _spawned: Array[Node3D] = []


func _ready() -> void:
	generate()


func generate() -> void:
	_clear_spawned()
	if tree_scene == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	var placed := PackedVector2Array()
	var attempts_left := tree_count * MAX_ATTEMPTS_PER_TREE
	while placed.size() < tree_count and attempts_left > 0:
		attempts_left -= 1
		var pos := Vector2(
			rng.randf_range(-area_half_extents.x, area_half_extents.x),
			rng.randf_range(-area_half_extents.y, area_half_extents.y)
		)
		if pos.length() < clearing_radius:
			continue
		if pos.y > road_z_range.x and pos.y < road_z_range.y:
			continue
		if pos.y > 0.0 and pos.x > path_x_range.x and pos.x < path_x_range.y:
			continue
		if _in_extra_clearing(pos):
			continue
		if not _is_clear(placed, pos):
			continue
		placed.append(pos)
		_spawn_tree(rng, pos)

	if placed.size() < tree_count:
		push_warning("TreeScatter placed %d of %d trees; enlarge the area or reduce min_spacing" % [placed.size(), tree_count])


func _in_extra_clearing(pos: Vector2) -> bool:
	for clearing in extra_clearings:
		if pos.distance_to(Vector2(clearing.x, clearing.y)) < clearing.z:
			return true
	return false


func _is_clear(placed: PackedVector2Array, pos: Vector2) -> bool:
	var min_sq := min_spacing * min_spacing
	for other in placed:
		if pos.distance_squared_to(other) < min_sq:
			return false
	return true


func _spawn_tree(rng: RandomNumberGenerator, pos: Vector2) -> void:
	var tree := tree_scene.instantiate() as ConiferTree
	if tree == null:
		push_warning("TreeScatter: tree_scene is not a ConiferTree scene")
		return
	tree.tree_seed = rng.randi_range(1, 1 << 30)
	tree.position = Vector3(pos.x, 0.0, pos.y)
	tree.rotation.y = rng.randf_range(0.0, TAU)
	add_child(tree)
	_spawned.append(tree)


func _request_regenerate() -> void:
	if is_node_ready():
		generate()


func _clear_spawned() -> void:
	for tree in _spawned:
		if is_instance_valid(tree):
			tree.queue_free()
	_spawned.clear()
