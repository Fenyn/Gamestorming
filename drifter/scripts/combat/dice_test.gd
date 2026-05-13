extends Control

@onready var _roll_button: Button = %RollButton
@onready var _values_label: Label = %ValuesLabel
@onready var _dice_tray: DiceTray = $VBox/DiceTray


func _ready() -> void:
	theme = ThemeBuilder.build()
	_roll_button.pressed.connect(_on_roll_pressed)
	EventBus.all_dice_settled.connect(_on_all_settled)
	EventBus.die_settled.connect(_on_die_settled)


func _on_roll_pressed() -> void:
	_values_label.text = "Rolling..."
	_roll_button.disabled = true
	_dice_tray.roll_all_free()


func _on_die_settled(cell_index: int, face_value: int) -> void:
	print("Cell ", cell_index, " settled: ", face_value)


func _on_all_settled(values: Array[int]) -> void:
	_values_label.text = "Rolled: " + str(values)
	_roll_button.disabled = false
	print("All settled: ", values)
