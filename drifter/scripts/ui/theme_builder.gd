class_name ThemeBuilder

const BG_DARK := Color(0.06, 0.06, 0.10)
const BG_PANEL := Color(0.10, 0.10, 0.16)
const BG_MODULE := Color(0.08, 0.12, 0.18, 0.90)
const BG_SOCKET_EMPTY := Color(0.15, 0.15, 0.22)
const BG_SOCKET_VALID := Color(0.15, 0.30, 0.20)
const BG_SOCKET_FILLED := Color(0.25, 0.30, 0.40)
const BG_SOCKET_INVALID := Color(0.30, 0.12, 0.12)

const TEXT_PRIMARY := Color(0.85, 0.90, 0.95)
const TEXT_SECONDARY := Color(0.50, 0.60, 0.70)
const TEXT_DAMAGE := Color(0.90, 0.30, 0.20)
const TEXT_HEAL := Color(0.30, 0.80, 0.40)
const TEXT_SHIELD := Color(0.30, 0.70, 0.85)

const HP_TEAL := Color(0.20, 0.75, 0.70)
const HP_RED := Color(0.75, 0.15, 0.15)
const ACCENT_GLOW := Color(0.40, 0.80, 0.90)
const BORDER := Color(0.20, 0.25, 0.30)


static func create_flat_style(
	bg: Color = BG_PANEL,
	border_color: Color = BORDER,
	border_width: int = 1,
	corner_radius: int = 2,
	content_margin: int = 4,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(content_margin)
	return style


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14

	var panel_style: StyleBoxFlat = create_flat_style(BG_PANEL, BORDER)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	var button_normal: StyleBoxFlat = create_flat_style(
		Color(0.12, 0.14, 0.20), BORDER, 1, 3, 8
	)
	var button_hover: StyleBoxFlat = create_flat_style(
		Color(0.16, 0.20, 0.28), ACCENT_GLOW, 1, 3, 8
	)
	var button_pressed: StyleBoxFlat = create_flat_style(
		Color(0.08, 0.10, 0.14), ACCENT_GLOW, 2, 3, 8
	)
	var button_disabled: StyleBoxFlat = create_flat_style(
		Color(0.08, 0.08, 0.10), Color(0.15, 0.15, 0.18), 1, 3, 8
	)
	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("disabled", "Button", button_disabled)

	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", ACCENT_GLOW)
	theme.set_color("font_pressed_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "Button", TEXT_SECONDARY)

	theme.set_color("font_color", "Label", TEXT_PRIMARY)

	var progress_bg: StyleBoxFlat = create_flat_style(
		Color(0.08, 0.08, 0.12), BORDER, 1, 1, 0
	)
	var progress_fill: StyleBoxFlat = create_flat_style(
		HP_TEAL, HP_TEAL, 0, 1, 0
	)
	theme.set_stylebox("background", "ProgressBar", progress_bg)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)

	return theme
