class_name ModuleCard
extends PanelContainer

const SOCKET_SLOT_SCENE: String = "res://scenes/combat/socket_slot.tscn"

var module_data: ModuleData
var module_index: int = 0
var _sockets: Array[SocketSlot] = []
var _socket_scene: PackedScene
var _fires_this_turn: int = 0
var _exhausted: bool = false

@onready var _name_label: Label = %ModuleName
@onready var _effect_label: Label = %EffectLabel
@onready var _socket_row: HBoxContainer = %SocketRow


func setup(data: ModuleData, idx: int) -> void:
	module_data = data
	module_index = idx


func _ready() -> void:
	if not module_data:
		return

	_socket_scene = load(SOCKET_SLOT_SCENE) as PackedScene
	_name_label.text = module_data.display_name
	_effect_label.text = module_data.description

	add_theme_stylebox_override("panel", ThemeBuilder.create_flat_style(
		ThemeBuilder.BG_MODULE, ThemeBuilder.BORDER, 1, 3, 6
	))

	for i: int in module_data.socket_requirements.size():
		var slot: SocketSlot = _socket_scene.instantiate() as SocketSlot
		slot.setup(module_data.socket_requirements[i], i, self)
		_socket_row.add_child(slot)
		slot.die_accepted.connect(_on_socket_filled)
		_sockets.append(slot)


func get_socket(index: int) -> SocketSlot:
	if index >= 0 and index < _sockets.size():
		return _sockets[index]
	return null


func are_all_filled() -> bool:
	for s: SocketSlot in _sockets:
		if not s.is_filled():
			return false
	return true


func fire() -> void:
	var pip_total: int = 0
	for s: SocketSlot in _sockets:
		pip_total += s.filled_value

	var effect_value: int = module_data.base_value + int(module_data.pip_scaling * pip_total)

	for s: SocketSlot in _sockets:
		s.eject()

	_fires_this_turn += 1
	if _fires_this_turn >= module_data.fires_per_turn:
		_set_exhausted(true)

	EventBus.module_fired.emit(
		module_index,
		module_data.effect_type,
		effect_value,
		pip_total,
	)

	_flash_fire()


func reset_turn() -> void:
	_fires_this_turn = 0
	_set_exhausted(false)


func is_exhausted() -> bool:
	return _exhausted


func _set_exhausted(value: bool) -> void:
	_exhausted = value
	modulate = Color(0.4, 0.4, 0.5) if _exhausted else Color.WHITE
	for s: SocketSlot in _sockets:
		s.set_locked(_exhausted)


func clear_all_sockets() -> Array[Dictionary]:
	var ejected: Array[Dictionary] = []
	for s: SocketSlot in _sockets:
		if s.is_filled():
			ejected.append(s.eject())
	return ejected


func _on_socket_filled(_socket_index: int, cell_index: int, _face_value: int) -> void:
	EventBus.die_socketed.emit(cell_index, module_index, _socket_index)
	if are_all_filled():
		if _validate_sum():
			fire()
		else:
			clear_all_sockets()


func _validate_sum() -> bool:
	for s: SocketSlot in _sockets:
		if s.requirement and s.requirement.type == SocketRequirement.Type.SUM:
			var total: int = 0
			for other: SocketSlot in _sockets:
				total += other.filled_value
			return total == s.requirement.sum_target
	return true


func _flash_fire() -> void:
	var end_color: Color = Color(0.4, 0.4, 0.5) if _exhausted else Color.WHITE
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 1.8, 2.0), 0.1)
	tween.tween_property(self, "modulate", end_color, 0.2)
