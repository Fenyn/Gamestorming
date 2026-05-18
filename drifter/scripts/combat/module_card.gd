class_name ModuleCard
extends PanelContainer

const SOCKET_SLOT_SCENE: String = "res://scenes/combat/socket_slot.tscn"

var module_data: ModuleData
var module_index: int = 0
var _sockets: Array[SocketSlot] = []
var _socket_scene: PackedScene
var _fires_this_turn: int = 0
var _exhausted: bool = false
var _last_fired_cell_indices: Array[int] = []

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
	_update_effect_preview()

	add_theme_stylebox_override("panel", ThemeBuilder.create_flat_style(
		ThemeBuilder.BG_MODULE, ThemeBuilder.BORDER, 1, 2, 2
	))

	for i: int in module_data.socket_requirements.size():
		var slot: SocketSlot = _socket_scene.instantiate() as SocketSlot
		slot.setup(module_data.socket_requirements[i], i, self)
		_socket_row.add_child(slot)
		slot.die_accepted.connect(_on_socket_filled)
		_sockets.append(slot)


func get_socket_count() -> int:
	return _sockets.size()


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
	var used_cell_indices: Array[int] = []
	for s: SocketSlot in _sockets:
		pip_total += s.filled_value
		if s.filled_cell_index >= 0:
			used_cell_indices.append(s.filled_cell_index)

	var effect_value: int = module_data.base_value + int(module_data.pip_scaling * pip_total)

	for s: SocketSlot in _sockets:
		s.eject()

	_fires_this_turn += 1
	if _fires_this_turn >= module_data.fires_per_turn:
		_set_exhausted(true)

	_last_fired_cell_indices = used_cell_indices
	EventBus.module_fired.emit(
		module_index,
		module_data.effect_type,
		effect_value,
		pip_total,
	)

	_flash_fire()
	_update_effect_preview()


func reset_turn() -> void:
	_fires_this_turn = 0
	_set_exhausted(false)
	_update_effect_preview()


func is_exhausted() -> bool:
	return _exhausted


func get_last_fired_cell_indices() -> Array[int]:
	return _last_fired_cell_indices


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
	_update_effect_preview()
	if are_all_filled():
		if _validate_sum():
			fire()
		else:
			clear_all_sockets()
			_update_effect_preview()


func _validate_sum() -> bool:
	for s: SocketSlot in _sockets:
		if s.requirement and s.requirement.type == SocketRequirement.Type.SUM:
			var total: int = 0
			for other: SocketSlot in _sockets:
				total += other.filled_value
			return total == s.requirement.sum_target
	return true


func preview_with_hypothetical(hypo_socket_index: int, hypo_value: int) -> void:
	if not module_data or not _effect_label:
		return

	var current_pip: int = 0
	var filled_count: int = 0
	for s: SocketSlot in _sockets:
		if s.is_filled():
			current_pip += s.filled_value
			filled_count += 1

	var current_val: int = module_data.base_value + int(module_data.pip_scaling * current_pip)
	var hypo_pip: int = current_pip + hypo_value
	var hypo_filled: int = filled_count + 1
	var hypo_val: int = module_data.base_value + int(module_data.pip_scaling * hypo_pip)
	var delta: int = hypo_val - current_val

	var effect_name: String = _get_effect_name()
	var color: Color = _get_effect_color()

	var text: String = effect_name + " " + str(hypo_val)
	if delta > 0:
		text += " (+" + str(delta) + ")"
	if hypo_filled < _sockets.size():
		text += "+"

	_effect_label.text = text
	_effect_label.add_theme_color_override("font_color", color)


func clear_preview() -> void:
	_update_effect_preview()


func _get_effect_name() -> String:
	if not module_data:
		return ""
	match module_data.effect_type:
		ModuleData.EffectType.DAMAGE: return "DMG"
		ModuleData.EffectType.SHIELD: return "SHD"
		ModuleData.EffectType.HEAL: return "HEAL"
		ModuleData.EffectType.DEBUFF_WEAK: return "WEAK"
		ModuleData.EffectType.DEBUFF_VULNERABLE: return "VULN"
		ModuleData.EffectType.BUFF_STRENGTH: return "STR"
	return ""


func _get_effect_color() -> Color:
	if not module_data:
		return ThemeBuilder.TEXT_SECONDARY
	match module_data.effect_type:
		ModuleData.EffectType.DAMAGE: return ThemeBuilder.TEXT_DAMAGE
		ModuleData.EffectType.SHIELD: return ThemeBuilder.TEXT_SHIELD
		ModuleData.EffectType.HEAL: return ThemeBuilder.TEXT_HEAL
		ModuleData.EffectType.DEBUFF_WEAK: return Color(0.7, 0.5, 0.9)
		ModuleData.EffectType.DEBUFF_VULNERABLE: return Color(0.9, 0.5, 0.7)
		ModuleData.EffectType.BUFF_STRENGTH: return Color(0.9, 0.7, 0.3)
	return ThemeBuilder.TEXT_SECONDARY


func _update_effect_preview() -> void:
	if not module_data or not _effect_label:
		return

	var pip_total: int = 0
	var filled_count: int = 0
	for s: SocketSlot in _sockets:
		if s.is_filled():
			pip_total += s.filled_value
			filled_count += 1

	var effect_name: String = _get_effect_name()
	var color: Color = _get_effect_color()

	if filled_count == 0:
		var base_text: String = str(module_data.base_value)
		if module_data.pip_scaling > 0:
			base_text += "+" + str(module_data.pip_scaling) + "xpip"
		_effect_label.text = effect_name + " " + base_text
		_effect_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
	else:
		var projected: int = module_data.base_value + int(module_data.pip_scaling * pip_total)
		_effect_label.text = effect_name + " " + str(projected)
		if filled_count < _sockets.size():
			_effect_label.text += "+"
			_effect_label.add_theme_color_override("font_color", color.lerp(ThemeBuilder.TEXT_SECONDARY, 0.4))
		else:
			_effect_label.add_theme_color_override("font_color", color)


func _flash_fire() -> void:
	var end_color: Color = Color(0.4, 0.4, 0.5) if _exhausted else Color.WHITE
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 1.8, 2.0), 0.1)
	tween.tween_property(self, "modulate", end_color, 0.2)
