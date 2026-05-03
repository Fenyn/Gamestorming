class_name BuildingPiece
extends Node3D

var instance: BuildingInstance
var _mesh: MeshInstance3D
var _health_label: Label3D
var _name_label: Label3D

func setup(building_instance: BuildingInstance) -> void:
	instance = building_instance
	_build_visuals()
	update_display()

func update_display() -> void:
	if instance == null:
		return
	_health_label.text = str(instance.current_health) + "/" + str(instance.max_health)
	if instance.current_health < instance.max_health:
		_health_label.modulate = Color.RED
	else:
		_health_label.modulate = Color.WHITE

func _build_visuals() -> void:
	_mesh = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	if instance.data.is_hq:
		box.size = Vector3(0.7, 0.5, 0.7)
	else:
		box.size = Vector3(0.5, 0.35, 0.5)
	_mesh.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _get_building_color()
	_mesh.set_surface_override_material(0, mat)
	_mesh.position.y = box.size.y * 0.5
	add_child(_mesh)

	_name_label = Label3D.new()
	_name_label.text = instance.data.display_name
	_name_label.font_size = 28
	_name_label.position = Vector3(0, 0.7, 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_name_label)

	_health_label = Label3D.new()
	_health_label.font_size = 36
	_health_label.position = Vector3(0, 0.1, 0.35)
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_health_label)

func _get_building_color() -> Color:
	if instance.data.is_hq:
		return Color(0.8, 0.6, 0.2)
	elif instance.data.resource_generation > 0:
		return Color(0.2, 0.6, 0.3)
	else:
		return Color(0.5, 0.4, 0.3)
