class_name SanctumUI
extends RefCounted
## Shared panel styling and restrained movement. Fonts inherit the project theme.
##
## Panels are the Kenney inner rule over a dark fill, and buttons the Ornate bevelled squares,
## both from the art library through MapArt, always in neutral white here: the adventure screens
## tint their own copy to the run's school. Small plain panels (`Panel`) and roster tiles
## (`TileButton`) keep the flat boxes, since a nine-slice frame does not fit them.

const PRIMARY_FACE: Color = Color(0.80, 0.78, 0.74)

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = ZenithTheme.get_theme().duplicate()
	_theme.set_color("font_color", "MutedLabel", Color(0.66, 0.66, 0.66))
	_theme.set_stylebox("panel", "PanelContainer", panel())
	_theme.set_stylebox("panel", "Panel", flat_panel())
	_theme.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	_theme.set_color("font_color", "AccentLabel", ZenithTheme.TEXT)
	var neutral: Color = Color.WHITE
	for kind: String in ["Button", "OptionButton", "AccentButton"]:
		var primary: bool = kind == "AccentButton"
		var prefix: String = "accent" if primary else "button"
		# The primary pieces grey out to pure white, which reads as a glaring slab; a warm light
		# grey keeps them the brightest thing on screen without shouting.
		var face: Color = PRIMARY_FACE if primary else neutral
		_theme.set_stylebox("normal", kind, MapArt.button_box(prefix + "_normal", face))
		_theme.set_stylebox("hover", kind, MapArt.button_box(prefix + "_hover", face))
		_theme.set_stylebox("pressed", kind, MapArt.button_box(prefix + "_pressed", face))
		_theme.set_stylebox("disabled", kind, MapArt.button_box("button_disabled", neutral))
		_theme.set_stylebox("focus", kind, StyleBoxEmpty.new())
		for state: String in ["font_color", "font_pressed_color", "font_focus_color"]:
			_theme.set_color(state, kind, Color(0.10, 0.10, 0.10) if primary else ZenithTheme.TEXT)
		# The ordinary button's hover piece is pale, so its text turns dark to stay readable.
		_theme.set_color("font_hover_color", kind, Color(0.10, 0.10, 0.10))
		_theme.set_color("font_disabled_color", kind, Color(0.42, 0.42, 0.42))
	_theme.set_stylebox("normal", "TileButton", ZenithTheme.box(Color(0.13, 0.13, 0.13), Color(0.30, 0.30, 0.30), 2, 1, 18, 10))
	_theme.set_stylebox("hover", "TileButton", ZenithTheme.box(Color(0.20, 0.20, 0.20), Color(0.44, 0.44, 0.44), 2, 1, 18, 10))
	_theme.set_stylebox("pressed", "TileButton", ZenithTheme.box(Color(0.09, 0.09, 0.09), Color(0.44, 0.44, 0.44), 2, 1, 18, 10))
	_theme.set_stylebox("disabled", "TileButton", ZenithTheme.box(Color(0.11, 0.11, 0.11), Color(0.20, 0.20, 0.20), 2, 1, 18, 10))
	_theme.set_stylebox("focus", "TileButton", ZenithTheme.box(Color.TRANSPARENT, Color(0.8, 0.8, 0.8), 2, 2, 0, 0))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_theme.set_color(state, "TileButton", ZenithTheme.TEXT)
	_theme.set_color("font_disabled_color", "TileButton", Color(0.42, 0.42, 0.42))
	_theme.set_stylebox("normal", "LineEdit", ZenithTheme.box(Color(0.06, 0.06, 0.06), Color(0.22, 0.22, 0.22), 2, 1, 10, 6))
	_theme.set_stylebox("focus", "LineEdit", ZenithTheme.box(Color.TRANSPARENT, Color(0.65, 0.65, 0.65), 2, 1, 10, 6))
	return _theme


## A copy of the shared theme with its framed panels in `tint`: the adventure screens pass the
## run's school colour (MapArt.tint after `MapArt.tint_for_school`). Buttons stay neutral.
static func themed(tint: Color) -> Theme:
	var t: Theme = theme().duplicate()
	t.set_stylebox("panel", "PanelContainer", MapArt.panel_box(22, tint))
	return t


## Dresses a flat screen in the shared look: its screen title on a scroll banner in the trim tint,
## and, with `terrain`, the dim hex terrain from the adventure map behind it (inside its
## `Background` node). Screens for reading cards (deck views, bundle picks, the shelf) leave the
## terrain off: behind rows of cards it is too busy (user, 2026-09-23). `act` picks the land,
## `seed_value` lays it out.
static func dress(screen: Control, title: Label, terrain: bool = false, act: int = 1, seed_value: int = 20260923) -> void:
	var background: Control = screen.get_node_or_null("Background") as Control
	if terrain and background != null:
		var backdrop: TerrainBackdrop = TerrainBackdrop.new()
		background.add_child(backdrop)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.show_act(act, seed_value)
	if title != null:
		banner_heading(title)


## A Label set on a scroll banner, in dark ink, sized to its text.
static func banner_heading(label: Label) -> void:
	label.add_theme_stylebox_override("normal", MapArt.banner_box("banner", 36, 12, 16))
	label.add_theme_color_override("font_color", ZenithTheme.TEXT_DARK)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## The shared framed panel: Kenney inner rule over a dark fill, neutral.
static func panel() -> StyleBox:
	return MapArt.panel_box(22, Color.WHITE)


## The flat box small panels keep.
static func flat_panel() -> StyleBoxFlat:
	return ZenithTheme.box(Color(0.065, 0.065, 0.065, 0.96), Color(0.20, 0.20, 0.20), 2, 1, 24, 22)


static func enter(control: Control, delay: float = 0.0) -> void:
	var previous: Tween = control.get_meta("sanctum_enter_tween") if control.has_meta("sanctum_enter_tween") else null
	if previous != null and previous.is_valid():
		previous.kill()
	if ArcaneBackdrop.motion_reduced():
		control.modulate.a = 1.0
		return
	control.modulate.a = 0.0
	var tween: Tween = control.create_tween()
	control.set_meta("sanctum_enter_tween", tween)
	tween.tween_interval(delay)
	tween.tween_property(control, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE)


static func wire_buttons(root: Node) -> void:
	for node: Node in root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.has_meta("sanctum_hover") or button is RosterTile:
			continue
		button.set_meta("sanctum_hover", true)
		button.mouse_entered.connect(func() -> void: _hover(button, true))
		button.mouse_exited.connect(func() -> void: _hover(button, false))


static func _hover(button: Button, over: bool) -> void:
	if button.disabled or ArcaneBackdrop.motion_reduced():
		return
	var previous: Tween = button.get_meta("sanctum_tween") if button.has_meta("sanctum_tween") else null
	if previous != null and previous.is_valid():
		previous.kill()
	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	button.set_meta("sanctum_tween", tween)
	tween.tween_property(button, "scale", Vector2.ONE * (1.025 if over else 1.0), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
