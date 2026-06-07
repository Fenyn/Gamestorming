class_name FarmTheme
extends Node

const UI_SHEET_PATH: String = "res://assets/UI/Modern_UI_Style_1_48x48.png"
const FONT_COLOR: Color = Color(0.25, 0.2, 0.15, 1)
const FONT_COLOR_HOVER: Color = Color(0.15, 0.1, 0.05, 1)
const FONT_COLOR_DISABLED: Color = Color(0.5, 0.45, 0.4, 1)
const SEPARATOR_COLOR: Color = Color(0.4, 0.32, 0.2, 0.6)

const PANEL_REGION: Rect2 = Rect2(0, 0, 144, 144)
const PANEL_MARGIN: int = 14
const SUBPANEL_REGION: Rect2 = Rect2(0, 144, 144, 144)
const SUBPANEL_MARGIN: int = 12
const BUTTON_REGION: Rect2 = Rect2(0, 528, 144, 96)
const BUTTON_HOVER_REGION: Rect2 = Rect2(144, 528, 144, 96)
const BUTTON_MARGIN: int = 12
const SLOT_REGION: Rect2 = Rect2(0, 288, 144, 144)
const SLOT_MARGIN: int = 8


static func create_theme() -> Theme:
	var sheet: Texture2D = preload(UI_SHEET_PATH)
	var theme: Theme = Theme.new()

	theme.set_stylebox("panel", "PanelContainer", _make_nine_patch(sheet, PANEL_REGION, PANEL_MARGIN, 6))
	theme.set_stylebox("panel", "Panel", _make_nine_patch(sheet, PANEL_REGION, PANEL_MARGIN, 6))

	theme.set_stylebox("normal", "Button", _make_nine_patch(sheet, BUTTON_REGION, BUTTON_MARGIN, 4))
	theme.set_stylebox("hover", "Button", _make_nine_patch(sheet, BUTTON_HOVER_REGION, BUTTON_MARGIN, 4))
	theme.set_stylebox("pressed", "Button", _make_nine_patch(sheet, SUBPANEL_REGION, SUBPANEL_MARGIN, 4))
	var btn_disabled: StyleBoxTexture = _make_nine_patch(sheet, BUTTON_REGION, BUTTON_MARGIN, 4)
	btn_disabled.modulate_color = Color(0.6, 0.6, 0.6, 0.7)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	theme.set_color("font_color", "Button", FONT_COLOR)
	theme.set_color("font_hover_color", "Button", FONT_COLOR_HOVER)
	theme.set_color("font_pressed_color", "Button", FONT_COLOR)
	theme.set_color("font_disabled_color", "Button", FONT_COLOR_DISABLED)

	theme.set_color("font_color", "Label", Color(0.9, 0.85, 0.7, 1))

	var sep_style: StyleBoxFlat = StyleBoxFlat.new()
	sep_style.bg_color = SEPARATOR_COLOR
	sep_style.content_margin_top = 1.0
	sep_style.content_margin_bottom = 1.0
	theme.set_stylebox("separator", "HSeparator", sep_style)
	theme.set_constant("separation", "HSeparator", 8)

	return theme


static func make_slot_style(selected: bool) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	if selected:
		s.bg_color = Color(0.3, 0.25, 0.15, 0.95)
		s.border_color = Color(0.85, 0.7, 0.4, 0.9)
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 2
	else:
		s.bg_color = Color(0.15, 0.12, 0.1, 0.85)
		s.border_color = Color(0.4, 0.32, 0.22, 0.6)
		s.border_width_left = 1
		s.border_width_top = 1
		s.border_width_right = 1
		s.border_width_bottom = 1
	s.corner_radius_top_left = 3
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	s.content_margin_left = 2
	s.content_margin_top = 2
	s.content_margin_right = 2
	s.content_margin_bottom = 2
	return s


static func _make_nine_patch(sheet: Texture2D, region: Rect2, margin: int, content_pad: int = 4) -> StyleBoxTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region

	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = atlas
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = content_pad
	style.content_margin_top = content_pad
	style.content_margin_right = content_pad
	style.content_margin_bottom = content_pad
	return style
