class_name Hud
extends Control

## The player's screen overlay. Only what the player needs right now:
## - top left: the clock and the till, and how to open the shop during prep,
## - under the crosshair: what is being looked at and its keys,
## - top right: the cup ticket for the order in hand,
## - bottom: the controls of a locked mini-game, and the optional readout,
## - toasts for reviews, and the end-of-day summary.
## player.gd feeds it; nothing here reads game state on its own.

const DAY_SUMMARY := preload("res://scenes/ui/day_summary.tscn")
## Clock turns amber with this many seconds left.
const CLOCK_WARN := 30.0

@onready var _clock: Label = %Clock
@onready var _till: Label = %Till
@onready var _prep_hint: HBoxContainer = %PrepHint
@onready var _prep_chip: PanelContainer = %PrepChip
@onready var _prompt: VBoxContainer = %Prompt
@onready var _prompt_chip: PanelContainer = %Chip
@onready var _prompt_name: Label = %Name
@onready var _prompt_lines: VBoxContainer = %Lines
@onready var ticket: TicketCard = %Ticket
@onready var _tip: PanelContainer = %Tip
@onready var _tip_text: Label = %TipText
@onready var _toasts: VBoxContainer = %Toasts
@onready var _readout: Label = %Readout
@onready var _controls: PanelContainer = %Controls
@onready var _controls_row: HBoxContainer = %ControlsRow

var _prompt_key := ""
var _controls_text := ""
var _prep := false

func _ready() -> void:
	_prep_hint.add_child(KeyHint.make("Enter", "Open shop"))
	_prep_chip.visible = false
	ticket.tip_changed.connect(_on_tip_changed)

func set_clock(seconds_left: float) -> void:
	var t := maxi(ceili(seconds_left), 0)
	_clock.text = "%d:%02d" % [t / 60, t % 60]
	_clock.add_theme_color_override("font_color", UiStyle.AMBER if seconds_left < CLOCK_WARN else UiStyle.CREMA)

## Prep before the doors open: the clock reads Prep and the open-shop key shows.
func set_prep(on: bool) -> void:
	_prep = on
	_prep_chip.visible = on
	# Nothing in the till before opening, so only the clock shows.
	_till.visible = not on
	_till.get_parent().get_node("Divider").visible = not on
	if on:
		_clock.text = "Prep"
		_clock.remove_theme_color_override("font_color")

func set_till(amount: float) -> void:
	_till.text = "$%.2f" % amount

## What the crosshair is on: a name and hint lines in "[Key] action" form.
func set_prompt(title: String, hint_text: String) -> void:
	var key := title + "|" + hint_text
	if key == _prompt_key:
		return
	_prompt_key = key
	_prompt_name.text = title
	_prompt_name.visible = not title.is_empty()
	for c in _prompt_lines.get_children():
		_prompt_lines.remove_child(c)
		c.queue_free()
	for line in hint_text.split("\n", false):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", UiStyle.SPACE_L)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		KeyHint.fill(row, line)
		_prompt_lines.add_child(row)
	_prompt_chip.visible = not hint_text.is_empty()

func clear_prompt() -> void:
	set_prompt("", "")

func set_prompt_visible(on: bool) -> void:
	_prompt.visible = on

## Locked mini-game helpers: the controls strip and the numbers readout.
func set_mini_game_help(controls: String, readout: String) -> void:
	if controls != _controls_text:
		_controls_text = controls
		KeyHint.fill(_controls_row, controls)
	_controls.visible = not controls.is_empty()
	_readout.text = readout
	_readout.visible = not readout.is_empty()

func set_info_mode(on: bool) -> void:
	ticket.set_info_mode(on)

func _on_tip_changed(text: String, at_y: float) -> void:
	_tip.visible = not text.is_empty()
	_tip_text.text = text
	_tip.position.y = at_y - 12.0

## Stars, the tip if any, and only the steps that went wrong.
func show_review(stars: float, tip: float, issues: PackedStringArray) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = UiStyle.HUD_PANEL
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiStyle.SPACE_S)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiStyle.SPACE_XS)
	var color := UiStyle.star_color(stars)
	for i in range(5):
		var kind := UiIcon.Kind.STAR_EMPTY
		if stars >= float(i) + 1.0:
			kind = UiIcon.Kind.STAR_FULL
		elif stars >= float(i) + 0.5:
			kind = UiIcon.Kind.STAR_HALF
		row.add_child(UiIcon.make(kind, color, 40))
	if tip > 0.0:
		var spacer := Control.new()
		spacer.custom_minimum_size.x = UiStyle.SPACE_M
		row.add_child(spacer)
		var t := Label.new()
		t.text = "+$%.2f tip" % tip
		t.theme_type_variation = UiStyle.HUD_VALUE
		t.add_theme_color_override("font_color", UiStyle.GREEN)
		row.add_child(t)
	box.add_child(row)
	if not issues.is_empty():
		var l := Label.new()
		l.text = "     ".join(issues)
		l.theme_type_variation = UiStyle.HUD_MUTED
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	_toasts.add_child(panel)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_interval(2.6)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)

func show_day_summary() -> void:
	var summary := DAY_SUMMARY.instantiate()
	add_child(summary)
	set_prompt_visible(false)
	ticket.visible = false
	$Status.visible = false
