class_name MapArt
extends RefCounted
## The adventure screens' textures, imported from the art library by tools/import_map_art.py.
## Every lookup is cached; a missing file answers null so a screen still draws without it.
##
## The trim (panel rules, banners, filigree, dividers) is imported as neutral greys and drawn
## through `tint`: white by default, and in the adventure the run's Mastery school colour, set once
## by the screen with `tint_for_school`. Buttons and the map's node markers (Kenney icons on dark
## tiles) keep their own colours.

const DIR: String = "res://assets/adventure_map"
## A school colour is capped at this saturation and brightness before it tints the trim, so the
## hot schools (Pyre, Shade, Storm) come out muted like Tide instead of loud.
const TINT_MAX_SATURATION: float = 0.5
const TINT_MAX_VALUE: float = 0.78
## The panel texture's rule and corner squares, in its own pixels, kept whole when it stretches.
const PANEL_MARGIN: int = 24
## The Kenney half-divider that fades in towards a knot; `fade_divider` mirrors it.
const FADE_DIVIDER: String = "res://assets/ui/borders/default/divider_fade/divider-fade-003.png"
## The same double rule with its knot, unfaded: the map's rule between acts, mirrored the same way.
const DIVIDER: String = "res://assets/ui/borders/default/divider/divider-003.png"
## The divider's knot, in its own (doubled) pixels, kept whole when the rule stretches.
const DIVIDER_KNOT: float = 48.0
## Kenney's corner brackets (border 000), drawn round the node the run stands on or is scouting.
const BRACKETS: String = "res://assets/ui/borders/default/border/panel-border-000.png"
const BRACKET_MARGIN: int = 24

static var tint: Color = Color.WHITE
## The same hue kept saturated, for thin or faint marks (the "here" brackets, the choice glow)
## where the muted `tint` would read as white.
static var tint_strong: Color = Color.WHITE
static var _cache: Dictionary = {}


static func texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[path] = tex
	return tex


static func marker(node_type: String) -> Texture2D:
	return texture("%s/markers/%s.png" % [DIR, node_type])


static func flair(badge: String) -> Texture2D:
	return texture("%s/flairs/%s.png" % [DIR, badge])


static func ui(piece: String) -> Texture2D:
	return texture("%s/ui/%s.png" % [DIR, piece])


## Sets the trim colour from a school: the run's Mastery school in the adventure. An empty
## school, or one Palette does not know, keeps the neutral white.
static func tint_for_school(school: String) -> void:
	if school == "":
		tint = Color.WHITE
		tint_strong = Color.WHITE
		return
	var c: Color = Palette.school_ui(school)
	tint = muted(c)
	tint_strong = Color.from_hsv(c.h, clampf(c.s, 0.65, 0.85), minf(c.v, 0.85))


## Any colour capped the way the trim tint is, so a loud group or school colour sits as quietly
## as the rest of the trim.
static func muted(color: Color) -> Color:
	return Color.from_hsv(color.h, minf(color.s, TINT_MAX_SATURATION), minf(color.v, TINT_MAX_VALUE))


## The button pieces' stepped corners, kept whole when the face stretches (Kenney border 022,
## doubled: 12 px corners become 24).
const BUTTON_MARGIN: int = 24

## Passed as `color` to mean "use the current trim tint".
const USE_TINT: Color = Color(0, 0, 0, 0)


## The default panel: a dark fill under the thin inner rule (Kenney border 012), in `color`, or
## the trim tint when none is given. The shared theme asks for white so it never caches a school.
static func panel_box(content: int, color: Color = USE_TINT) -> StyleBox:
	return _sliced("panel", PANEL_MARGIN, content, tint if color == USE_TINT else color)


## A scroll banner as a StyleBox: the curled ends kept whole, the middle stretched to the text.
static func banner_box(piece: String, pad_x: int = 30, pad_top: int = 8, pad_bottom: int = 12) -> StyleBox:
	var tex: Texture2D = ui(piece)
	if tex == null:
		return StyleBoxEmpty.new()
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = tex
	box.modulate_color = tint
	box.texture_margin_left = 26
	box.texture_margin_right = 26
	box.texture_margin_top = 12
	box.texture_margin_bottom = 16
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_top
	box.content_margin_bottom = pad_bottom
	return box


## One of the filigree pieces as a centred, hard-edged TextureRect, `height` pixels tall.
static func ornament(piece: String, height: float) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = ui(piece)
	rect.self_modulate = tint
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rect.texture != null:
		var aspect: float = float(rect.texture.get_width()) / float(rect.texture.get_height())
		rect.custom_minimum_size = Vector2(height * aspect, height)
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rect


## A centred divider `width` pixels wide: the Kenney half-divider that fades in towards a knot,
## beside its mirror image, in the trim tint.
static func fade_divider(width: float) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = texture(FADE_DIVIDER)
	for mirrored in [false, true]:
		var half: TextureRect = TextureRect.new()
		half.texture = tex
		half.flip_h = mirrored
		half.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		half.stretch_mode = TextureRect.STRETCH_SCALE
		half.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		half.self_modulate = tint
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var aspect: float = float(tex.get_height()) / float(tex.get_width()) if tex != null else 0.2
		half.custom_minimum_size = Vector2(width * 0.5, width * 0.5 * aspect)
		row.add_child(half)
	return row


## Draws the Kenney double rule across `rect`: two halves meeting at their knots in the middle,
## the knots kept whole and the rules stretched to fill. In `color`.
static func draw_divider(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var tex: Texture2D = texture(DIVIDER)
	if tex == null:
		return
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	var knot: float = DIVIDER_KNOT * rect.size.y / th
	var half: float = rect.size.x * 0.5
	var center: Vector2 = Vector2(rect.get_center().x, rect.position.y)
	for side: float in [1.0, -1.0]:
		# The left half as drawn; the right half is the same drawing mirrored about the centre.
		canvas.draw_set_transform(center, 0.0, Vector2(side, 1.0))
		canvas.draw_texture_rect_region(tex, Rect2(-half, 0, maxf(0.0, half - knot), rect.size.y), Rect2(0, 0, tw - DIVIDER_KNOT, th), color)
		canvas.draw_texture_rect_region(tex, Rect2(-knot, 0, knot, rect.size.y), Rect2(tw - DIVIDER_KNOT, 0, DIVIDER_KNOT, th), color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Kenney's corner brackets round `rect`, in `color`, drawn nine-slice so the corners keep their
## size whatever the node's.
static func draw_brackets(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var tex: Texture2D = texture(BRACKETS)
	if tex == null:
		return
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = tex
	box.modulate_color = color
	box.set_texture_margin_all(BRACKET_MARGIN)
	box.draw_center = false
	canvas.draw_style_box(box, rect)


## A button face: Kenney's stepped-corner rule over a flat fill, one piece per state, composed by
## tools/import_map_art.py. Never tinted. The face is flat, so the text centres on it and drops a
## pixel when pressed.
static func button_box(piece: String) -> StyleBox:
	var box: StyleBox = _sliced(piece, BUTTON_MARGIN, 0, Color.WHITE)
	box.content_margin_left = 24
	box.content_margin_right = 24
	var pressed: bool = piece.ends_with("_pressed")
	box.content_margin_top = 13 if pressed else 12
	box.content_margin_bottom = 11 if pressed else 12
	return box


static func _sliced(piece: String, margin: int, content: int, color: Color) -> StyleBox:
	var tex: Texture2D = ui(piece)
	if tex == null:
		return StyleBoxEmpty.new()
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = tex
	box.modulate_color = color
	box.set_texture_margin_all(margin)
	box.set_content_margin_all(content)
	return box
