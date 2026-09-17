class_name DevPanel
extends PanelContainer
## Dev commands: each button is an engine effect run for the viewer (or the rival) through the
## referee, so triggers fire as they would from a card.

signal command(effect: Dictionary)

const ROWS: Array = [
	["Fervor", [["-1", {"op": "fervor", "amount": -1}], ["+1", {"op": "fervor", "amount": 1}], ["0", {"op": "set_fervor", "amount": 0}], ["4", {"op": "set_fervor", "amount": 4}]]],
	["Needed", [["-1", {"op": "fervor_needed", "amount": -1}], ["+1", {"op": "fervor_needed", "amount": 1}], ["5", {"op": "set_fervor_needed", "amount": 5}], ["7", {"op": "set_fervor_needed", "amount": 7}]]],
	["Energy", [["-1", {"op": "energy", "amount": -1}], ["+1", {"op": "energy", "amount": 1}], ["0", {"op": "set_energy", "amount": 0}], ["Full", {"op": "energy", "amount": "max"}]]],
	["Aspect", [["Down", {"op": "lose_aspect"}], ["Up", {"op": "advance_aspect"}]]],
	["Cards", [["Draw", {"op": "draw", "amount": 1}], ["Wound", {"op": "discard_life", "amount": 1}], ["Wound 3", {"op": "discard_life", "amount": 3}], ["Recover", {"op": "recover", "amount": 1, "from": "top"}], ["Discard", {"op": "discard_hand", "amount": 1, "random": true}]]],
	["Flow", [["End Combat", {"op": "end_combat"}], ["End Turn", {"op": "end_turn"}]]],
]

@onready var rows: VBoxContainer = $Column/Rows
@onready var me_button: Button = $Column/Target/Me
@onready var rival_button: Button = $Column/Target/Rival
@onready var search_text: LineEdit = $Column/Search/Title
@onready var to_hand: Button = $Column/Search/ToHand
@onready var to_play: Button = $Column/Search/ToPlay
@onready var status: Label = $Column/Status


func _ready() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	me_button.button_group = group
	rival_button.button_group = group
	me_button.button_pressed = true
	for row in ROWS:
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		var name_label: Label = Label.new()
		name_label.text = str(row[0])
		name_label.custom_minimum_size = Vector2(56, 0)
		name_label.theme_type_variation = &"MutedLabel"
		h.add_child(name_label)
		for entry in row[1]:
			var b: Button = Button.new()
			b.text = str(entry[0])
			b.add_theme_font_size_override("font_size", 12)
			var effect: Dictionary = entry[1]
			b.pressed.connect(func() -> void: _send(effect))
			h.add_child(b)
		rows.add_child(h)
	to_hand.pressed.connect(func() -> void: _search("hand"))
	to_play.pressed.connect(func() -> void: _search("play"))
	search_text.text_submitted.connect(func(_t: String) -> void: _search("hand"))


func _search(dest: String) -> void:
	var title: String = search_text.text.strip_edges()
	if title == "":
		return
	_send({"op": "search", "title_contains": title, "to": dest, "source": "either"})


func _send(effect: Dictionary) -> void:
	var e: Dictionary = effect.duplicate()
	if rival_button.button_pressed:
		e["who"] = "opponent"
	command.emit(e)


func report(problem: String) -> void:
	status.text = problem
	status.visible = problem != ""
