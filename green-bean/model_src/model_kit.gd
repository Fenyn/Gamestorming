class_name ModelKit
extends RefCounted

## Helpers for building low-poly props from primitive meshes. Colours are sRGB in
## the Kenney palette so custom props match the Kenney furniture.

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

static func unique_name(parent: Node, base: String) -> String:
	if not parent.has_node(NodePath(base)):
		return base
	var i := 2
	while parent.has_node(NodePath("%s%d" % [base, i])):
		i += 1
	return "%s%d" % [base, i]

static func group(parent: Node3D, name: String) -> Node3D:
	var g := Node3D.new()
	g.name = unique_name(parent, name)
	parent.add_child(g)
	return g

static func box(parent: Node3D, name: String, size: Vector3, pos: Vector3, material: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, material, pos, rot_deg, name)

## Cylinder along Y; unequal radii make a cone.
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

static func torus(parent: Node3D, name: String, inner_radius: float, outer_radius: float, pos: Vector3, material: Material, rot_deg := Vector3.ZERO, rings := 16) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner_radius
	m.outer_radius = outer_radius
	m.rings = rings
	m.ring_segments = 8
	return _add(parent, m, material, pos, rot_deg, name)

## Surface of revolution around Y from (radius, y) points. Trace the outside
## upward and the inside downward: faces are single-sided and wound for that,
## and double-sided thin walls z-fight. deform(point, angle) -> point is optional.
static func lathe(parent: Node3D, name: String, profile: PackedVector2Array, pos: Vector3, material: Material, sides := 24, deform := Callable()) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i in range(sides):
		var angle := TAU * float(i) / float(sides)
		var ring := PackedVector3Array()
		for p in profile:
			var v := Vector3(sin(angle) * p.x, p.y, cos(angle) * p.x)
			if deform.is_valid():
				v = deform.call(v, angle)
			ring.append(v)
		rings.append(ring)
	# Reuse ring 0 so the seam welds and leaves no shading line.
	rings.append(rings[0])
	for i in range(sides):
		var a := rings[i]
		var b := rings[i + 1]
		for j in range(profile.size() - 1):
			# Wound so a profile traced upward on the outside faces outward.
			st.add_vertex(a[j]); st.add_vertex(b[j + 1]); st.add_vertex(b[j])
			st.add_vertex(a[j]); st.add_vertex(a[j + 1]); st.add_vertex(b[j + 1])
	st.index()
	st.generate_normals()
	return _add(parent, st.commit(), material, pos, Vector3.ZERO, name)

## Oval tube along a path (half_width along side_axis). The path must never run
## parallel to side_axis.
static func sweep(parent: Node3D, name: String, path: PackedVector3Array, half_width: float, half_depth: float, material: Material, side_axis := Vector3.RIGHT, sides := 10, pos := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i in range(path.size()):
		var tangent := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var normal := tangent.cross(side_axis).normalized()
		var ring := PackedVector3Array()
		for k in range(sides + 1):
			var a := TAU * float(k) / float(sides)
			ring.append(path[i] + side_axis * cos(a) * half_width + normal * sin(a) * half_depth)
		rings.append(ring)
	for i in range(path.size() - 1):
		for k in range(sides):
			var a := rings[i]
			var b := rings[i + 1]
			st.add_vertex(a[k]); st.add_vertex(a[k + 1]); st.add_vertex(b[k + 1])
			st.add_vertex(a[k]); st.add_vertex(b[k + 1]); st.add_vertex(b[k])
	st.index()
	st.generate_normals()
	return _add(parent, st.commit(), material, pos, Vector3.ZERO, name)

## Box with its four vertical edges rounded.
static func rounded_box(parent: Node3D, name: String, size: Vector3, center: Vector3, radius: float, material: Material) -> void:
	box(parent, name, Vector3(size.x - radius * 2.0, size.y, size.z), center, material)
	box(parent, name + "Sides", Vector3(size.x, size.y, size.z - radius * 2.0), center, material)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := center + Vector3((size.x * 0.5 - radius) * float(sx), 0, (size.z * 0.5 - radius) * float(sz))
			cyl(parent, name + "Edge", radius, radius, size.y, p, material, 10)

static func marker(parent: Node3D, name: String, pos: Vector3, rot_deg := Vector3.ZERO) -> Marker3D:
	var m := Marker3D.new()
	m.name = name
	m.position = pos
	m.rotation_degrees = rot_deg
	m.gizmo_extents = 0.03
	parent.add_child(m)
	return m

## Saves the tree as a .tscn with meshes and materials inline, so every part is
## editable in the editor.
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
