extends StaticBody3D

@export var firewood_scene: PackedScene = null
@export var firewood_per_log: int = 2

var _has_log := false


func receive_item(item: Node3D) -> bool:
	if _has_log:
		return false
	if not item.is_in_group("carriable"):
		return false
	if not item.has_meta("is_log"):
		if item.get("item_id") != "log":
			return false

	_has_log = true
	item.queue_free()
	_split()
	return true


func _split() -> void:
	_has_log = false

	if firewood_scene:
		for i: int in firewood_per_log:
			var fw: Node3D = firewood_scene.instantiate()
			get_parent().add_child(fw)
			var offset := Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))
			fw.global_position = global_position + offset
