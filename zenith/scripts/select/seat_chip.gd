class_name SeatChip
extends PanelContainer
## One seat in the online lobby's PLAYERS strip: an edge in the seat's colour, the player's rank
## emblem, the name with its tag (sized for the longest listed name), and the seat's state below. The
## seat colour stays on the edge so it is never read as the rank's. This player's own seat has the
## raised fill. A seat whose rank this side does not know (a LAN host's joiner) shows no emblem,
## its slot kept.

@onready var edge: ColorRect = %Edge
@onready var emblem: RankEmblem = %Emblem
@onready var name_label: Label = %PlayerName
@onready var tag_label: Label = %Tag
@onready var state_label: Label = %State


## `tag` "" means the badge is unknown. `present` false is an empty seat.
func show_seat(player_name: String, tag: String, rank: int, state: String, seat_color: Color, mine: bool, present: bool) -> void:
	edge.color = seat_color if present else ZenithTheme.BORDER
	emblem.rank = rank
	emblem.modulate.a = 1.0 if present and tag != "" else 0.0
	name_label.text = player_name if present else "Empty seat"
	name_label.theme_type_variation = &"BodyLabel" if present else &"MutedLabel"
	tag_label.text = "#" + tag if present and tag != "" else ""
	state_label.text = state
	var fill: Color = ZenithTheme.BG_ACTIVE if mine else (ZenithTheme.BG if present else Color.TRANSPARENT)
	add_theme_stylebox_override("panel", ZenithTheme.box(fill, Color.TRANSPARENT, ZenithTheme.RADIUS, 0, 0, 0))
