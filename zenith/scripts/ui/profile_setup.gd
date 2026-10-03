class_name ProfileSetup
extends Control
## The name screen over the title: on first launch, with a name already drawn so one Enter goes on,
## and later from the profile chip to change it. The name is one word from each `PlayerNames` list;
## Random draws another. The tag beside it is this install's and cannot be changed; it fills in a
## frame after the screen shows, since making the install's key on first launch takes a moment.

## `problem` is "" when the name was saved, otherwise why not; the screen closes either way, so a
## disk that refuses the file never keeps the player from the title.
signal saved(problem: String)

const SAME_WORDS: String = "Choose two different words."
const WEB_BODY: String = "Other players see this name when you play the desktop version online. The number after it is yours alone, and you can change the name later from the title screen."

@onready var scrim: ColorRect = %Scrim
@onready var panel: PanelContainer = %Panel
@onready var preview: ProfileChip = %Preview
@onready var first_pick: OptionButton = %First
@onready var second_pick: OptionButton = %Second
@onready var random_button: Button = %Random
@onready var body: Label = %Body
@onready var problem_label: Label = %Problem
@onready var cancel_button: Button = %Cancel
@onready var save_button: Button = %Save

var _tag: String = ""


func _ready() -> void:
	scrim.color = ZenithTheme.SCRIM_STRONG
	panel.add_theme_stylebox_override("panel", MapArt.panel_box(36, ZenithTheme.FRAME))
	if OnlineGate.is_web():
		body.text = WEB_BODY
	for word in PlayerNames.firsts():
		first_pick.add_item(word)
	for word in PlayerNames.seconds():
		second_pick.add_item(word)
	first_pick.item_selected.connect(func(_i: int) -> void: _show_preview())
	second_pick.item_selected.connect(func(_i: int) -> void: _show_preview())
	random_button.pressed.connect(func() -> void: _pick(PlayerNames.random()))
	cancel_button.pressed.connect(hide)
	save_button.pressed.connect(_save)
	hide()


## Shows the screen. On `first_launch` there is no Cancel and a name is drawn at random.
func open(first_launch: bool) -> void:
	cancel_button.visible = not first_launch
	_pick(Session.profile.name if Session.profile.named() else PlayerNames.random())
	show()
	save_button.grab_focus()
	if _tag == "":
		await get_tree().process_frame
		_tag = Session.profile_tag()
		_show_preview()


func chosen() -> String:
	return PlayerNames.compose(first_pick.get_item_text(first_pick.selected), second_pick.get_item_text(second_pick.selected))


func _pick(player_name: String) -> void:
	var words: Array[String] = PlayerNames.split(player_name)
	first_pick.select(maxi(0, PlayerNames.firsts().find(words[0])))
	second_pick.select(maxi(0, PlayerNames.seconds().find(words[1])))
	_show_preview()


func _show_preview() -> void:
	preview.show_player(chosen(), _tag, Session.profile.rank())
	# The same word twice is no name ("Moth Moth"); Save waits for another pick and says why.
	save_button.disabled = not PlayerNames.valid(chosen())
	problem_label.text = SAME_WORDS if save_button.disabled else ""


func _save() -> void:
	if not PlayerNames.valid(chosen()):
		return
	var problem: String = Session.set_profile_name(chosen())
	hide()
	saved.emit(problem)


func _unhandled_input(event: InputEvent) -> void:
	if visible and cancel_button.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()
