class_name TimingMinigame
extends BaseMinigame

@export var sweep_speed: float = 300.0
@export var bar_width: float = 400.0

var _indicator_x: float = 0.0
var _direction: float = 1.0
var _sweet_spot_left: float = 0.0
var _sweet_spot_right: float = 0.0

@onready var _indicator: ColorRect = %Indicator
@onready var _sweet_spot: ColorRect = %SweetSpot


func _on_start() -> void:
	_indicator_x = 0.0
	_direction = 1.0
	_sweet_spot_left = _sweet_spot.position.x
	_sweet_spot_right = _sweet_spot.position.x + _sweet_spot.size.x


func _process(delta: float) -> void:
	if not _active:
		return
	_indicator_x += _direction * sweep_speed * delta
	if _indicator_x >= bar_width:
		_indicator_x = bar_width
		_direction = -1.0
	elif _indicator_x <= 0.0:
		_indicator_x = 0.0
		_direction = 1.0
	_indicator.position.x = _indicator_x


func _evaluate_hit() -> bool:
	return _indicator_x >= _sweet_spot_left and _indicator_x <= _sweet_spot_right
