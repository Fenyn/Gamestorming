class_name SeatColors
extends RefCounted
## Per-battle identity colour for each seat: the player colour the lobby, the versus screen and
## the duel all draw with.
##
## A seat's colour is rolled inside its style's chunk of the wheel, so Root always reads green
## and Pyre always reads red, but the exact green changes from battle to battle. Player 1 keeps
## whatever its chunk gave it and Player 2 is pushed away from it, so Player 1's colour never
## moves when the other seat picks. The push wants 45 degrees when the styles own different
## hues; two seats on one style get a narrower gap plus a brightness split instead, because two
## Root seats have to stay two greens.
##
## The roll is seeded from Session.color_seed, which the authority shares, so both sides of an
## online duel draw the same two colours from the lobby onward.

const CHUNK_DEGREES: float = 14.0        # half-width of a style's hue chunk
const APART_DEGREES: float = 45.0        # wanted gap when the styles own different hues
const SAME_STYLE_DEGREES: float = 14.0   # how far two identical styles get pulled apart
const SAME_STYLE_VALUE: float = 0.12     # and how far their brightness is split
const SAME_STYLE_SAT: float = 0.30       # the deeper of the two also runs richer, as a fraction
const SAT_JITTER: float = 0.20           # fraction of the style's own saturation
const VAL_JITTER: float = 0.10
const SAT_CAP: float = 0.95
const VAL_RANGE: Vector2 = Vector2(0.70, 1.0)

static var _key: String = ""
static var _colors: Array[Color] = []


## Colour for one seat of a live duel, taking both styles from the view. Screens outside the
## duel go through `Session.seat_color`, which knows the matchup being chosen.
static func accent(view: SeatView, index: int, seed_value: int) -> Color:
	var styles: Array[String] = []
	for p in view.players:
		styles.append(p.style)
	return of_styles(styles, index, seed_value)


static func of_styles(styles: Array[String], index: int, seed_value: int) -> Color:
	var rolled: Array[Color] = for_styles(styles, seed_value)
	if index < 0 or index >= rolled.size():
		return Palette.school_ui("")
	return rolled[index]


## Cached roll. The same styles and seed always give the same colours, so every readout, chip
## or panel that asks during a battle gets one answer.
static func for_styles(styles: Array[String], seed_value: int) -> Array[Color]:
	var key: String = "%d|%s" % [seed_value, ",".join(styles)]
	if key != _key:
		_key = key
		_colors = roll(styles, seed_value)
	return _colors


static func roll(styles: Array[String], seed_value: int) -> Array[Color]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var bases: Array[Color] = []
	var hues: Array[float] = []
	var sats: Array[float] = []
	var vals: Array[float] = []
	for style in styles:
		var base: Color = Palette.school_ui(style)
		bases.append(base)
		hues.append(wrapf(base.h * 360.0 + rng.randf_range(-CHUNK_DEGREES, CHUNK_DEGREES), 0.0, 360.0))
		# Saturation moves relative to the style's own, so Steel stays the pale one.
		sats.append(clampf(base.s + rng.randf_range(-SAT_JITTER, SAT_JITTER) * base.s,
			base.s * 0.6, minf(base.s * 1.5, SAT_CAP)))
		vals.append(clampf(base.v + rng.randf_range(-VAL_JITTER, VAL_JITTER), VAL_RANGE.x, VAL_RANGE.y))
	if styles.size() == 2:
		# Styles on separate hues get the full gap. Two styles that already sit close (Steel and
		# Storm) keep their own distance, and two seats on the same style get the narrow gap plus
		# a brightness split. Only seat 1 moves.
		var base_gap: float = arc(bases[0].h * 360.0, bases[1].h * 360.0)
		var same_style: bool = bases[0].is_equal_approx(bases[1])
		var want: float = APART_DEGREES
		if base_gap < APART_DEGREES:
			want = SAME_STYLE_DEGREES if same_style else maxf(base_gap, SAME_STYLE_DEGREES)
		var short: float = want - arc(hues[0], hues[1])
		if short > 0.0:
			var dir: float = 1.0 if wrapf(hues[1] - hues[0], -180.0, 180.0) >= 0.0 else -1.0
			hues[1] = wrapf(hues[1] + dir * short, 0.0, 360.0)
		if same_style:
			# One green stays as rolled, the other goes lighter and cooler or deeper and richer,
			# whichever way has room, so they read apart even at a close hue.
			var floor_s: float = bases[0].s * 0.6
			var cap_s: float = minf(bases[0].s * 1.5, SAT_CAP)
			var split: float = SAME_STYLE_SAT * bases[0].s
			var up: bool = vals[0] < (VAL_RANGE.x + VAL_RANGE.y) * 0.5
			vals[1] = clampf(vals[0] + (SAME_STYLE_VALUE if up else -SAME_STYLE_VALUE), VAL_RANGE.x, VAL_RANGE.y)
			sats[1] = clampf(sats[0] + (-split if up else split), floor_s, cap_s)
	var out: Array[Color] = []
	for i in range(styles.size()):
		out.append(Color.from_hsv(hues[i] / 360.0, sats[i], vals[i]))
	return out


## Shortest distance between two hues in degrees.
static func arc(a: float, b: float) -> float:
	var d: float = absf(wrapf(a, 0.0, 360.0) - wrapf(b, 0.0, 360.0))
	return minf(d, 360.0 - d)
