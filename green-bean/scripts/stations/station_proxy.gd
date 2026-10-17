extends StaticBody3D
## Extra clickable area for a station (e.g. the steamer's mat). Placed items go
## to the parent's receive_method. No interact(), so no prompt when empty-handed.

@export var receive_method: StringName = &"receive_item"

func receive_item(item: Node3D) -> bool:
	var station := get_parent()
	if station and station.has_method(receive_method):
		return station.call(receive_method, item)
	return false

