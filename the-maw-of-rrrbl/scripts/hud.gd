extends CanvasLayer
class_name HUD

@onready var sparks_label: Label = $MarginContainer/VBoxContainer/SparksLabel
@onready var maw_bar: ProgressBar = $MarginContainer/VBoxContainer/MawBar
@onready var void_label: Label = $MarginContainer/VBoxContainer/VoidLabel
@onready var orb_count_label: Label = $MarginContainer/VBoxContainer/OrbCountLabel

var _cycle_label: Label
var _hint_label: Label
var _tutorial_label: Label

func _ready() -> void:
	_add_cycle_label()
	_add_controls_hint()
	_add_tutorial_prompt()

func update_sparks(amount: float) -> void:
	if sparks_label:
		sparks_label.text = "Sparks: %d" % int(amount)

func update_maw(fill_pct: float) -> void:
	if maw_bar:
		maw_bar.value = fill_pct * 100.0

func update_void_marbles(count: int) -> void:
	if void_label:
		void_label.text = "Void Marbles: %d" % count

func update_orb_count(active: int) -> void:
	if orb_count_label:
		orb_count_label.text = "Orbs: %d" % active

func update_cycle(cycle: int) -> void:
	if _cycle_label:
		_cycle_label.text = "Cycle: %d" % cycle

func hide_tutorial() -> void:
	if _tutorial_label:
		_tutorial_label.visible = false

func _add_cycle_label() -> void:
	_cycle_label = Label.new()
	_cycle_label.text = "Cycle: 1"
	_cycle_label.add_theme_font_size_override("font_size", 16)
	_cycle_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))

	var container: Control = Control.new()
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	container.offset_left = 16.0
	container.offset_top = 16.0
	container.offset_right = 200.0
	container.offset_bottom = 40.0
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_cycle_label)
	add_child(container)

func _add_controls_hint() -> void:
	_hint_label = Label.new()
	_hint_label.text = "LMB: Place / Click Portal  |  RMB: Orbit  |  MMB: Pan  |  Scroll: Zoom  |  R: Rotate  |  Tab: Cycle  |  Ctrl+Z: Undo  |  Esc: Cancel"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.6))

	var container: Control = Control.new()
	container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	container.offset_top = -30.0
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_hint_label)
	_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

func _add_tutorial_prompt() -> void:
	_tutorial_label = Label.new()
	_tutorial_label.text = "Pick a piece from the left panel, connect it to a portal, and build toward the Maw"
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_label.add_theme_font_size_override("font_size", 20)
	_tutorial_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5, 0.9))

	var container: Control = Control.new()
	container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	container.offset_top = 60.0
	container.offset_left = -300.0
	container.offset_right = 300.0
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_tutorial_label)
	_tutorial_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)
