class_name SpellPiece
extends Node3D

var instance: SpellInstance
var _mesh: MeshInstance3D
var _name_label: Label3D
var _pos_label: Label3D

func setup(spell_instance: SpellInstance) -> void:
	instance = spell_instance
	_build_visuals()
	update_display()

func update_display() -> void:
	if instance == null:
		return
	_pos_label.text = str(instance.current_position)

func _build_visuals() -> void:
	_mesh = MeshInstance3D.new()
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.6, 0.15, 0.6)
	_mesh.mesh = prism
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.25, 0.7)
	_mesh.set_surface_override_material(0, mat)
	_mesh.position.y = 0.1
	add_child(_mesh)

	_name_label = Label3D.new()
	_name_label.text = instance.data.display_name
	_name_label.font_size = 28
	_name_label.position = Vector3(0, 0.4, 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_name_label)

	_pos_label = Label3D.new()
	_pos_label.font_size = 40
	_pos_label.position = Vector3(0, 0.15, 0.35)
	_pos_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_pos_label.modulate = Color.YELLOW
	add_child(_pos_label)
