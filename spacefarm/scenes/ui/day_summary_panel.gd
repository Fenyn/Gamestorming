class_name DaySummaryPanel
extends CanvasLayer
## End-of-day report shown during the sleep fade. Dismiss with interact/accept.

signal continue_requested

@onready var _title: Label = %SummaryTitle
@onready var _body: Label = %SummaryBody
@onready var _rest_note: Label = %RestNote


func _ready() -> void:
	visible = false


func show_summary(ended_day: int, rested: bool) -> void:
	_title.text = "DAY %d COMPLETE" % ended_day
	_body.text = _build_body()
	if rested:
		_rest_note.text = "Well rested. Energy fully restored."
		_rest_note.modulate = Color(0.6, 0.9, 0.6, 1)
	else:
		_rest_note.text = "Worked past shutdown. Woke tired (75% energy)."
		_rest_note.modulate = Color(0.95, 0.75, 0.4, 1)
	visible = true


func _build_body() -> String:
	var lines: Array[String] = []
	if GameState.today_harvested.is_empty():
		lines.append("Harvested: nothing")
	else:
		var parts: Array[String] = []
		for crop_id: String in GameState.today_harvested:
			var crop: CropData = Database.get_crop(crop_id)
			var crop_name: String = crop.get_active_name() if crop else crop_id
			parts.append("%s x%d" % [crop_name, GameState.today_harvested[crop_id]])
		lines.append("Harvested: " + ", ".join(parts))
	var shipped_today: int = GameState.food_shipped_total - GameState.day_start_food_shipped
	lines.append("Food shipped today: %d units" % shipped_today)
	var directive: MilestoneData = Database.get_milestone(GameState.active_directive_id) as MilestoneData
	if directive and directive.required_food_units > 0:
		lines.append("Directive: %d / %d food units" % [GameState.food_shipped_total, directive.required_food_units])
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		visible = false
		get_viewport().set_input_as_handled()
		continue_requested.emit()
