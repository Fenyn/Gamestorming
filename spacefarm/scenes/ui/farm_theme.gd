class_name FarmTheme
extends Node

const PANEL_BG: Color = Color(0.22, 0.18, 0.14, 0.92)
const PANEL_BORDER: Color = Color(0.45, 0.35, 0.22, 1)
const BUTTON_NORMAL_BG: Color = Color(0.35, 0.28, 0.18, 0.9)
const BUTTON_HOVER_BG: Color = Color(0.42, 0.34, 0.22, 0.95)
const BUTTON_PRESSED_BG: Color = Color(0.25, 0.2, 0.13, 0.95)
const BUTTON_DISABLED_BG: Color = Color(0.2, 0.18, 0.15, 0.7)
const BUTTON_BORDER: Color = Color(0.5, 0.4, 0.25, 1)
const FONT_COLOR: Color = Color(0.9, 0.85, 0.7, 1)
const FONT_COLOR_DIM: Color = Color(0.6, 0.55, 0.45, 1)
const FONT_COLOR_DISABLED: Color = Color(0.45, 0.4, 0.35, 1)
const SEPARATOR_COLOR: Color = Color(0.4, 0.32, 0.2, 0.6)
const CORNER_RADIUS: int = 4
const BORDER_WIDTH: int = 2


static func create_theme() -> Theme:
	var theme: Theme = Theme.new()

	theme.set_stylebox("panel", "PanelContainer", _make_panel())
	theme.set_stylebox("panel", "Panel", _make_panel())

	theme.set_stylebox("normal", "Button", _make_button(BUTTON_NORMAL_BG))
	theme.set_stylebox("hover", "Button", _make_button(BUTTON_HOVER_BG))
	theme.set_stylebox("pressed", "Button", _make_button(BUTTON_PRESSED_BG))
	theme.set_stylebox("disabled", "Button", _make_button(BUTTON_DISABLED_BG))

	theme.set_color("font_color", "Button", FONT_COLOR)
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.8, 1))
	theme.set_color("font_pressed_color", "Button", Color(0.8, 0.75, 0.6, 1))
	theme.set_color("font_disabled_color", "Button", FONT_COLOR_DISABLED)

	theme.set_color("font_color", "Label", FONT_COLOR)

	theme.set_stylebox("separator", "HSeparator", _make_separator())
	theme.set_constant("separation", "HSeparator", 8)

	theme.set_stylebox("panel", "ScrollContainer", _make_scroll_bg())

	var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
	theme.set_stylebox("scroll", "HScrollBar", empty_style)
	theme.set_stylebox("scroll", "VScrollBar", empty_style)

	return theme


static func _make_panel() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.border_color = PANEL_BORDER
	s.border_width_left = BORDER_WIDTH
	s.border_width_top = BORDER_WIDTH
	s.border_width_right = BORDER_WIDTH
	s.border_width_bottom = BORDER_WIDTH
	s.corner_radius_top_left = CORNER_RADIUS
	s.corner_radius_top_right = CORNER_RADIUS
	s.corner_radius_bottom_left = CORNER_RADIUS
	s.corner_radius_bottom_right = CORNER_RADIUS
	s.content_margin_left = 8.0
	s.content_margin_top = 6.0
	s.content_margin_right = 8.0
	s.content_margin_bottom = 6.0
	return s


static func _make_button(bg: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = BUTTON_BORDER
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 3
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	s.content_margin_left = 8.0
	s.content_margin_top = 4.0
	s.content_margin_right = 8.0
	s.content_margin_bottom = 4.0
	return s


static func _make_separator() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = SEPARATOR_COLOR
	s.content_margin_top = 1.0
	s.content_margin_bottom = 1.0
	return s


static func _make_scroll_bg() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.15, 0.12, 0.1, 0.3)
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_left = 2
	s.corner_radius_bottom_right = 2
	return s
