class_name Kettle
extends RigidBody3D

const MAX_WATER := 1.0
const BLOOM_COST := 0.1
const SHOT_PRESS_COST := 0.3
const POUR_OVER_COST := 0.4
const AMERICANO_COST := 0.3

const MODEL := preload("res://scenes/props/gooseneck_kettle.tscn")

## Mouth of the spout in the kettle's local space, from the model's SpoutTip.
var spout_tip := Vector3(-0.17, 0.066, 0)
var water_level := 0.0
var _lid: Node3D = null
var _lid_rest := Transform3D.IDENTITY
var _lid_parked := Transform3D.IDENTITY
var _lid_tween: Tween = null
var has_water: bool:
	get: return water_level > 0.01

func _ready() -> void:
	add_to_group("carriable")
	add_to_group("kettle")
	freeze = true

	var model: Node3D = MODEL.instantiate()
	model.name = "Model"
	add_child(model)
	var col := model.get_node_or_null("Collision") as CollisionShape3D
	if col:
		var xform := col.transform
		model.remove_child(col)
		col.owner = null
		add_child(col)
		col.transform = model.transform * xform
	else:
		col = CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.072
		shape.height = 0.12
		col.shape = shape
		add_child(col)
	var tip := model.get_node_or_null("SpoutTip") as Node3D
	if tip:
		spout_tip = model.transform * tip.position
	_lid = model.get_node_or_null("Lid") as Node3D
	if _lid:
		_lid_rest = _lid.transform
		_lid_parked = _lid_rest.translated(Vector3(0, 0.04, 0))
	var parked := model.get_node_or_null("LidParked") as Node3D
	if parked:
		_lid_parked = parked.transform

func fill() -> void:
	water_level = MAX_WATER

func use_water(amount: float) -> bool:
	if water_level < amount - 0.001:
		return false
	water_level = maxf(water_level - amount, 0.0)
	return true

func empty() -> void:
	water_level = 0.0

func get_level_percent() -> float:
	return water_level / MAX_WATER * 100.0

## Moves the lid to its clip (LidParked) and back, lifting it clear of the opening first.
func set_lid_open(open: bool) -> void:
	if _lid == null:
		return
	if _lid_tween and _lid_tween.is_valid():
		_lid_tween.kill()
	var lifted := _lid_rest.translated(Vector3(0, 0.03, 0))
	_lid_tween = create_tween()
	if open:
		_lid_tween.tween_property(_lid, "transform", lifted, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_lid_tween.tween_property(_lid, "transform", _lid_parked, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_lid_tween.tween_property(_lid, "transform", lifted, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_lid_tween.tween_property(_lid, "transform", _lid_rest, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
