class_name UnitDead
extends State

var _unit: Unit = null


func enter(_msg: Dictionary = {}) -> void:
	_unit = owner as Unit
	_unit.mover.cancel()
	_unit.modulate = Color(0.5, 0.5, 0.5, 0.7)
	_unit.rotation_degrees = 90.0
	var ap_label: Label = _unit.get_node_or_null("%APLabel") as Label
	if ap_label:
		ap_label.visible = false
	var hp_bar: Control = _unit.get_node_or_null("%HPBar") as Control
	if hp_bar:
		hp_bar.visible = false
