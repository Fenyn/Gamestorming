class_name ModelKit
extends RefCounted

## Helpers for building low-poly props from primitive meshes and exporting them
## as .glb. Colours follow the Kenney palette so custom props sit next to the
## Kenney furniture without looking out of place.

const WOOD := Color(0.896, 0.602, 0.393)
const WOOD_DARK := Color(0.678, 0.456, 0.299)
const WOOD_DARKER := Color(0.48, 0.31, 0.2)
const METAL := Color(0.741, 0.823, 0.84)
const METAL_MEDIUM := Color(0.369, 0.467, 0.467)
const METAL_DARK := Color(0.306, 0.388, 0.388)
const STEEL := Color(0.78, 0.8, 0.82)
const BLACK := Color(0.12, 0.12, 0.13)
const CREAM := Color(0.93, 0.89, 0.8)
const BEANS := Color(0.3, 0.17, 0.09)
const RED := Color(0.85, 0.3, 0.27)
const GLASS := Color(0.698, 0.827, 0.769)

static var _materials := {}

## Colours are written in sRGB like the Kenney palette.
static func mat(color: Color, metallic: float = 0.0, roughness: float = 0.85) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f" % [color.to_html(), metallic, roughness]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	_materials[key] = m
	return m

static func metal(color: Color) -> StandardMaterial3D:
	return mat(color, 0.35, 0.45)

static func _add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot_deg: Vector3, name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = unique_name(parent, name)
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

## Readable names for repeated parts: Foot, Foot2, Foot3...
static func unique_name(parent: Node, base: String) -> String:
	if not parent.has_node(NodePath(base)):
		return base
	var i := 2
	while parent.has_node(NodePath("%s%d" % [base, i])):
		i += 1
	return "%s%d" % [base, i]

## Empty node to group related parts in the scene tree.
static func group(parent: Node3D, name: String) -> Node3D:
	var g := Node3D.new()
	g.name = unique_name(parent, name)
	parent.add_child(g)
	return g

static func box(parent: Node3D, name: String, size: Vector3, pos: Vector3, material: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, material, pos, rot_deg, name)

## Cylinder along Y. Different top/bottom radii make a cone or a funnel.
static func cyl(parent: Node3D, name: String, bottom_radius: float, top_radius: float, height: float, pos: Vector3, material: Material, sides := 16, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom_radius
	m.top_radius = top_radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return _add(parent, m, material, pos, rot_deg, name)

static func sphere(parent: Node3D, name: String, radius: float, pos: Vector3, material: Material, squash := 1.0, segments := 12) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 * squash
	m.radial_segments = segments
	m.rings = maxi(segments / 2, 4)
	return _add(parent, m, material, pos, Vector3.ZERO, name)

static func torus(parent: Node3D, name: String, inner_radius: float, outer_radius: float, pos: Vector3, material: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner_radius
	m.outer_radius = outer_radius
	m.rings = 16
	m.ring_segments = 8
	return _add(parent, m, material, pos, rot_deg, name)

## Saves the node tree under root as a Godot scene (.tscn). Meshes and materials
## are stored inside the scene, so every part can be selected and edited in the
## editor (sizes, colours, positions).
static func save_scene(root: Node3D, path: String) -> Error:
	_own_children(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("ModelKit: pack failed for %s (%d)" % [path, err])
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("ModelKit: save failed for %s (%d)" % [path, err])
	return err

static func _own_children(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_own_children(child, owner_node)

## Writes the node tree under root to a binary glTF file.
static func export_glb(root: Node3D, path: String) -> Error:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err != OK:
		push_error("ModelKit: append_from_scene failed for %s (%d)" % [path, err])
		return err
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	err = doc.write_to_filesystem(state, path)
	if err != OK:
		push_error("ModelKit: write failed for %s (%d)" % [path, err])
	return err
