class_name DuskPanel
extends Control
## The evening tally.

signal closed

@onready var _called: Label = %Called
@onready var _watered: Label = %Watered
@onready var _invited: Label = %Invited
@onready var _planted: Label = %Planted
@onready var _close: Button = %Close


func _ready() -> void:
	_close.pressed.connect(func() -> void: hide(); closed.emit())
	hide()


func show_tally(tally: Dictionary) -> void:
	_called.text = str(int(tally.get("called", 0)))
	_watered.text = str(int(tally.get("watered", 0)))
	_invited.text = str(int(tally.get("invited", 0)))
	_planted.text = str(int(tally.get("planted", 0)))
	show()
	_close.grab_focus()
