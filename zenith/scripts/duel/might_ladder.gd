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

## How an Energy change moves the pill when `animate` is on. Every gain is a charge: it climbs
## rung by rung, glinting each in Energy green, and pops on arrival. A loss cued as a hit drops,
## lights the rungs it falls through red, throws shards and shakes; any other loss slides down
## through ember.
enum Motion { SLIDE, HIT, CHARGE }
const HIT_HOLD: float = 0.08             # the struck pill shudders in place before it drains
const HIT_TIME: float = 0.4              # plus HIT_PER_STAGE a stage, up to HIT_MAX
const HIT_PER_STAGE: float = 0.07
const HIT_MAX: float = 0.85
const CHARGE_TIME: float = 0.35          # plus CHARGE_PER_STAGE a stage, up to CHARGE_MAX
const CHARGE_PER_STAGE: float = 0.15
const CHARGE_MAX: float = 1.3
const SLIDE_TIME: float = 0.5
const GLOW_FADE: float = 0.9             # a passed rung's glow, per second
const GLOW_ALPHA: float = 0.85
const SHAKE_FADE: float = 4.0
const POP_FADE: float = 3.5
const TINT_FADE: float = 2.2
## Sizes are in face pixels; a table card shows the face at about 0.4, so they run large.
const SHAKE_PX: float = 10.0
const POP_PX: float = 8.0
const SHARDS: Array[int] = [6, 10, 16]   # by hit tier
const SHARD_SIZE: Vector2 = Vector2(9.0, 16.0)
const SHARD_SPEED: Vector2 = Vector2(280.0, 520.0)
const SHARD_GRAVITY: float = 1400.0
const SHARD_LIFE: float = 0.6

@export var printed: bool = true
## Energy changes move the pill instead of snapping it. Off for cached faces.
@export var animate: bool = false
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
var _pos: float = -1.0              # where the pill is drawn, in stages; equals _energy at rest
var _from: float = -1.0
var _t: float = 0.0
var _duration: float = 0.0
var _motion: Motion = Motion.SLIDE
var _cue: Motion = Motion.SLIDE     # the motion the next Energy change takes
var _cue_tier: int = 0
var _tier: int = 0
var _glow: Dictionary = {}          # stage -> [strength 0..1, Color]
var _shards: Array[Dictionary] = []
var _shake: float = 0.0
var _pop: float = 0.0
var _tint: float = 0.0
var _tint_color: Color = Color.WHITE
var _clock: float = 0.0


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
	var cue: Motion = _cue
	_cue = Motion.SLIDE
	if energy == _energy and might == _live_might and shown_reach == _reach and cost == _preview:
		return
	if animate and _energy >= 0 and energy >= 0 and energy != _energy:
		_start(energy, cue)
	elif energy != _energy:
		_pos = float(energy)
	_energy = energy
	_live_might = might
	_reach = shown_reach
	_preview = cost
	_touch()


## The next Energy loss is a hit of `tier` (0 light to 2 heavy). A loss with no cue slides.
func cue(motion: Motion, tier: int = 0) -> void:
	_cue = motion
	_cue_tier = clampi(tier, 0, SHARDS.size() - 1)


## True while the pill is still travelling to its rung.
func moving() -> bool:
	return _t < _duration


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


## The lit stage's pill: the rung, reaching OVERHANG past the box on both sides. Between rungs
## while it moves.
func pill_rect() -> Rect2:
	var box: Rect2 = box_rect()
	var r: Rect2 = _rung_at(clampf(_pos, 0.0, float(STAGES)))
	return Rect2(box.position.x - OVERHANG, r.position.y - 1.0, box.size.x + OVERHANG * 2.0, r.size.y + 2.0)


## `rung_rect` at a fractional stage.
func _rung_at(stage: float) -> Rect2:
	var box: Rect2 = box_rect()
	var step: float = (size.y - HEADER - FOOT) / float(STAGES + 1)
	return Rect2(box.position.x + ROW_INSET, HEADER + step * (float(STAGES) - stage), box.size.x - ROW_INSET * 2.0, step)


func _start(energy: int, motion: Motion) -> void:
	var stages: int = absi(energy - _energy)
	if energy > _energy:
		motion = Motion.CHARGE
	elif motion == Motion.CHARGE:
		motion = Motion.SLIDE
	_motion = motion
	_tier = _cue_tier
	_from = _pos if _pos >= 0.0 else float(_energy)
	_t = 0.0
	match motion:
		Motion.HIT:
			_duration = minf(HIT_TIME + HIT_PER_STAGE * stages, HIT_MAX)
			_t = -HIT_HOLD
			_shake = 1.0 if _tier > 0 else 0.5
			_tint = 1.0
			_tint_color = ZenithTheme.ATTACK
			_spawn_shards(SHARDS[_tier])
		Motion.CHARGE:
			_duration = minf(CHARGE_TIME + CHARGE_PER_STAGE * stages, CHARGE_MAX)
		_:
			_duration = SLIDE_TIME
			_tint = 0.6
			_tint_color = ZenithTheme.WARN
	set_process(true)


## Shards off both ends of the pill, thrown outward and up, falling.
func _spawn_shards(count: int) -> void:
	var pill: Rect2 = pill_rect()
	for i in count:
		var left: bool = i % 2 == 0
		var at: Vector2 = Vector2(pill.position.x if left else pill.end.x, pill.position.y + randf() * pill.size.y)
		var speed: float = randf_range(SHARD_SPEED.x, SHARD_SPEED.y) * (1.0 + 0.25 * _tier)
		var angle: float = randf_range(-0.9, 0.35)
		var dir: Vector2 = Vector2(-cos(angle) if left else cos(angle), sin(angle))
		_shards.append({"at": at, "vel": dir * speed, "life": SHARD_LIFE * randf_range(0.7, 1.0),
			"size": randf_range(SHARD_SIZE.x, SHARD_SIZE.y) + 2.0 * _tier, "spin": randf_range(-12.0, 12.0), "turn": randf() * TAU,
			"color": ZenithTheme.ATTACK.lerp(Color.WHITE, randf() * 0.4)})


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_clock += delta
	if _t < _duration:
		_t = minf(_t + delta, _duration)
		var k: float = maxf(_t, 0.0) / _duration
		var target: float = float(_energy)
		var eased: float
		match _motion:
			Motion.HIT:
				eased = 1.0 - pow(1.0 - k, 3.0)
			Motion.CHARGE:
				eased = k * k * (3.0 - 2.0 * k)
			_:
				eased = 1.0 - pow(1.0 - k, 2.0)
		var before: float = _pos
		_pos = lerpf(_from, target, eased)
		_mark_passed(before, _pos)
		if _t >= _duration:
			_pos = target
			if _motion == Motion.CHARGE:
				_pop = 1.0
				_tint = 1.0
				_tint_color = Color.WHITE
	for stage in _glow.keys():
		var g: Array = _glow[stage]
		g[0] = float(g[0]) - GLOW_FADE * delta
		if float(g[0]) <= 0.0:
			_glow.erase(stage)
	for i in range(_shards.size() - 1, -1, -1):
		var s: Dictionary = _shards[i]
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			_shards.remove_at(i)
			continue
		s["vel"] = (s["vel"] as Vector2) + Vector2(0.0, SHARD_GRAVITY * delta)
		s["at"] = (s["at"] as Vector2) + (s["vel"] as Vector2) * delta
		s["turn"] = float(s["turn"]) + float(s["spin"]) * delta
	_shake = maxf(0.0, _shake - SHAKE_FADE * delta)
	_pop = maxf(0.0, _pop - POP_FADE * delta)
	_tint = maxf(0.0, _tint - TINT_FADE * delta)
	if _t >= _duration and _glow.is_empty() and _shards.is_empty() and _shake <= 0.0 and _pop <= 0.0 and _tint <= 0.0:
		set_process(false)
	_touch()


## Lights each rung the pill crossed between `a` and `b` this frame.
func _mark_passed(a: float, b: float) -> void:
	var lo: int = int(ceil(minf(a, b) - 0.001))
	var hi: int = int(floor(maxf(a, b) + 0.001))
	for stage in range(maxi(lo, 0), mini(hi, STAGES) + 1):
		if is_equal_approx(float(stage), _from):
			continue
		match _motion:
			Motion.HIT:
				_glow[stage] = [1.0, ZenithTheme.ATTACK]
			Motion.CHARGE:
				_glow[stage] = [1.0, ZenithTheme.ENERGY]
				_pop = maxf(_pop, 0.45)
			_:
				_glow[stage] = [0.7, ZenithTheme.WARN]


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
	var moving: bool = not is_equal_approx(_pos, float(_energy))
	for stage in range(STAGES + 1):
		if float(stage) >= _pos - 0.5:
			break
		var r: Rect2 = rung_rect(stage)
		draw_rect(r, pale)
		_rung_text(font, stage, r)
	for stage: int in _glow.keys():
		var g: Array = _glow[stage]
		var c: Color = g[1]
		draw_rect(rung_rect(stage), Color(c, clampf(float(g[0]), 0.0, 1.0) * GLOW_ALPHA))
	if moving and _motion == Motion.CHARGE:
		_draw_streak()
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
	var jolt: Vector2 = Vector2(sin(_clock * 70.0), cos(_clock * 53.0) * 0.4) * SHAKE_PX * _shake
	var pill: Rect2 = pill_rect().grow(POP_PX * _pop)
	pill.position += jolt
	var fill: Color = _lit.lerp(Color.WHITE, flash * FLASH_LIGHTEN).lerp(_tint_color, _tint * 0.65)
	draw_style_box(_pill_style(fill, rim), pill)
	var ink: Color = CardFace.lit_ink_color(_lit)
	var shown: int = clampi(roundi(_pos), 0, STAGES)
	var r: Rect2 = _rung_at(clampf(_pos, 0.0, float(STAGES)))
	r.position += jolt
	var might: int = _live_might if _live_might >= 0 and not moving else printed_might(shown)
	_text(font, str(shown), Rect2(r.position.x, r.position.y, STAGE_WIDTH, r.size.y), LIT_STAGE_FONT, Color(ink, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	if might >= 0:
		_text(font, CardText.short_number(might), Rect2(r.position.x, r.position.y, r.size.x - VALUE_PAD, r.size.y), LIT_MIGHT_FONT, ink, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_shards()
	var delta: int = might_delta()
	if delta != 0 and not moving:
		var word: String = "%+d" % delta
		var width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, DELTA_FONT).x + 10.0
		var chip: Rect2 = Rect2(r.position.x + STAGE_WIDTH + 2.0, r.get_center().y - 11.0, width, 22.0)
		draw_style_box(_pill_style(Color(INK, 0.88), Color(0, 0, 0, 0), 5), chip)
		_text(font, word, chip, DELTA_FONT, ZenithTheme.ENERGY if delta > 0 else ZenithTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER)


## A charge's wake: Energy green rising from the rung it left to the pill, clear at the bottom.
func _draw_streak() -> void:
	var low: Rect2 = _rung_at(_from)
	var high: Rect2 = pill_rect()
	var bottom: float = low.end.y
	var top: float = high.get_center().y
	if bottom <= top:
		return
	var x0: float = low.position.x
	var x1: float = low.end.x
	var clear: Color = Color(ZenithTheme.ENERGY, 0.0)
	var lit: Color = Color(ZenithTheme.ENERGY, 0.55)
	draw_polygon(PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, bottom), Vector2(x0, bottom)]),
		PackedColorArray([lit, lit, clear, clear]))


func _draw_shards() -> void:
	for s: Dictionary in _shards:
		var at: Vector2 = s["at"]
		var half: float = float(s["size"]) * 0.5
		var turn: float = float(s["turn"])
		var c: Color = s["color"]
		c.a = clampf(float(s["life"]) / SHARD_LIFE, 0.0, 1.0)
		var points: PackedVector2Array = PackedVector2Array()
		for corner in 4:
			points.append(at + Vector2(half, 0.0).rotated(turn + corner * PI * 0.5))
		draw_colored_polygon(points, c)


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
