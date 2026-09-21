class_name Palette
extends RefCounted
## Shared colors for card frames and UI accents.
##
## Each school owns a hue with a gap on the wheel to its neighbours, so no two read alike at a
## glance: Pyre scarlet, Root leaf green, Tide sea teal, Storm electric indigo, Shade plum,
## Steel the one bright silver, Freestyle warm bronze.
##
## Signature cards are not a school and do not take a school hue. They are told apart by value
## instead: an obsidian frame, the only dark one on the table, with a bone rule inside it.

const SCHOOL_COLORS: Dictionary = {
	"": Color(0.58, 0.44, 0.26),
	"freestyle": Color(0.58, 0.44, 0.26),
	"pyre": Color(0.74, 0.20, 0.10),
	"tide": Color(0.08, 0.44, 0.54),
	"storm": Color(0.34, 0.26, 0.76),
	"shade": Color(0.42, 0.12, 0.40),
	"steel": Color(0.70, 0.74, 0.80),
	"root": Color(0.20, 0.50, 0.22),
}
## The Signature frame, its rule line, and its word on the dark UI. Held as vars, not consts, so a
## colour trial can swap all three in one place before rendering a comparison sheet.
static var SIGNATURE_FRAME: Color = Color(0.13, 0.12, 0.16)
static var SIGNATURE_RULE: Color = Color(0.86, 0.80, 0.64)
static var SIGNATURE_UI: Color = Color(0.97, 0.93, 0.80)

const DUELIST_COLOR: Color = Color(0.62, 0.48, 0.14)
const SEAL_COLOR: Color = Color(0.55, 0.45, 0.10)
const GROUNDS_COLOR: Color = Color(0.30, 0.34, 0.26)
const BACK_COLOR: Color = Color(0.12, 0.10, 0.16)
const TABLE_COLOR: Color = Color(0.16, 0.14, 0.12)
const HIGHLIGHT: Color = Color(1.0, 0.85, 0.30, 0.55)


## Card-group colour for text or a chip on the dark UI: pass `def.card_group()`, not `def.school`,
## so a Signature card reads as its own group instead of as Freestyle.
static func card_ui(def: CardDef) -> Color:
	return school_ui(def.card_group())


## School colour lifted for use as text or a chip on the dark UI. Frame colours are too dark there.
## Also answers the two non-school group ids, so `card_group()` can be passed straight in.
static func school_ui(school: String) -> Color:
	match school:
		"", "freestyle":
			return Color(0.86, 0.72, 0.50)
		"signature":
			return SIGNATURE_UI
		"pyre":
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
		CardDef.Type.PERSONALITY:
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
		CardDef.Type.PERSONALITY:
			return DUELIST_COLOR
		CardDef.Type.SEAL:
			return SEAL_COLOR
		CardDef.Type.GROUNDS:
			return GROUNDS_COLOR
		_:
			if def.is_signature():
				return SIGNATURE_FRAME
			return SCHOOL_COLORS.get(def.school, SCHOOL_COLORS[""])
