class_name PourStream
extends MeshInstance3D

## A thin stream of liquid drawn from a point on `source` to a target point or node.
## Visible only while `flow_check` returns true (or always, if no check is set).

const STREAM_SHADER := preload("res://assets/shaders/pour_stream.gdshader")

var source: Node3D = null
var source_offset := Vector3.ZERO
var target_point := Vector3.ZERO
var target_node: Node3D = null
var target_offset := Vector3.ZERO
var flow_check: Callable = Callable()
## Optional world offset added to the landing point each frame (aimed pours).
var aim: Callable = Callable()
var radius := 0.003

func _init(color: Color = Color(0.82, 0.9, 0.95, 0.75), stream_radius: float = 0.0045) -> void:
	radius = stream_radius
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 6
	cylinder.rings = 4
	mesh = cylinder
	var mat := ShaderMaterial.new()
	mat.shader = STREAM_SHADER
	mat.set_shader_parameter("stream_color", color)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	visible = false

func _process(_delta: float) -> void:
	if source == null or not is_instance_valid(source):
		queue_free()
		return
	var flowing := true
	if flow_check.is_valid():
		flowing = bool(flow_check.call())
	var a := source.to_global(source_offset)
	var b := target_point
	if target_node and is_instance_valid(target_node):
		b = target_node.global_position + target_offset
	if aim.is_valid():
		b += aim.call()
	var axis := b - a
	if not flowing or axis.length() < 0.005:
		visible = false
		return
	visible = true
	var side := Vector3.RIGHT
	if absf(axis.normalized().dot(Vector3.RIGHT)) > 0.9:
		side = Vector3.FORWARD
	var x_axis := axis.cross(side).normalized() * radius
	var z_axis := x_axis.cross(axis).normalized() * radius
	global_transform = Transform3D(Basis(x_axis, axis, z_axis), (a + b) * 0.5)
