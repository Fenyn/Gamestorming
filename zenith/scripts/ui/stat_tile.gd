class_name StatTile
extends PanelContainer
## One headline number: a small caps name, a big value in its role colour, an optional pip bar,
## and a one-line note. Used wherever a game fundamental (Energy, Might, Life) needs to be read
## at a glance rather than found in a list.

const PIP_SIZE: Vector2 = Vector2(7, 9)

@onready var name_label: Label = $Column/Name
@onready var value_label: Label = $Column/Value
@onready var pips_box: HBoxContainer = $Column/Pips
@onready var sub_label: Label = $Column/Sub

var _pips: Array[Panel] = []


func _ready() -> void:
	add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.RAISED, Color(0, 0, 0, 0), 8, 0, 10, 6))


func set_stat(stat_name: String, value: String, sub: String, color: Color) -> void:
	name_label.text = stat_name.to_upper()
	value_label.text = value
	value_label.add_theme_color_override("font_color", color)
	sub_label.text = sub
	sub_label.visible = sub != ""


## Fills `count` pips of `total` in `color`. Pass total 0 to hide the bar.
func set_pips(count: int, total: int, color: Color) -> void:
	pips_box.visible = total > 0
	while _pips.size() < total:
		var p: Panel = Panel.new()
		p.custom_minimum_size = PIP_SIZE
		pips_box.add_child(p)
		_pips.append(p)
	for i in range(_pips.size()):
		_pips[i].visible = i < total
		_pips[i].add_theme_stylebox_override("panel", ZenithTheme.pip(i < count, color))
