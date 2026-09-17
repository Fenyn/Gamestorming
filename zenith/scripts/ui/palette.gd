class_name Palette
extends RefCounted
## Shared colors for card frames and UI accents.
##
## Each school owns a hue with a gap on the wheel to its neighbours, so no two read alike at a
## glance: Ember scarlet, Root leaf green, Tide sea teal, Storm electric indigo, Shade plum,
## Steel the one bright silver, Freestyle warm bronze.

const SCHOOL_COLORS: Dictionary = {
	"": Color(0.58, 0.44, 0.26),
	"ember": Color(0.74, 0.20, 0.10),
	"tide": Color(0.08, 0.44, 0.54),
	"storm": Color(0.34, 0.26, 0.76),
	"shade": Color(0.42, 0.12, 0.40),
	"steel": Color(0.70, 0.74, 0.80),
	"root": Color(0.20, 0.50, 0.22),
}
const DUELIST_COLOR: Color = Color(0.62, 0.48, 0.14)
const SEAL_COLOR: Color = Color(0.55, 0.45, 0.10)
const GROUNDS_COLOR: Color = Color(0.30, 0.34, 0.26)
const BACK_COLOR: Color = Color(0.12, 0.10, 0.16)
const TABLE_COLOR: Color = Color(0.16, 0.14, 0.12)
const HIGHLIGHT: Color = Color(1.0, 0.85, 0.30, 0.55)


## School colour lifted for use as text or a chip on the dark UI. Frame colours are too dark there.
static func school_ui(school: String) -> Color:
	match school:
		"":
			return Color(0.86, 0.72, 0.50)
		"ember":
			return Color(0.94, 0.42, 0.32)
		"tide":
			return Color(0.34, 0.74, 0.82)
		"storm":
			return Color(0.62, 0.56, 0.96)
		"shade":
			return Color(0.84, 0.50, 0.82)
		"steel":
			return Color(0.84, 0.88, 0.94)
		"root":
			return Color(0.50, 0.78, 0.46)
		_:
			return SCHOOL_COLORS.get(school, SCHOOL_COLORS[""]).lightened(0.3)


## UI colour for a card type, used for deck composition bars and type icons on the dark UI.
static func type_ui(type: CardDef.Type) -> Color:
	match type:
		CardDef.Type.DUELIST:
			return Color(0.95, 0.80, 0.40)
		CardDef.Type.MASTERY:
			return Color(0.80, 0.62, 0.90)
		CardDef.Type.RELIC:
			return Color(0.72, 0.60, 0.48)
		CardDef.Type.STRIKE:
			return Color(0.88, 0.55, 0.40)
		CardDef.Type.ART:
			return Color(0.60, 0.55, 0.92)
		CardDef.Type.COMBAT:
			return Color(0.75, 0.72, 0.66)
		CardDef.Type.NON_COMBAT:
			return Color(0.45, 0.72, 0.62)
		CardDef.Type.DRILL:
			return Color(0.40, 0.66, 0.90)
		CardDef.Type.ALLY:
			return Color(0.86, 0.69, 0.27)
		CardDef.Type.SEAL:
			return Color(0.95, 0.85, 0.45)
		CardDef.Type.GROUNDS:
			return Color(0.55, 0.62, 0.45)
		_:
			return Color(0.6, 0.6, 0.65)


## The same type colour, deepened to read on the cream card face.
static func type_ink(type: CardDef.Type) -> Color:
	var c: Color = type_ui(type).darkened(0.3)
	c.s = minf(c.s * 1.25, 1.0)
	return c


static func frame_color(def: CardDef) -> Color:
	match def.type:
		CardDef.Type.DUELIST:
			return DUELIST_COLOR
		CardDef.Type.SEAL:
			return SEAL_COLOR
		CardDef.Type.GROUNDS:
			return GROUNDS_COLOR
		_:
			return SCHOOL_COLORS.get(def.school, SCHOOL_COLORS[""])
