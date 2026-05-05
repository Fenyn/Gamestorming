extends Node3D

@export var node_data: NodeData

var _label: Label3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _connected: bool = false
var _pulse_time: float = 0.0
var _building_height: float = 1.0


func _ready() -> void:
	if node_data == null:
		return
	position = node_data.position
	_create_visual()
	_create_label()
	_create_connection_ring()
	EventBus.node_connected.connect(_on_node_connected)
	EventBus.network_reset.connect(_on_network_reset)
	_check_connected()


func _process(delta: float) -> void:
	if _connected or _ring == null:
		return
	_pulse_time += delta * 2.0
	var pulse: float = (sin(_pulse_time) + 1.0) * 0.5
	_ring_mat.albedo_color.a = lerpf(0.2, 0.7, pulse)


func _create_visual() -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()

	match node_data.type:
		NodeData.NodeType.MINE:
			box.size = Vector3(1.2, 1.0, 1.2)
			mat.albedo_color = Color(0.5, 0.35, 0.2)
		NodeData.NodeType.FARM:
			box.size = Vector3(1.4, 0.6, 1.4)
			mat.albedo_color = Color(0.3, 0.7, 0.2)
		NodeData.NodeType.FACTORY:
			box.size = Vector3(1.5, 1.4, 1.0)
			mat.albedo_color = Color(0.6, 0.6, 0.65)
		NodeData.NodeType.TOWN:
			box.size = Vector3(1.0, 1.2, 1.0)
			mat.albedo_color = Color(0.8, 0.6, 0.3)
		NodeData.NodeType.PORT:
			box.size = Vector3(1.6, 0.8, 1.2)
			mat.albedo_color = Color(0.2, 0.4, 0.8)

	box.material = mat
	mesh_instance.mesh = box
	_building_height = box.size.y
	mesh_instance.position.y = _building_height / 2.0
	add_child(mesh_instance)


func _create_label() -> void:
	_label = Label3D.new()
	_label.text = node_data.display_name
	_label.font_size = 48
	_label.position.y = _building_height + 0.6
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	add_child(_label)


func _create_connection_ring() -> void:
	_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 1.5
	torus.outer_radius = 1.8
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Color(1.0, 0.8, 0.2, 0.5)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = _ring_mat
	_ring.mesh = torus
	_ring.position.y = 0.05
	add_child(_ring)


func _check_connected() -> void:
	var adj: Array = NetworkManager.adjacency.get(node_data.id, []) as Array
	_connected = adj.size() > 0
	if _ring != null:
		_ring.visible = not _connected


func _on_node_connected(node_id: String) -> void:
	if node_id == node_data.id:
		_connected = true
		if _ring != null:
			var tween: Tween = create_tween()
			tween.tween_property(_ring_mat, "albedo_color:a", 0.0, 0.5)
			tween.tween_callback(func() -> void: _ring.visible = false)


func _on_network_reset() -> void:
	_connected = false
	if _ring != null:
		_ring_mat.albedo_color.a = 0.5
		_ring.visible = true
		_pulse_time = 0.0
