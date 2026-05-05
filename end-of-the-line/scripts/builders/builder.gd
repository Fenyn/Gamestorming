extends Node3D

var builder_data: BuilderTypeData
var builder_id: int = -1
var source_node_id: String = ""
var target_node_id: String = ""

var _progress: float = 0.0
var _total_distance: float = 0.0
var _source_pos: Vector3 = Vector3.ZERO
var _target_pos: Vector3 = Vector3.ZERO
var _building: bool = false
var _finished: bool = false
var _guide_line: MeshInstance3D = null
var _progress_line: MeshInstance3D = null
var _progress_mat: StandardMaterial3D = null


func _ready() -> void:
	_source_pos = NetworkManager.get_node_position(source_node_id)
	_target_pos = NetworkManager.get_node_position(target_node_id)
	_total_distance = _source_pos.distance_to(_target_pos)
	_building = true
	position = _source_pos
	_create_guide_line()
	_create_progress_line()


func _process(delta: float) -> void:
	if not _building or _finished:
		return

	var speed: float = builder_data.build_speed
	_progress += (speed * delta) / _total_distance

	if _progress >= 1.0:
		_progress = 1.0
		_finish_building()
	else:
		position = _source_pos.lerp(_target_pos, _progress)
		_update_progress_line()


func _finish_building() -> void:
	_finished = true
	_building = false
	position = _target_pos

	NetworkManager.add_edge(source_node_id, target_node_id)
	EventBus.builder_finished.emit(builder_id, target_node_id)

	_cleanup_lines()

	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.5)
	tween.tween_callback(queue_free)


func _cleanup_lines() -> void:
	if _guide_line != null and is_instance_valid(_guide_line):
		_guide_line.queue_free()
		_guide_line = null
	if _progress_line != null and is_instance_valid(_progress_line):
		_progress_line.queue_free()
		_progress_line = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_lines()


func _create_guide_line() -> void:
	_guide_line = MeshInstance3D.new()
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var segments: int = 8
	for i: int in range(segments):
		var t0: float = float(i * 2) / float(segments * 2)
		var t1: float = float(i * 2 + 1) / float(segments * 2)
		var p0: Vector3 = _source_pos.lerp(_target_pos, t0)
		var p1: Vector3 = _source_pos.lerp(_target_pos, t1)
		p0.y = 0.1
		p1.y = 0.1
		mesh.surface_add_vertex(p0)
		mesh.surface_add_vertex(p1)
	mesh.surface_end()

	_guide_line.mesh = mesh
	get_parent().add_child.call_deferred(_guide_line)


func _create_progress_line() -> void:
	_progress_line = MeshInstance3D.new()
	_progress_line.position = Vector3.ZERO
	_progress_mat = StandardMaterial3D.new()
	_progress_mat.albedo_color = Color(0.9, 0.6, 0.1, 0.8)
	_progress_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_progress_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	get_parent().add_child.call_deferred(_progress_line)


func _update_progress_line() -> void:
	if _progress_line == null:
		return

	var mesh: ImmediateMesh = ImmediateMesh.new()
	var from: Vector3 = _source_pos
	var to: Vector3 = _source_pos.lerp(_target_pos, _progress)
	from.y = 0.15
	to.y = 0.15

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _progress_mat)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()

	_progress_line.mesh = mesh
