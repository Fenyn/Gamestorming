class_name SocketSlot
extends PanelContainer

signal die_accepted(socket_index: int, cell_index: int, face_value: int)

var requirement: SocketRequirement
var socket_index: int = 0
var filled_value: int = -1
var filled_cell_index: int = -1
var locked: bool = false
var _module_card: Control

@onready var _value_label: Label = %ValueLabel
@onready var _req_label: Label = %ReqLabel


func setup(req: SocketRequirement, idx: int, card: Control) -> void:
	requirement = req
	socket_index = idx
	_module_card = card


func _ready() -> void:
	custom_minimum_size = Vector2(36, 28)
	_update_display()


func is_filled() -> bool:
	return filled_value >= 0


var _is_wild: bool = false


func can_accept(value: int, is_wild: bool = false) -> bool:
	if locked or is_filled():
		return false
	if is_wild:
		return true
	if not requirement:
		return true
	return _check_requirement(value)


func set_locked(value: bool) -> void:
	locked = value


func accept_die(cell_index: int, value: int) -> void:
	filled_value = value
	filled_cell_index = cell_index
	_update_display()
	die_accepted.emit(socket_index, cell_index, value)


func eject() -> Dictionary:
	var result: Dictionary = {
		"cell_index": filled_cell_index,
		"value": filled_value,
	}
	filled_value = -1
	filled_cell_index = -1
	_update_display()
	return result


func _check_requirement(value: int) -> bool:
	match requirement.type:
		SocketRequirement.Type.ANY:
			return true
		SocketRequirement.Type.SPECIFIC:
			return value == requirement.specific_value
		SocketRequirement.Type.RANGE:
			return value >= requirement.range_min and value <= requirement.range_max
		SocketRequirement.Type.PARITY:
			return (value % 2 == 0) == requirement.parity_even
		SocketRequirement.Type.MATCH:
			var ref: SocketSlot = _module_card.get_socket(requirement.match_socket_index)
			if not ref or not ref.is_filled():
				return true
			return value == ref.filled_value
		SocketRequirement.Type.SEQUENCE:
			var ref: SocketSlot = _module_card.get_socket(requirement.sequence_ref_index)
			if not ref or not ref.is_filled():
				return true
			return value == ref.filled_value + requirement.sequence_offset
		SocketRequirement.Type.SUM:
			return true
	return false


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		_clear_highlight()
		return false
	var dict: Dictionary = data as Dictionary
	if not dict.has("face_value"):
		_clear_highlight()
		return false
	var wild: bool = dict.get("is_wild", false) as bool
	var face_value: int = dict["face_value"] as int
	var valid: bool = can_accept(face_value, wild)
	if valid:
		add_theme_stylebox_override("panel", ThemeBuilder.create_flat_style(
			ThemeBuilder.BG_SOCKET_VALID, ThemeBuilder.ACCENT_GLOW, 2, 2, 2
		))
		var card: ModuleCard = _module_card as ModuleCard
		if card:
			card.preview_with_hypothetical(socket_index, face_value)
	else:
		_clear_highlight()
	return valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dict: Dictionary = data as Dictionary
	accept_die(dict["cell_index"] as int, dict["face_value"] as int)
	_clear_highlight()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_clear_highlight()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_clear_highlight()


func _clear_highlight() -> void:
	var card: ModuleCard = _module_card as ModuleCard
	if card:
		card.clear_preview()
	_update_display()


func _update_display() -> void:
	if is_filled():
		add_theme_stylebox_override("panel", ThemeBuilder.create_flat_style(
			ThemeBuilder.BG_SOCKET_FILLED, ThemeBuilder.BORDER, 1, 2, 2
		))
		if _value_label:
			_value_label.text = str(filled_value)
			_value_label.visible = true
		if _req_label:
			_req_label.visible = false
	else:
		add_theme_stylebox_override("panel", ThemeBuilder.create_flat_style(
			ThemeBuilder.BG_SOCKET_EMPTY, ThemeBuilder.BORDER, 1, 2, 2
		))
		if _value_label:
			_value_label.visible = false
		if _req_label:
			_req_label.text = _get_req_text()
			_req_label.visible = true


func _get_req_text() -> String:
	if not requirement:
		return "?"
	match requirement.type:
		SocketRequirement.Type.ANY:
			return "*"
		SocketRequirement.Type.SPECIFIC:
			return str(requirement.specific_value)
		SocketRequirement.Type.RANGE:
			return str(requirement.range_min) + "-" + str(requirement.range_max)
		SocketRequirement.Type.PARITY:
			return "Even" if requirement.parity_even else "Odd"
		SocketRequirement.Type.MATCH:
			return "="
		SocketRequirement.Type.SEQUENCE:
			return "+1"
		SocketRequirement.Type.SUM:
			return "Σ" + str(requirement.sum_target)
	return "?"
