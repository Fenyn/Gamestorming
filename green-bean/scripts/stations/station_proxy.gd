extends StaticBody3D
## Extra clickable area for a station, e.g. the steamer's spare-pitcher mat.
## Items placed here go to the parent station's method named in receive_method.
## It has no interact(), so empty-handed players get no prompt here.

@export var receive_method: StringName = &"receive_item"

func receive_item(item: Node3D) -> bool:
	var station := get_parent()
	if station and station.has_method(receive_method):
		return station.call(receive_method, item)
	return false

