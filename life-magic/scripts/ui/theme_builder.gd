class_name ThemeBuilder

const BG_DARK := Color(0.08, 0.12, 0.08)
const BG_PANEL := Color(0.11, 0.16, 0.11)
const BG_PANEL_HOVER := Color(0.14, 0.20, 0.14)
const BG_BUTTON := Color(0.15, 0.22, 0.13)
const BG_BUTTON_HOVER := Color(0.2, 0.3, 0.18)
const BG_BUTTON_PRESSED := Color(0.12, 0.18, 0.1)
const BG_BUTTON_DISABLED := Color(0.1, 0.12, 0.1)
const BG_TAB_ACTIVE := Color(0.16, 0.24, 0.14)
const BG_TAB_INACTIVE := Color(0.09, 0.13, 0.09)

const BG_GLASS := Color(0.09, 0.13, 0.09, 0.78)
const BG_GLASS_CARD := Color(0.09, 0.14, 0.09, 0.82)

const TEXT_PRIMARY := Color(0.88, 0.95, 0.85)
const TEXT_SECONDARY := Color(0.55, 0.68, 0.52)
const TEXT_MUTED := Color(0.4, 0.48, 0.38)
const TEXT_DISABLED := Color(0.3, 0.35, 0.28)
const TEXT_GREEN := Color(0.45, 0.8, 0.4)
const TEXT_GOLD := Color(0.9, 0.72, 0.15)

const ACCENT_GREEN := Color(0.3, 0.55, 0.25)
const ACCENT_RED := Color(0.8, 0.15, 0.15)
const BORDER := Color(0.18, 0.26, 0.16)

const TIER_COLORS := [
	Color(0.9, 0.3, 0.3),
	Color(0.9, 0.6, 0.2),
	Color(0.4, 0.8, 0.3),
	Color(0.3, 0.7, 0.7),
	Color(0.5, 0.4, 0.9),
]


static func get_tier_color(tier: int) -> Color:
	if tier >= 0 and tier < TIER_COLORS.size():
		return TIER_COLORS[tier]
	return TEXT_PRIMARY


static func create_panel_style(border_color: Color = BORDER, border_left: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_GLASS_CARD
	style.border_color = border_color
	style.border_width_bottom = 1
	style.border_width_left = border_left
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func create_tab_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_TAB_ACTIVE if active else BG_TAB_INACTIVE
	style.border_color = ACCENT_GREEN if active else BORDER
	style.border_width_bottom = 3 if active else 1
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func create_bottom_tab_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.1, 0.92) if active else Color(0.06, 0.09, 0.06, 0.85)
	style.border_color = ACCENT_GREEN if active else Color(0, 0, 0, 0)
	style.border_width_top = 3 if active else 0
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 4
	style.content_margin_right = 4
	return style


static func create_pill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.75)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


const BAR_BG := Color(0.1, 0.14, 0.1)
const BAR_FILL := Color(0.3, 0.6, 0.25)

const BG_VITALS := Color(0.06, 0.04, 0.08)
const BG_VITALS_BOTTOM := Color(0.08, 0.12, 0.08)


static func build() -> Theme:
	var theme := Theme.new()

	var font := load("res://resources/fonts/game_font.tres") as Font
	if font:
		theme.set_default_font(font)

	theme.set_color("font_color", "Label", TEXT_PRIMARY)
	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", Color(0.95, 1.0, 0.9))
	theme.set_color("font_pressed_color", "Button", TEXT_GREEN)
	theme.set_color("font_disabled_color", "Button", TEXT_DISABLED)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = BG_GLASS
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.border_color = BORDER
	panel_style.border_width_bottom = 1
	panel_style.content_margin_left = 4
	panel_style.content_margin_right = 4
	panel_style.content_margin_top = 4
	panel_style.content_margin_bottom = 4
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = BG_BUTTON
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.border_color = ACCENT_GREEN
	btn_normal.border_width_bottom = 2
	btn_normal.content_margin_left = 10
	btn_normal.content_margin_right = 10
	btn_normal.content_margin_top = 6
	btn_normal.content_margin_bottom = 6
	theme.set_stylebox("normal", "Button", btn_normal)

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = BG_BUTTON_HOVER
	theme.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = BG_BUTTON_PRESSED
	btn_pressed.border_width_bottom = 1
	btn_pressed.border_width_top = 1
	theme.set_stylebox("pressed", "Button", btn_pressed)

	var btn_disabled := btn_normal.duplicate()
	btn_disabled.bg_color = BG_BUTTON_DISABLED
	btn_disabled.border_color = Color(0.15, 0.18, 0.13)
	btn_disabled.border_width_bottom = 1
	theme.set_stylebox("disabled", "Button", btn_disabled)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = BAR_BG
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	theme.set_stylebox("background", "ProgressBar", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = BAR_FILL
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	theme.set_stylebox("fill", "ProgressBar", bar_fill)

	var sep := StyleBoxFlat.new()
	sep.bg_color = BORDER
	sep.content_margin_top = 1
	sep.content_margin_bottom = 1
	theme.set_stylebox("separator", "HSeparator", sep)
	theme.set_constant("separation", "HSeparator", 1)

	return theme
