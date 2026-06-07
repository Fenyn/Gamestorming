class_name HybridizerPanel
extends PanelContainer

var _hybridizer: Hybridizer = null
var _selected_a: String = ""
var _selected_b: String = ""

@onready var _crop_list: VBoxContainer = %CropList
@onready var _slot_a_label: Label = %SlotALabel
@onready var _slot_b_label: Label = %SlotBLabel
@onready var _result_label: Label = %ResultLabel
@onready var _start_button: Button = %StartButton
@onready var _clear_button: Button = %ClearButton


func _ready() -> void:
	visible = false
	_start_button.pressed.connect(_on_start)
	_clear_button.pressed.connect(_on_clear)


func set_hybridizer(hyb: Hybridizer) -> void:
	_hybridizer = hyb


func on_opened() -> void:
	_selected_a = ""
	_selected_b = ""
	_refresh()


func on_closed() -> void:
	_hybridizer = null


func _refresh() -> void:
	_rebuild_crop_list()
	_update_slots()


func _rebuild_crop_list() -> void:
	for child: Node in _crop_list.get_children():
		child.queue_free()

	var harvested: Dictionary = GameState.get_all_harvested()
	if harvested.is_empty():
		var label: Label = Label.new()
		label.text = "No harvested crops"
		label.add_theme_font_size_override("font_size", 11)
		label.modulate = Color(0.5, 0.5, 0.5, 1)
		_crop_list.add_child(label)
		return

	for crop_id: String in harvested:
		var count: int = harvested[crop_id]
		var needed: int = 0
		if _selected_a == crop_id:
			needed += 1
		if _selected_b == crop_id:
			needed += 1
		var available: int = count - needed
		if available <= 0:
			continue
		var crop: CropData = Database.get_crop(crop_id)
		var crop_name: String = crop.get_active_name() if crop else crop_id
		var btn: Button = Button.new()
		btn.text = "%s x%d" % [crop_name, available]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_crop_selected.bind(crop_id))
		_crop_list.add_child(btn)


func _on_crop_selected(crop_id: String) -> void:
	if _selected_a == "":
		_selected_a = crop_id
	elif _selected_b == "":
		_selected_b = crop_id
	else:
		_selected_b = crop_id
	_refresh()


func _on_clear() -> void:
	_selected_a = ""
	_selected_b = ""
	_refresh()


func _on_start() -> void:
	if _hybridizer == null or _selected_a == "" or _selected_b == "":
		return
	if _hybridizer.start_hybridizing(_selected_a, _selected_b):
		visible = false
	else:
		EventBus.notification_requested.emit("Invalid combination!")


func _update_slots() -> void:
	_slot_a_label.text = "Slot A: %s" % _display(_selected_a) if _selected_a != "" else "Slot A: (empty)"
	_slot_b_label.text = "Slot B: %s" % _display(_selected_b) if _selected_b != "" else "Slot B: (empty)"

	if _selected_a != "" and _selected_b != "":
		var result: String = _hybridizer.get_recipe_result(_selected_a, _selected_b) if _hybridizer else ""
		if result != "":
			var crop: CropData = Database.get_crop(result)
			_result_label.text = "= %s" % (crop.get_active_name() if crop else result)
			_result_label.modulate = Color(0.3, 1.0, 0.3, 1)
			_start_button.disabled = false
		else:
			_result_label.text = "= No known hybrid"
			_result_label.modulate = Color(1.0, 0.3, 0.3, 1)
			_start_button.disabled = true
	else:
		_result_label.text = "Select 2 crops"
		_result_label.modulate = Color(0.5, 0.5, 0.5, 1)
		_start_button.disabled = true


func _display(crop_id: String) -> String:
	var crop: CropData = Database.get_crop(crop_id)
	return crop.get_active_name() if crop else crop_id
