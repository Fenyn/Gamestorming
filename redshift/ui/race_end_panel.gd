class_name RaceEndPanel
extends PanelContainer

@onready var _title_label: Label = %TitleLabel
@onready var _time_label: Label = %TimeLabel
@onready var _best_label: Label = %BestLabel
@onready var _prompt_label: Label = %PromptLabel

var _best_time: float = INF


func _ready() -> void:
	visible = false
	EventBus.race_finished.connect(_on_race_finished)
	EventBus.race_countdown_tick.connect(_on_countdown)


func set_best_time(time: float) -> void:
	_best_time = time


func _on_race_finished(final_time: float, is_new_best: bool) -> void:
	_time_label.text = _format_time(final_time)

	if is_new_best:
		_best_time = final_time
		_title_label.text = "NEW BEST!"
		_title_label.modulate = Color.YELLOW
		_best_label.text = _format_time(final_time)
		_best_label.modulate = Color.YELLOW
	else:
		_title_label.text = "FINISHED"
		_title_label.modulate = Color.WHITE
		if _best_time < INF:
			_best_label.text = _format_time(_best_time)
		else:
			_best_label.text = "--:--.--"
		_best_label.modulate = Color(0.6, 0.6, 0.6, 1)

	_prompt_label.text = "Press R to restart"
	visible = true


func _on_countdown(_seconds_left: int) -> void:
	visible = false


func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: float = fmod(seconds, 60.0)
	return "%d:%05.2f" % [mins, secs]
