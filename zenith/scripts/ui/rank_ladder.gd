class_name RankLadder
extends Control
## The ranked ladder over the screen that opened it: every rank's emblem, name and the best rating
## that opens it, this player's rank lit and the ones above it dimmed, and this player's best rating.
## What sets a rank is each cell's hover. Opened from the Multiplayer page's Ranks button; Close or
## Esc shuts it.

const LOCKED_ALPHA: float = 0.6
const EMBLEM: int = 72
const CELL_WIDTH: int = 144
const RANK_HOVER: String = "A rank opens at the best ranked rating shown under it. A rank stays when the rating falls."

@onready var scrim: ColorRect = %Scrim
@onready var panel: PanelContainer = %Panel
@onready var row: HBoxContainer = %Ranks
@onready var note: Label = %Note
@onready var close_button: Button = %Close


func _ready() -> void:
	scrim.color = ZenithTheme.SCRIM_STRONG
	panel.add_theme_stylebox_override("panel", MapArt.panel_box(36, ZenithTheme.FRAME))
	close_button.pressed.connect(hide)
	# Close is the only control, so focus stays on it instead of reaching the title behind.
	for side: String in ["focus_neighbor_left", "focus_neighbor_top", "focus_neighbor_right", "focus_neighbor_bottom", "focus_next", "focus_previous"]:
		close_button.set(side, close_button.get_path())
	hide()


## Shows the ladder for a player whose best rating is `best`; `rated` false for one who has never
## had a ranked rating.
func open(best: int, rated: bool) -> void:
	var mine: int = Ranks.index_for(best)
	for child in row.get_children():
		child.free()
	for i in Ranks.LADDER.size():
		row.add_child(_cell(i, i <= mine, i == mine))
	note.text = ladder_text(best, rated)
	note.visible = note.text != ""
	show()
	close_button.grab_focus()


## This player's best ranked rating as a label, "" for one never rated.
static func ladder_text(best: int, rated: bool) -> String:
	return "Best rating %d" % best if rated else ""


## One rank's cell: a reached rank at full strength, the player's own boxed in its colour.
func _cell(rank: int, reached: bool, mine: bool) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	var box_color: Color = Ranks.color(rank) if mine else Color.TRANSPARENT
	frame.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_ACTIVE if mine else Color.TRANSPARENT, box_color, ZenithTheme.RADIUS, 2, 6, 12))
	frame.modulate.a = 1.0 if reached else LOCKED_ALPHA
	frame.tooltip_text = RANK_HOVER
	var cell: VBoxContainer = VBoxContainer.new()
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.custom_minimum_size = Vector2(CELL_WIDTH, 0)
	cell.add_theme_constant_override("separation", 6)
	frame.add_child(cell)
	var emblem: RankEmblem = RankEmblem.new()
	emblem.custom_minimum_size = Vector2.ONE * EMBLEM
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	emblem.rank = rank
	cell.add_child(emblem)
	var title: Label = Label.new()
	title.text = Ranks.rank_name(rank)
	title.theme_type_variation = &"BodyLabel"
	title.add_theme_color_override("font_color", Ranks.color(rank))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(title)
	var at: Label = Label.new()
	at.text = str(int(Ranks.LADDER[rank]["at"]))
	at.theme_type_variation = &"CaptionLabel"
	at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(at)
	return frame


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()
