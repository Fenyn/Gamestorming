class_name UiStyle
extends RefCounted

## Green Bean's UI tokens and the project theme built from them.
## Palette: dark roast panels with crema text, the sage and olive of raw coffee
## beans as the one accent (olive is also the stand's trim and sign frame), amber for warnings, red for failures, receipt paper and ink for the
## cup ticket. One family (Nunito) at a few weights. Sizes are for the
## 1920 x 1080 base viewport.
## Styleboxes come from godot_base's StyleFactory. tools/build_ui_theme.gd saves
## build_theme() to assets/ui/ui_theme.tres, the project theme; edit that file
## in the editor to tune styles, and these constants for code-drawn parts.

const FONT_PATH := "res://assets/fonts/nunito/Nunito.ttf"
const THEME_PATH := "res://assets/ui/ui_theme.tres"

const ROAST := Color("231915")
const ROAST_RAISED := Color("3a2b22")
const CREMA := Color("f3e9d7")
const STEAM := Color("b5a491")
## Sage and olive: the colour of unroasted (green) coffee beans.
const SAGE := Color("a3a77b")
const OLIVE := Color("5e683e")
const AMBER := Color("e8a93f")
const RED := Color("dc6249")
const PAPER := Color("faf6ee")
const INK := Color("2b241f")
const INK_SOFT := Color("9a8f84")
const PANEL_ALPHA := 0.88

const SIZE_SMALL := 17
const SIZE_BODY := 21
const SIZE_LEAD := 26
const SIZE_TITLE := 36
const SIZE_DISPLAY := 52
const SIZE_HERO := 96

const W_REGULAR := 560
const W_BOLD := 760
const W_BLACK := 920

const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 12
const SPACE_L := 16
const SPACE_XL := 24
const SPACE_XXL := 36
## Distance from the screen edge to HUD elements.
const SCREEN_MARGIN := 28

const RADIUS_KEY := 7
const RADIUS_PANEL := 14
const RADIUS_PAPER := 3

## Theme type variations, set with theme_type_variation.
const HUD_CHIP := &"HudChip"
const HUD_PANEL := &"HudPanel"
const TICKET_PANEL := &"TicketPanel"
const KEY_CAP := &"KeyCap"
const KEY_CAP_LABEL := &"KeyCapLabel"
const HUD_VALUE := &"HudValue"
const HUD_MUTED := &"HudMuted"
const HUD_FLOAT := &"HudFloat"
const PROMPT_NAME := &"PromptName"
const TICKET_CODE := &"TicketCode"
const TICKET_TEXT := &"TicketText"
const TICKET_MUTED := &"TicketMuted"
const HEADING := &"Heading"
const DISPLAY := &"Display"
const TITLE := &"Title"

static var _fonts := {}

## Nunito at a weight (200 to 1000), cached.
static func font(weight: int = W_REGULAR) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var base := load(FONT_PATH) as FontFile
	var v := FontVariation.new()
	v.base_font = base
	var ts := TextServerManager.get_primary_interface()
	v.variation_opentype = {ts.name_to_tag("wght"): weight}
	_fonts[weight] = v
	return v

## Styles a world label (Label3D) to match the HUD: Nunito with a roast outline.
static func world_label(l: Label3D, weight: int = W_BOLD, color: Color = CREMA) -> void:
	l.font = font(weight)
	l.modulate = color
	l.outline_modulate = Color(ROAST, 0.85)
	l.outline_size = maxi(l.outline_size, 8)

static func _panel(bg: Color, radius: int, margin_h: int, margin_v: int) -> StyleBoxFlat:
	var s := StyleFactory.flat_no_border(bg, radius, margin_h)
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s

static func _label_type(theme: Theme, type: StringName, size: int, weight: int, color: Color, shadow := false) -> void:
	theme.set_type_variation(type, &"Label")
	theme.set_font(&"font", type, font(weight))
	theme.set_font_size(&"font_size", type, size)
	theme.set_color(&"font_color", type, color)
	if shadow:
		theme.set_color(&"font_shadow_color", type, Color(0, 0, 0, 0.55))
		theme.set_constant(&"shadow_offset_x", type, 0)
		theme.set_constant(&"shadow_offset_y", type, 2)
		theme.set_constant(&"shadow_outline_size", type, 6)

static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(W_REGULAR)
	t.default_font_size = SIZE_BODY

	t.set_color(&"font_color", &"Label", CREMA)
	t.set_constant(&"line_spacing", &"Label", 2)

	# Panels
	t.set_stylebox(&"panel", &"PanelContainer", _panel(Color(ROAST, PANEL_ALPHA), RADIUS_PANEL, SPACE_XL, SPACE_L))
	t.set_type_variation(HUD_PANEL, &"PanelContainer")
	t.set_stylebox(&"panel", HUD_PANEL, _panel(Color(ROAST, PANEL_ALPHA), RADIUS_PANEL, SPACE_XL, SPACE_L))
	t.set_type_variation(HUD_CHIP, &"PanelContainer")
	var chip := StyleFactory.pill(Color(ROAST, PANEL_ALPHA), SPACE_L, SPACE_XS + 2)
	chip.set_corner_radius_all(22)
	t.set_stylebox(&"panel", HUD_CHIP, chip)
	t.set_type_variation(TICKET_PANEL, &"PanelContainer")
	var paper := _panel(PAPER, RADIUS_PAPER, SPACE_L + 2, SPACE_M)
	paper.corner_radius_bottom_left = 0
	paper.corner_radius_bottom_right = 0
	paper.shadow_color = Color(0, 0, 0, 0.28)
	paper.shadow_size = 10
	paper.shadow_offset = Vector2(0, 4)
	t.set_stylebox(&"panel", TICKET_PANEL, paper)
	# Key caps: crema top with a deeper bottom edge, like a real key.
	t.set_type_variation(KEY_CAP, &"PanelContainer")
	var cap := StyleFactory.flat(CREMA, STEAM.darkened(0.25), 0, RADIUS_KEY, SPACE_S)
	cap.border_width_bottom = 3
	cap.content_margin_top = 1
	cap.content_margin_bottom = 2
	cap.content_margin_left = SPACE_S + 1
	cap.content_margin_right = SPACE_S + 1
	t.set_stylebox(&"panel", KEY_CAP, cap)

	# Labels
	_label_type(t, KEY_CAP_LABEL, SIZE_SMALL, W_BLACK, INK)
	_label_type(t, HUD_VALUE, SIZE_LEAD, W_BLACK, CREMA)
	_label_type(t, HUD_MUTED, SIZE_SMALL, W_BOLD, STEAM)
	_label_type(t, HUD_FLOAT, SIZE_BODY, W_BOLD, CREMA, true)
	_label_type(t, PROMPT_NAME, SIZE_SMALL, W_BOLD, CREMA, true)
	_label_type(t, TICKET_CODE, SIZE_DISPLAY, W_BLACK, INK)
	_label_type(t, TICKET_TEXT, SIZE_BODY, W_BOLD, INK)
	_label_type(t, TICKET_MUTED, SIZE_BODY, W_REGULAR, INK_SOFT)
	_label_type(t, HEADING, SIZE_TITLE, W_BLACK, CREMA)
	_label_type(t, DISPLAY, SIZE_DISPLAY, W_BLACK, CREMA)
	_label_type(t, TITLE, SIZE_HERO, W_BLACK, CREMA)

	# Buttons: roast at rest, olive when hovered or pressed.
	t.set_font(&"font", &"Button", font(W_BOLD))
	t.set_font_size(&"font_size", &"Button", SIZE_LEAD)
	t.set_color(&"font_color", &"Button", CREMA)
	t.set_color(&"font_hover_color", &"Button", CREMA)
	t.set_color(&"font_pressed_color", &"Button", CREMA)
	t.set_color(&"font_focus_color", &"Button", CREMA)
	t.set_color(&"font_disabled_color", &"Button", Color(STEAM, 0.55))
	t.set_stylebox(&"normal", &"Button", _panel(ROAST_RAISED, RADIUS_PANEL - 4, SPACE_XL, SPACE_S + 2))
	t.set_stylebox(&"hover", &"Button", _panel(OLIVE, RADIUS_PANEL - 4, SPACE_XL, SPACE_S + 2))
	t.set_stylebox(&"pressed", &"Button", _panel(OLIVE.darkened(0.2), RADIUS_PANEL - 4, SPACE_XL, SPACE_S + 2))
	t.set_stylebox(&"disabled", &"Button", _panel(Color(ROAST_RAISED, 0.5), RADIUS_PANEL - 4, SPACE_XL, SPACE_S + 2))
	var focus := StyleFactory.flat(Color.TRANSPARENT, SAGE, 2, RADIUS_PANEL - 4, 0)
	t.set_stylebox(&"focus", &"Button", focus)

	# Tooltips
	t.set_stylebox(&"panel", &"TooltipPanel", _panel(Color(ROAST, 0.95), RADIUS_KEY, SPACE_M, SPACE_S))
	t.set_color(&"font_color", &"TooltipLabel", CREMA)
	t.set_font_size(&"font_size", &"TooltipLabel", SIZE_SMALL)
	return t

## Colour for a 0..5 star review.
static func star_color(stars: float) -> Color:
	if stars >= 4.5:
		return AMBER
	if stars >= 3.0:
		return CREMA
	return RED
