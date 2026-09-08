class_name ForestManager
extends Node
## Forest plots and regrowth. Lives in main.tscn, group "forest_manager".
##
## Plots: PLOTS carves the world into rects; the home plot is owned
## from the start, the rest map to catalog upgrades. ConiferTree asks
## is_position_owned() before accepting chops.
##
## Regrowth: every felled tree leaves a site that sprouts a sapling
## after regrow_delay; the sapling scales up over grow_time and is then
## swapped for a fresh random ConiferTree (the old stump is cleared),
## so owned land replants itself indefinitely.

## Plot rects in world XZ. id "" is owned from the start; other ids
## must match a GameManager.CATALOG upgrade.
const PLOTS: Array[Dictionary] = [
	{"id": "", "rect": Rect2(-20.0, -20.0, 40.0, 72.0)},
	{"id": "plot_west", "rect": Rect2(-52.0, -52.0, 32.0, 104.0)},
	{"id": "plot_east", "rect": Rect2(20.0, -52.0, 32.0, 104.0)},
	{"id": "plot_north", "rect": Rect2(-20.0, -52.0, 40.0, 32.0)},
]

## Meters between boundary stakes on locked plot borders.
const STAKE_SPACING: float = 3.5

@export var tree_scene: PackedScene
## Seconds from felling until a sapling sprouts at the site.
@export var regrow_delay: float = 45.0
## Seconds the sapling takes to grow into a full tree.
@export var grow_time: float = 90.0

static var _sapling_trunk: CylinderMesh = null
static var _sapling_tier: CylinderMesh = null
static var _stake_post: BoxMesh = null
static var _stake_cap: BoxMesh = null

## Border stake nodes per locked plot id, freed on purchase.
var _borders: Dictionary[String, Array] = {}


func _ready() -> void:
	add_to_group("forest_manager")
	EventBus.tree_felled.connect(_on_tree_felled)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	_build_borders()


func _on_upgrade_purchased(upgrade_id: String) -> void:
	if _borders.has(upgrade_id):
		for node: Node in _borders[upgrade_id]:
			node.queue_free()
		_borders.erase(upgrade_id)


## Red-capped survey stakes along the perimeter of every plot the
## player doesn't own yet. Purchased plots (including on a loaded save)
## get no stakes; buying one clears its line.
func _build_borders() -> void:
	if _stake_post == null:
		_stake_post = BoxMesh.new()
		_stake_post.size = Vector3(0.14, 1.1, 0.14)
		var wood: StandardMaterial3D = StandardMaterial3D.new()
		wood.albedo_color = Color(0.32, 0.24, 0.16)
		wood.roughness = 1.0
		_stake_post.material = wood
		_stake_cap = BoxMesh.new()
		_stake_cap.size = Vector3(0.2, 0.12, 0.2)
		var paint: StandardMaterial3D = StandardMaterial3D.new()
		paint.albedo_color = Color(0.78, 0.22, 0.16)
		paint.roughness = 0.8
		_stake_cap.material = paint
	for plot in PLOTS:
		var plot_id: String = String(plot["id"])
		if plot_id.is_empty() or GameManager.has_upgrade(plot_id):
			continue
		var points: PackedVector2Array = _perimeter_points(plot["rect"], STAKE_SPACING)
		var posts: MultiMeshInstance3D = _stake_multimesh(_stake_post, points, 0.55)
		posts.name = plot_id + "BorderPosts"
		var caps: MultiMeshInstance3D = _stake_multimesh(_stake_cap, points, 1.16)
		caps.name = plot_id + "BorderCaps"
		add_child(posts)
		add_child(caps)
		_borders[plot_id] = [posts, caps]


func _stake_multimesh(
	mesh: Mesh, points: PackedVector2Array, height: float
) -> MultiMeshInstance3D:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = points.size()
	for i in points.size():
		multimesh.set_instance_transform(
			i, Transform3D(Basis.IDENTITY, Vector3(points[i].x, height, points[i].y)))
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	return instance


func _perimeter_points(rect: Rect2, spacing: float) -> PackedVector2Array:
	var corners: Array[Vector2] = [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.end,
		rect.position + Vector2(0.0, rect.size.y),
	]
	var points: PackedVector2Array = PackedVector2Array()
	for i in 4:
		var from: Vector2 = corners[i]
		var to: Vector2 = corners[(i + 1) % 4]
		var count: int = maxi(1, ceili(from.distance_to(to) / spacing))
		for j in count:
			points.append(from.lerp(to, float(j) / count))
	return points


func is_position_owned(pos: Vector3) -> bool:
	var p: Vector2 = Vector2(pos.x, pos.z)
	for plot in PLOTS:
		var rect: Rect2 = plot["rect"]
		if rect.has_point(p):
			var plot_id: String = String(plot["id"])
			return plot_id.is_empty() or GameManager.has_upgrade(plot_id)
	return false


func _on_tree_felled(tree: Node3D) -> void:
	var site: Vector3 = tree.global_position
	site.y = 0.0
	get_tree().create_timer(regrow_delay).timeout.connect(_sprout.bind(site))


func _sprout(site: Vector3) -> void:
	var sapling: Node3D = _build_sapling()
	get_parent().add_child(sapling)
	sapling.global_position = site
	sapling.scale = Vector3.ONE * 0.15
	var tween: Tween = sapling.create_tween()
	tween.tween_property(sapling, "scale", Vector3.ONE, grow_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_mature.bind(sapling, site))


## Full-grown sapling swaps into a real tree; the fell-site stump goes.
func _mature(sapling: Node3D, site: Vector3) -> void:
	sapling.queue_free()
	for stump in get_tree().get_nodes_in_group("stumps"):
		if stump is Node3D and (stump as Node3D).global_position.distance_to(site) < 1.2:
			stump.queue_free()
	var tree: ConiferTree = tree_scene.instantiate() as ConiferTree
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	tree.tree_seed = rng.randi_range(1, 1 << 30)
	tree.rotation.y = rng.randf_range(0.0, TAU)
	get_parent().add_child(tree)
	tree.global_position = site
	Fx.dust_puff(tree, site + Vector3.UP * 0.4, 0.8)


## Simple young-tree prop: a thin trunk and two green tiers. Purely
## visual; it becomes choppable only once it matures into a real tree.
func _build_sapling() -> Node3D:
	if _sapling_trunk == null:
		_sapling_trunk = CylinderMesh.new()
		_sapling_trunk.top_radius = 0.05
		_sapling_trunk.bottom_radius = 0.09
		_sapling_trunk.height = 1.1
		var bark: StandardMaterial3D = StandardMaterial3D.new()
		bark.albedo_color = Color(0.42, 0.31, 0.2)
		bark.roughness = 1.0
		_sapling_trunk.material = bark
		_sapling_tier = CylinderMesh.new()
		_sapling_tier.top_radius = 0.0
		_sapling_tier.bottom_radius = 0.55
		_sapling_tier.height = 1.0
		_sapling_tier.radial_segments = 7
		var needles: StandardMaterial3D = StandardMaterial3D.new()
		needles.albedo_color = Color(0.2, 0.42, 0.22)
		needles.roughness = 1.0
		_sapling_tier.material = needles
	var sapling: Node3D = Node3D.new()
	sapling.name = "Sapling"
	var trunk: MeshInstance3D = MeshInstance3D.new()
	trunk.mesh = _sapling_trunk
	trunk.position = Vector3(0.0, 0.55, 0.0)
	sapling.add_child(trunk)
	var lower: MeshInstance3D = MeshInstance3D.new()
	lower.mesh = _sapling_tier
	lower.position = Vector3(0.0, 1.1, 0.0)
	sapling.add_child(lower)
	var upper: MeshInstance3D = MeshInstance3D.new()
	upper.mesh = _sapling_tier
	upper.position = Vector3(0.0, 1.7, 0.0)
	upper.scale = Vector3.ONE * 0.7
	sapling.add_child(upper)
	return sapling
