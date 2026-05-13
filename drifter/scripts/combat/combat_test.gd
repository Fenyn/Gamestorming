extends Control

const MODULE_CARD_SCENE: String = "res://scenes/combat/module_card.tscn"

@onready var _roll_button: Button = %RollButton
@onready var _values_label: Label = %ValuesLabel
@onready var _dice_tray: DiceTray = %DiceTray
@onready var _module_row: HBoxContainer = %ModuleRow

var _card_scene: PackedScene
var _starting_modules: Array[ModuleData] = []


func _ready() -> void:
	theme = ThemeBuilder.build()
	_card_scene = load(MODULE_CARD_SCENE) as PackedScene

	_starting_modules = [
		load("res://resources/modules/plasma_jab.tres") as ModuleData,
		load("res://resources/modules/barrier.tres") as ModuleData,
		load("res://resources/modules/plasma_lance.tres") as ModuleData,
		load("res://resources/modules/arc_sweep.tres") as ModuleData,
	]

	for i: int in _starting_modules.size():
		var card: ModuleCard = _card_scene.instantiate() as ModuleCard
		card.setup(_starting_modules[i], i)
		_module_row.add_child(card)

	_roll_button.pressed.connect(_on_roll_pressed)
	EventBus.all_dice_settled.connect(_on_all_settled)
	EventBus.module_fired.connect(_on_module_fired)


func _on_roll_pressed() -> void:
	_values_label.text = "Rolling..."
	_roll_button.disabled = true
	_dice_tray.roll_all_free()


func _on_all_settled(values: Array[int]) -> void:
	_values_label.text = "Rolled: " + str(values)
	_roll_button.disabled = false


func _on_module_fired(module_index: int, effect_type: int, total_value: int, pip_total: int) -> void:
	var type_name: String = ModuleData.EffectType.keys()[effect_type]
	_values_label.text = "FIRED: " + type_name + " for " + str(total_value) + " (pips: " + str(pip_total) + ")"
