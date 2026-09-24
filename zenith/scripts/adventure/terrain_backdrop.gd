class_name TerrainBackdrop
extends ColorRect
## The stage screen's backdrop: the current act's hex terrain from the art library, darkened well
## behind the panels, with a faint wash of the run's school colour. Takes the same calls as
## ArcaneBackdrop so the screen can swap one for the other.

const SHADE: float = 0.2
const HEX_WIDTH: float = 128.0

var _field: HexField = null
var _wash: ColorRect = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0.05, 0.045, 0.04)
	_field = HexField.new()
	_field.hex_width = HEX_WIDTH
	add_child(_field)
	_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash = ColorRect.new()
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash.color = Color(0, 0, 0, 0)
	add_child(_wash)
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Shows `act`'s land, laid out from `seed_value`.
func show_act(act: int, seed_value: int) -> void:
	var band: Array[Dictionary] = [{"top": -INF, "bottom": INF, "act": act, "shade": SHADE}]
	_field.set_bands(band, seed_value + 7919)


func set_school(school_color: Color, _strong: bool = false) -> void:
	_wash.color = Color(school_color, 0.08)


func set_rival(_rival_color: Color) -> void:
	pass
