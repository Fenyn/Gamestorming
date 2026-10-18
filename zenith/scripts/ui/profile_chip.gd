class_name ProfileChip
extends Button
## A player as other players see them: the rank emblem, the name with its tag, and the rank's name
## in its colour. With `clickable` on it is a button (the title's, which changes the name) with an
## EDIT handle at its end; otherwise a quiet tile that takes no input (versus sheets, the duel
## plates, the name screen's preview). The button sizes itself to its content.

@export var clickable: bool = false
## The emblem's side and the name's font size, per use: 60/30 on the title, 96/36 on the name
## screen, 72/30 on the versus sheets, 48/24 on the duel plate.
@export var emblem_size: int = 60
@export var name_size: int = ZenithTheme.SIZE_ROW
## Keep a missing tag's width, so the name does not move when the tag arrives (the name screen).
@export var reserve_tag: bool = false
## A darker fill that reads over the busy duel board.
@export var solid: bool = false

@onready var margin: MarginContainer = %Margin
@onready var emblem: RankEmblem = %Emblem
@onready var name_label: Label = %PlayerName
@onready var tag_label: Label = %Tag
@onready var rank_label: Label = %RankName
@onready var edit_rule: ColorRect = %EditRule
@onready var edit_label: Label = %Edit


func _ready() -> void:
	emblem.custom_minimum_size = Vector2.ONE * emblem_size
	name_label.add_theme_font_size_override("font_size", name_size)
	# Beside a large emblem the rank name reads at body size.
	rank_label.theme_type_variation = &"BodyLabel" if emblem_size >= 72 else &"CaptionLabel"
	edit_rule.visible = clickable
	edit_label.visible = clickable
	if clickable:
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_stylebox_override("focus", ZenithTheme.box(Color.TRANSPARENT, ZenithTheme.ACCENT, ZenithTheme.RADIUS, 2, 0, 0))
		edit_rule.color = ZenithTheme.BORDER
		# The handle brightens while the chip is hovered or focused, so it reads as the thing to press.
		for pair: Array in [[mouse_entered, true], [mouse_exited, false], [focus_entered, true], [focus_exited, false]]:
			(pair[0] as Signal).connect(_light_edit.bind(bool(pair[1])))
		_light_edit(false)
	else:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tile: StyleBox = ZenithTheme.box(ZenithTheme.BG if solid else ZenithTheme.RAISED, Color.TRANSPARENT, ZenithTheme.RADIUS, 0, 0, 0)
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, tile)
	margin.minimum_size_changed.connect(_fit)
	_fit()


## `tag` "" shows none. `known` false is a player whose rank this side cannot know (a LAN host's
## joiner): no emblem and no rank name, rather than a false Novice.
func show_player(player_name: String, tag: String, rank: int, known: bool = true) -> void:
	emblem.rank = rank
	emblem.visible = known
	name_label.text = player_name
	tag_label.text = "#" + (tag if tag != "" else "0000")
	tag_label.visible = tag != "" or reserve_tag
	tag_label.modulate.a = 1.0 if tag != "" else 0.0
	rank_label.text = Ranks.rank_name(rank)
	rank_label.visible = known
	rank_label.add_theme_color_override("font_color", Ranks.color(rank))


func _light_edit(on: bool) -> void:
	edit_label.add_theme_color_override("font_color", ZenithTheme.ACCENT if on or has_focus() else ZenithTheme.TEXT_SOFT)


func _fit() -> void:
	custom_minimum_size = margin.get_combined_minimum_size()
