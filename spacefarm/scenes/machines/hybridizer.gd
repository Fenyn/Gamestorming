class_name Hybridizer
extends StaticBody2D

const HYBRID_RECIPES: Dictionary = {
	"tomato+pepper": "grapevine",
	"pepper+tomato": "grapevine",
	"turnip+wheat": "prickly_pear",
	"wheat+turnip": "prickly_pear",
	"cabbage+grapevine": "cotton",
	"grapevine+cabbage": "cotton",
	"tomato+prickly_pear": "corn",
	"prickly_pear+tomato": "corn",
	"grapevine+prickly_pear": "watermelon",
	"prickly_pear+grapevine": "watermelon",
}
const HYBRID_DAYS: int = 3

signal hybridizer_opened

var _slot_a: String = ""
var _slot_b: String = ""
var _days_remaining: int = 0
var _result_crop_id: String = ""
var _is_processing: bool = false

@onready var _visual: ColorRect = %HybridVisual
@onready var _label: Label = %HybridLabel
@onready var _status: Label = %StatusLabel


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	EventBus.day_started.connect(_on_day_started)
	_update_display()


func interact(_player: Node2D) -> void:
	if _result_crop_id != "" and not _is_processing:
		_collect()
		return
	hybridizer_opened.emit()


func get_interact_hint() -> String:
	if _result_crop_id != "" and not _is_processing:
		var crop: CropData = Database.get_crop(_result_crop_id)
		var name: String = crop.get_active_name() if crop else _result_crop_id
		return "E/Click: Collect %s seeds" % name
	if _is_processing:
		return "Hybridizing... %d days left" % _days_remaining
	return "E/Click: Open hybridizer"


func start_hybridizing(crop_a: String, crop_b: String) -> bool:
	var key: String = "%s+%s" % [crop_a, crop_b]
	if not HYBRID_RECIPES.has(key):
		return false
	if not GameState.remove_item(crop_a, 1):
		return false
	if not GameState.remove_item(crop_b, 1):
		GameState.add_item(crop_a, 1)
		return false

	_slot_a = crop_a
	_slot_b = crop_b
	_result_crop_id = HYBRID_RECIPES[key]
	_days_remaining = HYBRID_DAYS
	_is_processing = true
	_update_display()
	return true


func _collect() -> void:
	GameState.add_seeds(_result_crop_id, 2)
	EventBus.notification_requested.emit("Received 2x %s seeds!" % _result_crop_id.replace("_", " "))
	_result_crop_id = ""
	_slot_a = ""
	_slot_b = ""
	_is_processing = false
	_update_display()


func _on_day_started(_day: int) -> void:
	if not _is_processing:
		return
	_days_remaining -= 1
	if _days_remaining <= 0:
		_is_processing = false
	_update_display()


func _update_display() -> void:
	if _result_crop_id != "" and not _is_processing:
		_status.text = "DONE"
		_status.modulate = Color(0.3, 1.0, 0.3, 1)
	elif _is_processing:
		_status.text = "%d DAYS" % _days_remaining
		_status.modulate = Color(1.0, 0.8, 0.3, 1)
	else:
		_status.text = "IDLE"
		_status.modulate = Color(0.5, 0.5, 0.5, 1)


func get_recipe_result(crop_a: String, crop_b: String) -> String:
	var key: String = "%s+%s" % [crop_a, crop_b]
	return HYBRID_RECIPES.get(key, "")
