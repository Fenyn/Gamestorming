class_name ZenithTheme
extends RefCounted
## One dark theme with a single gold accent, built once at runtime and applied to every screen.
## Type variations: AccentButton, TitleLabel, HeaderLabel, MutedLabel, AccentLabel, StatLabel,
## TileButton, Chip (Panel).
##
## Colour roles. Gold is reserved for "act here": the current step, legal cards, primary buttons,
## Fervor. Green is Energy. Warm red is an attack in progress, blue a defence. Orange is a warning
## the player must read (a deck problem, a must-pass flag). School colours mark identity only.

const BG: Color = Color(0.08, 0.08, 0.10, 0.90)
const BG_INPUT: Color = Color(0.0, 0.0, 0.0, 0.35)
const BORDER: Color = Color(1.0, 1.0, 1.0, 0.10)
const ACCENT: Color = Color(0.86, 0.69, 0.27)
const ACCENT_SOFT: Color = Color(0.86, 0.69, 0.27, 0.30)
const ENERGY: Color = Color(0.36, 0.76, 0.58)
const ENERGY_SOFT: Color = Color(0.36, 0.76, 0.58, 0.22)
const MIGHT: Color = Color(0.78, 0.82, 0.90)
const ATTACK: Color = Color(0.90, 0.38, 0.30)
const ATTACK_SOFT: Color = Color(0.90, 0.38, 0.30, 0.22)
const DEFEND: Color = Color(0.40, 0.62, 0.92)
const DEFEND_SOFT: Color = Color(0.40, 0.62, 0.92, 0.22)
const WARN: Color = Color(0.95, 0.60, 0.25)
const WARN_SOFT: Color = Color(0.95, 0.60, 0.25, 0.20)
const TEXT: Color = Color(0.93, 0.91, 0.87)
const TEXT_DARK: Color = Color(0.12, 0.10, 0.06)
const MUTED: Color = Color(0.60, 0.60, 0.65)
const HOVER: Color = Color(1.0, 1.0, 1.0, 0.12)
const RAISED: Color = Color(1.0, 1.0, 1.0, 0.06)
const RAISED_STRONG: Color = Color(1.0, 1.0, 1.0, 0.10)

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 8, border_width: int = 1, pad_x: int = 10, pad_y: int = 6) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_width if border.a > 0.0 else 0)
	b.set_corner_radius_all(radius)
	b.content_margin_left = pad_x
	b.content_margin_right = pad_x
	b.content_margin_top = pad_y
	b.content_margin_bottom = pad_y
	b.anti_aliasing = true
	return b


static func build() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = 15

	t.set_stylebox("panel", "PanelContainer", box(BG, BORDER, 12, 1, 14, 12))
	t.set_stylebox("panel", "Panel", box(BG, BORDER, 12, 1, 0, 0))
	t.set_type_variation("Chip", "Panel")
	t.set_stylebox("panel", "Chip", box(RAISED, Color(0, 0, 0, 0), 6, 0, 0, 0))

	t.set_stylebox("normal", "Button", box(RAISED, BORDER, 8, 1, 12, 7))
	t.set_stylebox("hover", "Button", box(HOVER, BORDER, 8, 1, 12, 7))
	t.set_stylebox("pressed", "Button", box(ACCENT_SOFT, ACCENT, 8, 1, 12, 7))
	t.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.05), 8, 1, 12, 7))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)

	t.set_type_variation("AccentButton", "Button")
	t.set_stylebox("normal", "AccentButton", box(ACCENT, Color(0, 0, 0, 0), 8, 0, 14, 8))
	t.set_stylebox("hover", "AccentButton", box(ACCENT.lightened(0.12), Color(0, 0, 0, 0), 8, 0, 14, 8))
	t.set_stylebox("pressed", "AccentButton", box(ACCENT.darkened(0.18), Color(0, 0, 0, 0), 8, 0, 14, 8))
	t.set_stylebox("disabled", "AccentButton", box(ACCENT_SOFT, Color(0, 0, 0, 0), 8, 0, 14, 8))
	t.set_color("font_color", "AccentButton", TEXT_DARK)
	t.set_color("font_hover_color", "AccentButton", TEXT_DARK)
	t.set_color("font_pressed_color", "AccentButton", TEXT_DARK)
	t.set_color("font_focus_color", "AccentButton", TEXT_DARK)
	t.set_color("font_disabled_color", "AccentButton", Color(TEXT_DARK, 0.6))

	t.set_color("font_color", "Label", TEXT)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font_size("font_size", "TitleLabel", 44)
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font_size("font_size", "HeaderLabel", 20)
	t.set_type_variation("MutedLabel", "Label")
	t.set_font_size("font_size", "MutedLabel", 13)
	t.set_color("font_color", "MutedLabel", MUTED)
	t.set_type_variation("AccentLabel", "Label")
	t.set_color("font_color", "AccentLabel", ACCENT)
	t.set_type_variation("StatLabel", "Label")
	t.set_font_size("font_size", "StatLabel", 24)
	t.set_type_variation("WarnLabel", "Label")
	t.set_color("font_color", "WarnLabel", WARN)

	# Selectable tile: a quiet card that lights up with the accent border when chosen.
	t.set_type_variation("TileButton", "Button")
	t.set_stylebox("normal", "TileButton", box(RAISED, BORDER, 10, 1, 14, 10))
	t.set_stylebox("hover", "TileButton", box(HOVER, Color(1, 1, 1, 0.22), 10, 1, 14, 10))
	t.set_stylebox("pressed", "TileButton", box(ACCENT_SOFT, ACCENT, 10, 2, 14, 10))
	t.set_stylebox("disabled", "TileButton", box(RAISED, BORDER, 10, 1, 14, 10))
	t.set_stylebox("focus", "TileButton", StyleBoxEmpty.new())
	t.set_color("font_color", "TileButton", TEXT)
	t.set_color("font_hover_color", "TileButton", TEXT)
	t.set_color("font_pressed_color", "TileButton", TEXT)
	t.set_color("font_focus_color", "TileButton", TEXT)

	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	t.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 4, 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(ENERGY, Color(0, 0, 0, 0), 4, 0, 0, 0))

	t.set_stylebox("normal", "LineEdit", box(BG_INPUT, BORDER, 6, 1, 10, 6))
	t.set_stylebox("focus", "LineEdit", box(BG_INPUT, ACCENT, 6, 1, 10, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", ACCENT)

	t.set_stylebox("panel", "ItemList", box(BG_INPUT, BORDER, 8, 1, 6, 6))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", box(ACCENT_SOFT, ACCENT, 6, 1, 8, 4))
	t.set_stylebox("selected_focus", "ItemList", box(ACCENT_SOFT, ACCENT, 6, 1, 8, 4))
	t.set_stylebox("hovered", "ItemList", box(HOVER, Color(0, 0, 0, 0), 6, 0, 8, 4))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", TEXT)
	t.set_color("font_hovered_color", "ItemList", TEXT)
	t.set_constant("v_separation", "ItemList", 6)

	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t


## Small rounded square used for Energy and Fervor pips.
static func pip(filled: bool, color: Color, round: bool = false) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = color if filled else Color(1, 1, 1, 0.10)
	b.set_corner_radius_all(7 if round else 3)
	b.anti_aliasing = true
	return b


## Applies a small tinted chip style to a label: soft fill of `color`, text in `color`.
static func chip(label: Label, color: Color, filled: bool = false) -> void:
	if filled:
		label.add_theme_stylebox_override("normal", box(color, Color(0, 0, 0, 0), 5, 0, 8, 2))
		label.add_theme_color_override("font_color", TEXT_DARK)
	else:
		label.add_theme_stylebox_override("normal", box(Color(color, 0.18), Color(0, 0, 0, 0), 5, 0, 8, 2))
		label.add_theme_color_override("font_color", color.lightened(0.15))


## Panel style with a coloured left edge, used to tag a block with a school or a state.
## StyleBoxFlat has one border colour, so the edge is the only border drawn.
static func edged(edge: Color, bg: Color = BG, radius: int = 12, pad_x: int = 14, pad_y: int = 12) -> StyleBoxFlat:
	var b: StyleBoxFlat = box(bg, edge, radius, 0, pad_x, pad_y)
	b.border_width_left = 5
	b.content_margin_left = pad_x + 4
	return b
