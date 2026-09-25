class_name ZenithTheme
extends RefCounted
## The one UI theme and its colour tokens, built once at runtime and applied to every screen. The
## standard it implements is designs/zenith_ui.md; no screen defines its own colours, sizes or radii.
##
## Type variations: AccentButton, TileButton, TitleLabel, GroupLabel, HeaderLabel, RowTitleLabel,
## BodyLabel, CaptionLabel, MutedLabel, AccentLabel, WarnLabel, StatLabel, Chip (Panel).
##
## Colour roles. Bone-white is "act here": the primary button, legal cards, YOUR TURN, the current
## step, the selection ring. Iron frames every panel and button. Meaning colours (Energy, Might,
## Fervor, attack, defence, XP, Motes) mean the same thing on every screen. School colours mark
## identity only: card frames, school chips, one edge or title per adventure screen.

const BG_SCREEN: Color = Color(0.055, 0.050, 0.055)
const SCRIM: Color = Color(0.03, 0.025, 0.03, 0.70)
const SCRIM_STRONG: Color = Color(0.03, 0.025, 0.03, 0.88)
const BG: Color = Color(0.085, 0.078, 0.080, 0.96)          # surface.panel
const BG_ACTIVE: Color = Color(0.15, 0.14, 0.14, 0.96)      # raised fill of a selected or active block
const BG_INPUT: Color = Color(0.0, 0.0, 0.0, 0.30)          # surface.sunken
const RAISED: Color = Color(1.0, 1.0, 1.0, 0.06)
const RAISED_STRONG: Color = Color(1.0, 1.0, 1.0, 0.09)
const HOVER: Color = Color(1.0, 1.0, 1.0, 0.12)
const FRAME: Color = Color(0.56, 0.57, 0.58)               # iron
const FRAME_DIM: Color = Color(0.36, 0.37, 0.38)
const BORDER: Color = Color(0.36, 0.37, 0.38, 0.55)        # 1 px tile edge and divider
const TEXT: Color = Color(0.93, 0.91, 0.87)
const TEXT_SOFT: Color = Color(0.78, 0.77, 0.74)
const MUTED: Color = Color(0.60, 0.59, 0.60)
const TEXT_DISABLED: Color = Color(0.42, 0.42, 0.42)
const TEXT_DARK: Color = Color(0.12, 0.10, 0.09)           # on card faces and light fills
const ACCENT: Color = Color(0.94, 0.91, 0.84)              # bone-white
const ACCENT_SOFT: Color = Color(0.94, 0.91, 0.84, 0.22)
const WARN: Color = Color(0.93, 0.55, 0.30)                # ember
const WARN_SOFT: Color = Color(0.93, 0.55, 0.30, 0.20)
const ATTACK: Color = Color(0.90, 0.38, 0.30)
const ATTACK_SOFT: Color = Color(0.90, 0.38, 0.30, 0.22)
const DEFEND: Color = Color(0.40, 0.62, 0.92)
const DEFEND_SOFT: Color = Color(0.40, 0.62, 0.92, 0.22)
const FERVOR: Color = Color(0.86, 0.22, 0.30)              # crimson
const FERVOR_TEXT: Color = Color(0.95, 0.42, 0.48)         # the same crimson lifted for text on dark
const ENERGY: Color = Color(0.36, 0.76, 0.58)
const ENERGY_SOFT: Color = Color(0.36, 0.76, 0.58, 0.22)
const MIGHT: Color = Color(0.78, 0.82, 0.90)
const XP: Color = Color(0.62, 0.55, 0.90)
const MOTES: Color = Color(0.48, 0.72, 1.00)               # arcane blue, drawn with a soft glow

## Radii: 0 for framed panels and buttons, 4 for flat tiles, chips and bars.
const RADIUS: int = 4
## Type scale at the 1920x1080 design size. Multiples of 6 draw whole pixels at 900p and 720p.
const SIZE_CAPTION: int = 18
const SIZE_BODY: int = 24
const SIZE_ROW: int = 30
const SIZE_GROUP: int = 36
const SIZE_TITLE: int = 48
const SIZE_DISPLAY: int = 72

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = RADIUS, border_width: int = 1, pad_x: int = 12, pad_y: int = 6) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_width if border.a > 0.0 else 0)
	b.set_corner_radius_all(radius)
	b.content_margin_left = pad_x
	b.content_margin_right = pad_x
	b.content_margin_top = pad_y
	b.content_margin_bottom = pad_y
	b.anti_aliasing = radius > 0
	return b


static func build() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = SIZE_BODY

	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", flat_panel())
	t.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	t.set_type_variation("Chip", "Panel")
	t.set_stylebox("panel", "Chip", box(RAISED, Color(0, 0, 0, 0), RADIUS, 0, 0, 0))

	for kind: String in ["Button", "OptionButton", "AccentButton"]:
		var primary: bool = kind == "AccentButton"
		var prefix: String = "accent" if primary else "button"
		t.set_stylebox("normal", kind, MapArt.button_box(prefix + "_normal"))
		t.set_stylebox("hover", kind, MapArt.button_box(prefix + "_hover"))
		t.set_stylebox("pressed", kind, MapArt.button_box(prefix + "_pressed"))
		t.set_stylebox("disabled", kind, MapArt.button_box("button_disabled"))
		t.set_stylebox("focus", kind, StyleBoxEmpty.new())
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(state, kind, TEXT_DARK if primary else TEXT)
		t.set_color("font_disabled_color", kind, TEXT_DISABLED)
	t.set_type_variation("AccentButton", "Button")

	# Selectable tile: a flat tile that takes the bone ring and a raised fill when chosen.
	t.set_type_variation("TileButton", "Button")
	t.set_stylebox("normal", "TileButton", box(RAISED, BORDER, RADIUS, 1, 18, 12))
	t.set_stylebox("hover", "TileButton", box(HOVER, FRAME, RADIUS, 1, 18, 12))
	t.set_stylebox("pressed", "TileButton", selected_box(18, 12))
	t.set_stylebox("disabled", "TileButton", box(Color(1, 1, 1, 0.03), Color(BORDER, 0.3), RADIUS, 1, 18, 12))
	t.set_stylebox("focus", "TileButton", box(Color.TRANSPARENT, FRAME, RADIUS, 2, 0, 0))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "TileButton", TEXT)
	t.set_color("font_disabled_color", "TileButton", TEXT_DISABLED)

	t.set_color("font_color", "Label", TEXT)
	_label(t, "TitleLabel", SIZE_TITLE, TEXT)
	_label(t, "GroupLabel", SIZE_GROUP, TEXT)
	_label(t, "HeaderLabel", SIZE_ROW, TEXT)
	_label(t, "RowTitleLabel", SIZE_ROW, TEXT)
	_label(t, "BodyLabel", SIZE_BODY, TEXT_SOFT)
	_label(t, "CaptionLabel", SIZE_CAPTION, MUTED)
	_label(t, "MutedLabel", SIZE_CAPTION, MUTED)
	_label(t, "StatLabel", SIZE_GROUP, TEXT)
	t.set_type_variation("AccentLabel", "Label")
	t.set_color("font_color", "AccentLabel", ACCENT)
	t.set_type_variation("WarnLabel", "Label")
	t.set_color("font_color", "WarnLabel", WARN)

	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	t.set_stylebox("background", "ProgressBar", box(BG_INPUT, Color(0, 0, 0, 0), RADIUS, 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(ENERGY, Color(0, 0, 0, 0), RADIUS, 0, 0, 0))

	t.set_stylebox("normal", "LineEdit", box(BG_INPUT, BORDER, RADIUS, 1, 12, 6))
	t.set_stylebox("focus", "LineEdit", box(BG_INPUT, ACCENT, RADIUS, 1, 12, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", ACCENT)

	t.set_stylebox("panel", "ItemList", box(BG_INPUT, BORDER, RADIUS, 1, 6, 6))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", selected_box(12, 6))
	t.set_stylebox("selected_focus", "ItemList", selected_box(12, 6))
	t.set_stylebox("hovered", "ItemList", box(HOVER, Color(0, 0, 0, 0), RADIUS, 0, 12, 6))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", TEXT)
	t.set_color("font_hovered_color", "ItemList", TEXT)
	t.set_constant("v_separation", "ItemList", 6)

	t.set_stylebox("separator", "HSeparator", _rule(true))
	t.set_stylebox("separator", "VSeparator", _rule(false))
	t.set_stylebox("panel", "TooltipPanel", MapArt.panel_box(12, FRAME))
	t.set_color("font_color", "TooltipLabel", TEXT_SOFT)
	t.set_font_size("font_size", "TooltipLabel", SIZE_CAPTION)

	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t


static func _label(t: Theme, variation: String, size: int, colour: Color) -> void:
	t.set_type_variation(variation, "Label")
	t.set_font_size("font_size", variation, size)
	t.set_color("font_color", variation, colour)


static func _rule(horizontal: bool) -> StyleBoxLine:
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = FRAME_DIM
	line.thickness = 1
	line.vertical = not horizontal
	return line


## The framed panel: Kenney inner rule in iron over the panel fill. The fill is never tinted.
static func panel(content: int = 22) -> StyleBox:
	return MapArt.panel_box(content, FRAME)


## The flat box small panels keep, where a nine-slice frame does not fit.
static func flat_panel() -> StyleBoxFlat:
	return box(BG, BORDER, RADIUS, 1, 24, 18)


## The panel for a modal over a live screen: framed and opaque.
static func modal_panel() -> StyleBox:
	return panel(22)


## The selected state of a tile, row or tab: a raised fill under a 2 px bone ring.
static func selected_box(pad_x: int = 18, pad_y: int = 12) -> StyleBoxFlat:
	return box(BG_ACTIVE, ACCENT, RADIUS, 2, pad_x, pad_y)


## Small square used for Energy, Fervor and progress pips.
static func pip(filled: bool, color: Color, round: bool = false) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = color if filled else Color(1, 1, 1, 0.10)
	b.set_corner_radius_all(7 if round else 2)
	b.anti_aliasing = true
	return b


## A chip on a label. A tag is outlined with tinted text; a badge is filled with dark text.
static func chip(label: Label, color: Color, filled: bool = false) -> void:
	if filled:
		label.add_theme_stylebox_override("normal", box(color, Color(0, 0, 0, 0), RADIUS, 0, 12, 2))
		label.add_theme_color_override("font_color", TEXT_DARK)
	else:
		label.add_theme_stylebox_override("normal", box(Color(color, 0.10), Color(color, 0.55), RADIUS, 1, 12, 2))
		label.add_theme_color_override("font_color", color.lightened(0.15))


## A flat tile with a coloured left edge, tagging a block with a school or a state.
## StyleBoxFlat has one border colour, so the edge is the only border drawn.
static func edged(edge: Color, bg: Color = RAISED, radius: int = RADIUS, pad_x: int = 18, pad_y: int = 12) -> StyleBoxFlat:
	var b: StyleBoxFlat = box(bg, edge, radius, 0, pad_x, pad_y)
	b.border_width_left = 5
	b.content_margin_left = pad_x + 6
	return b


## Motes: the arcane blue with a soft outer glow, for a Motes number or price.
static func motes_label(label: Label) -> void:
	label.add_theme_color_override("font_color", MOTES)
	label.add_theme_color_override("font_shadow_color", Color(MOTES, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 10)
