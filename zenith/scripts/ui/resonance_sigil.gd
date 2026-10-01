class_name ResonanceSigil
extends Control
## A Resonance's round medallion: its pixel sigil on a dark disc inside an iron ring, the ring
## bone-white while `lit`. The Shrine draws it large; the duel board draws the same medallion
## through `draw_medallion` on its printed canvas.

## The sigil's share of the disc's width.
const ICON_SHARE: float = 0.62

@export var resonance: String = "":
	set(value):
		resonance = value
		queue_redraw()
@export var lit: bool = false:
	set(value):
		lit = value
		queue_redraw()

static var _textures: Dictionary = {}


## The sigil art alone, loaded once. Null for an id with no art.
static func texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var path: String = ResonanceData.icon_of(id)
	var tex: Texture2D = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	_textures[id] = tex
	return tex


## Draws the medallion for `id` onto `canvas`, centred on `center`.
static func draw_medallion(canvas: CanvasItem, center: Vector2, radius: float, id: String, lit_ring: bool) -> void:
	var ring: float = maxf(2.0, radius * 0.06)
	canvas.draw_circle(center, radius, ZenithTheme.BG_SCREEN)
	canvas.draw_arc(center, radius - ring * 0.5, 0.0, TAU, 64, ZenithTheme.ACCENT if lit_ring else ZenithTheme.FRAME, ring, true)
	var tex: Texture2D = texture(id)
	if tex == null:
		return
	var side: float = radius * 2.0 * ICON_SHARE
	canvas.draw_texture_rect(tex, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	if resonance == "":
		return
	draw_medallion(self, size * 0.5, minf(size.x, size.y) * 0.5 - 1.0, resonance, lit)
