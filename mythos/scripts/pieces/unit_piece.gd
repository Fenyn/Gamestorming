class_name UnitPiece
extends Node3D

var instance: UnitInstance
var _mesh: MeshInstance3D
var _attack_label: Label3D
var _health_label: Label3D
var _name_label: Label3D

func setup(unit_instance: UnitInstance) -> void:
	instance = unit_instance
	_build_visuals()
	update_display()

func update_display() -> void:
	if instance == null:
		return
	_attack_label.text = str(instance.get_effective_attack())
	_health_label.text = str(instance.current_health)
	if instance.current_health < instance.data.health:
		_health_label.modulate = Color.RED
	else:
		_health_label.modulate = Color.WHITE

func _build_visuals() -> void:
	_mesh = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.2
	capsule.height = 0.6
	_mesh.mesh = capsule
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _get_color_for_cost(instance.data.cost)
	_mesh.set_surface_override_material(0, mat)
	_mesh.position.y = 0.3
	add_child(_mesh)

	_name_label = Label3D.new()
	_name_label.text = instance.data.display_name
	_name_label.font_size = 32
	_name_label.position = Vector3(0, 0.8, 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_name_label)

	_attack_label = Label3D.new()
	_attack_label.font_size = 48
	_attack_label.position = Vector3(-0.25, 0.15, 0.25)
	_attack_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_attack_label.modulate = Color.YELLOW
	add_child(_attack_label)

	_health_label = Label3D.new()
	_health_label.font_size = 48
	_health_label.position = Vector3(0.25, 0.15, 0.25)
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_health_label)

func play_attack(direction: float) -> void:
	var original_pos: Vector3 = position
	var lunge_target: Vector3 = original_pos + Vector3(0, 0, direction * 0.4)
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", lunge_target, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position", original_pos, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func play_hit() -> void:
	var original_pos: Vector3 = position
	var tween: Tween = create_tween()
	tween.tween_property(_mesh, "position:x", 0.1, 0.05)
	tween.tween_property(_mesh, "position:x", -0.1, 0.05)
	tween.tween_property(_mesh, "position:x", 0.05, 0.05)
	tween.tween_property(_mesh, "position:x", 0.0, 0.05)

func play_death() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

func _get_color_for_cost(cost: int) -> Color:
	if cost <= 2:
		return Color(0.3, 0.7, 0.3)
	elif cost <= 4:
		return Color(0.3, 0.4, 0.8)
	elif cost <= 6:
		return Color(0.6, 0.3, 0.7)
	else:
		return Color(0.9, 0.7, 0.2)
