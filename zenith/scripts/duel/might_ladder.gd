class_name MightLadder
extends Control
## The Might ladder down a personality face: stages 10 to 0 with their printed Might, the Strike
## Table band letters in the gutter, and the printed Surge over the rungs.
##
## The live layer marks a personality in play: filled rungs up to its Energy, the current stage as
## a pill with the live Might, and the Surge rail up to the rung the next Recover reaches. With
## `printed` off only the live layer draws, as an overlay on a cached face.

signal changed

const STAGES: int = CardInstance.MAX_STAGE
const GUTTER: float = 24.0          # band letters, left of the box
const HEADER: float = 30.0         # the printed Surge line over the rungs
const FOOT: float = 4.0
const ROW_INSET: float = 3.0
const STAGE_WIDTH: float = 24.0     # the stage number's column at the box's left
const VALUE_PAD: float = 10.0
const STAGE_FONT: int = 11
const MIGHT_FONT: int = 27
const LIT_STAGE_FONT: int = 15
const LIT_MIGHT_FONT: int = 34
const BAND_FONT: int = 15
const HEADER_FONT: int = 17
const DELTA_FONT: int = 17
const OVERHANG: float = 8.0         # how far the lit pill reaches past the box on each side
const RAIL_WIDTH: float = 8.0
const RAIL_CORE: float = 3.0
const TICK: float = 7.0
const PALE: float = 0.42           # how far the filled rungs lean from the paper to the Mastery colour
const RIM_DARKEN: float = 0.45
const FLASH_LIGHTEN: float = 0.45
const PAPER: Color = Color(0.818, 0.781, 0.698)   # CardFace.CREAM darkened 0.07, the inset panels
const INK: Color = CardFace.INK

@export var printed: bool = true
var flash: float = 0.0:
	set(value):
		if not is_equal_approx(flash, value):
			flash = value
			_touch()
var _might: Array[int] = []         # by stage; -1 where the card prints nothing
var _bands: Array[String] = []      # by stage; the band letter where a band starts, else ""
var _surge: int = 0
var _lit: Color = CardFace.LIT_FALLBACK
var _energy: int = -1
var _live_might: int = -1
var _reach: int = -1
var _preview: int = 0
var _box_style: StyleBoxFlat = null


## The printed ladder of `def` at `aspect`, lit in the colour of the deck `backdrop` names.
func show_card(def: CardDef, aspect: int, backdrop: Color) -> void:
	var t: int = def.aspect if def.aspect > 0 else aspect
	var td: Dictionary = def.aspect_data(t)
	var raw: Array = td.get("might", [])
	var might: Array[int] = []
	var bands: Array[String] = []
	bands.resize(STAGES + 1)
	bands.fill("")
	var prev_band: int = -1
	for stage in range(STAGES, -1, -1):
		var value: int = int(raw[stage]) if raw.size() > stage else -1
		var band: int = CardFace.strike_table.band(value) if CardFace.strike_table != null else -1
		if CardFace.strike_table != null and band != prev_band:
			bands[stage] = CardText.band_letter(band)
		prev_band = band
	for stage in range(STAGES + 1):
		might.append(int(raw[stage]) if raw.size() > stage else -1)
	# The printed rate plus the flat bonus every deck gets.
	var surge: int = int(td.get("surge", 0)) + DuelEngine.STYLE_SURGE_BONUS
	var lit: Color = CardFace.lit_color(backdrop)
	if might == _might and bands == _bands and surge == _surge and lit.is_equal_approx(_lit):
		return
	_might = might
	_bands = bands
	_surge = surge
	_lit = lit
	_touch()


## The live layer: `energy` -1 draws none. `might` -1 takes the printed rung. `reach` is the stage
## the next Recover lands on, -1 for no rail. `preview` outlines the rung a projected cost would
## drop Energy to.
func show_live(energy: int, might: int = -1, reach: int = -1, preview: int = 0) -> void:
	var shown_reach: int = mini(reach, STAGES) if energy >= 0 and energy < STAGES and reach > energy else -1
	var cost: int = maxi(0, preview)
	if energy == _energy and might == _live_might and shown_reach == _reach and cost == _preview:
		return
	_energy = energy
	_live_might = might
	_reach = shown_reach
	_preview = cost
	_touch()


func set_preview(cost: int) -> void:
	show_live(_energy, _live_might, _reach, cost)


func energy() -> int:
	return _energy


func reach() -> int:
	return _reach


func preview_cost() -> int:
	return _preview


func surge() -> int:
	return _surge


## Printed Might at `stage`, -1 where the card prints none.
func printed_might(stage: int) -> int:
	return _might[stage] if stage >= 0 and stage < _might.size() else -1


## The live Might against the printed rung, 0 when there is no live layer.
func might_delta() -> int:
	if _energy < 0 or _live_might < 0 or printed_might(_energy) < 0:
		return 0
	return _live_might - printed_might(_energy)


func box_rect() -> Rect2:
	return Rect2(GUTTER, 0.0, size.x - GUTTER, size.y)


func rung_rect(stage: int) -> Rect2:
	var box: Rect2 = box_rect()
	var step: float = (size.y - HEADER - FOOT) / float(STAGES + 1)
	return Rect2(box.position.x + ROW_INSET, HEADER + step * float(STAGES - stage), box.size.x - ROW_INSET * 2.0, step)


## The lit stage's pill: the rung, reaching OVERHANG past the box on both sides.
func pill_rect() -> Rect2:
	var box: Rect2 = box_rect()
	var r: Rect2 = rung_rect(clampi(_energy, 0, STAGES))
	return Rect2(box.position.x - OVERHANG, r.position.y - 1.0, box.size.x + OVERHANG * 2.0, r.size.y + 2.0)


## The rail on the box's right outline: from the pill's top up to the divider above the rung the
## next Recover reaches. Empty without one.
func rail_rect() -> Rect2:
	if _energy < 0 or _reach <= _energy:
		return Rect2()
	var x: float = box_rect().end.x - 1.0
	var top: float = rung_rect(_reach).position.y
	return Rect2(x - RAIL_WIDTH * 0.5, top, RAIL_WIDTH, pill_rect().position.y - top)


func _touch() -> void:
	queue_redraw()
	changed.emit()


func _draw() -> void:
	if _might.size() != STAGES + 1 or size.y <= HEADER + FOOT:
		return
	var font: Font = get_theme_default_font()
	if printed:
		_draw_printed(font)
	if _energy >= 0:
		_draw_live(font)


func _draw_printed(font: Font) -> void:
	var box: Rect2 = box_rect()
	if _box_style == null:
		_box_style = StyleBoxFlat.new()
		_box_style.bg_color = PAPER
		_box_style.border_color = Color(INK, 0.28)
		_box_style.set_border_width_all(2)
		_box_style.set_corner_radius_all(6)
	draw_style_box(_box_style, box)
	_text(font, "SURGE %d" % _surge, Rect2(box.position.x, 0.0, box.size.x, HEADER), HEADER_FONT, Color(INK, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(Vector2(box.position.x + 10.0, HEADER - 1.0), Vector2(box.end.x - 10.0, HEADER - 1.0), Color(INK, 0.16), 1.0)
	for stage in range(STAGES + 1):
		var r: Rect2 = rung_rect(stage)
		if _bands[stage] != "":
			if stage < STAGES:
				draw_line(Vector2(box.position.x + 2.0, r.position.y), Vector2(box.end.x - 2.0, r.position.y), Color(INK, 0.35), 2.0)
			_text(font, _bands[stage], Rect2(0.0, r.position.y, GUTTER - 6.0, r.size.y), BAND_FONT, Color(INK, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
		_rung_text(font, stage, r)


func _draw_live(font: Font) -> void:
	var pale: Color = PAPER.lerp(_lit, PALE)
	for stage in range(_energy):
		var r: Rect2 = rung_rect(stage)
		draw_rect(r, pale)
		_rung_text(font, stage, r)
	var rim: Color = _lit.darkened(RIM_DARKEN)
	var target: int = _energy - _preview
	if _preview > 0 and target >= 0:
		var ghost: StyleBoxFlat = _pill_style(Color(0, 0, 0, 0), rim)
		ghost.draw_center = false
		draw_style_box(ghost, rung_rect(target).grow_individual(0.0, -1.0, 0.0, -1.0))
	var rail: Rect2 = rail_rect()
	if rail.has_area():
		draw_rect(rail, rim)
		draw_rect(Rect2(rail.get_center().x - RAIL_CORE * 0.5, rail.position.y, RAIL_CORE, rail.size.y), _lit)
		for stage in range(_energy + 2, _reach + 1):
			var y: float = rung_rect(stage).end.y
			draw_rect(Rect2(rail.get_center().x - TICK, y - 1.0, TICK * 2.0, 2.0), rim)
	var pill: Rect2 = pill_rect()
	var fill: Color = _lit.lerp(Color.WHITE, flash * FLASH_LIGHTEN)
	draw_style_box(_pill_style(fill, rim), pill)
	var ink: Color = CardFace.lit_ink_color(_lit)
	var r: Rect2 = rung_rect(_energy)
	var might: int = _live_might if _live_might >= 0 else printed_might(_energy)
	_text(font, str(_energy), Rect2(r.position.x, r.position.y, STAGE_WIDTH, r.size.y), LIT_STAGE_FONT, Color(ink, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	if might >= 0:
		_text(font, CardText.short_number(might), Rect2(r.position.x, r.position.y, r.size.x - VALUE_PAD, r.size.y), LIT_MIGHT_FONT, ink, HORIZONTAL_ALIGNMENT_RIGHT)
	var delta: int = might_delta()
	if delta != 0:
		var word: String = "%+d" % delta
		var width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, DELTA_FONT).x + 10.0
		var chip: Rect2 = Rect2(r.position.x + STAGE_WIDTH + 2.0, r.get_center().y - 11.0, width, 22.0)
		draw_style_box(_pill_style(Color(INK, 0.88), Color(0, 0, 0, 0), 5), chip)
		_text(font, word, chip, DELTA_FONT, ZenithTheme.ENERGY if delta > 0 else ZenithTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER)


func _rung_text(font: Font, stage: int, r: Rect2) -> void:
	_text(font, str(stage), Rect2(r.position.x, r.position.y, STAGE_WIDTH, r.size.y), STAGE_FONT, Color(INK, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	if _might[stage] >= 0:
		_text(font, CardText.short_number(_might[stage]), Rect2(r.position.x, r.position.y, r.size.x - VALUE_PAD, r.size.y), MIGHT_FONT, INK, HORIZONTAL_ALIGNMENT_RIGHT)


func _pill_style(fill: Color, rim: Color, radius: int = 6) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(2 if rim.a > 0.0 else 0)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


## `text` centred on `box` vertically, aligned inside it horizontally.
func _text(font: Font, text: String, box: Rect2, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var baseline: float = box.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(box.position.x, baseline), text, align, box.size.x, font_size, color)
