class_name Palette
extends RefCounted
## Shared colors for card frames and UI accents.

const GUILD_COLORS: Dictionary = {
	"": Color(0.42, 0.37, 0.30),
	"ember": Color(0.62, 0.20, 0.12),
	"tide": Color(0.14, 0.36, 0.62),
	"storm": Color(0.40, 0.26, 0.62),
	"shade": Color(0.18, 0.18, 0.22),
	"steel": Color(0.40, 0.44, 0.50),
	"root": Color(0.20, 0.44, 0.24),
}
const FIGHTER_COLOR: Color = Color(0.62, 0.48, 0.14)
const TOKEN_COLOR: Color = Color(0.55, 0.45, 0.10)
const GROUNDS_COLOR: Color = Color(0.30, 0.34, 0.26)
const BACK_COLOR: Color = Color(0.12, 0.10, 0.16)
const TABLE_COLOR: Color = Color(0.16, 0.14, 0.12)
const HIGHLIGHT: Color = Color(1.0, 0.85, 0.30, 0.55)


## Guild colour lifted for use as text or a chip on the dark UI. Frame colours are too dark there.
static func guild_ui(guild: String) -> Color:
	var base: Color = GUILD_COLORS.get(guild, GUILD_COLORS[""])
	if guild == "shade":
		return Color(0.62, 0.58, 0.72)
	if guild == "":
		return Color(0.80, 0.72, 0.58)
	var c: Color = base.lightened(0.28)
	c.s = minf(c.s * 1.1, 1.0)
	return c


## UI colour for a card type, used for deck composition bars and type icons on the dark UI.
static func type_ui(type: CardDef.Type) -> Color:
	match type:
		CardDef.Type.FIGHTER:
			return Color(0.95, 0.80, 0.40)
		CardDef.Type.MASTERY:
			return Color(0.80, 0.62, 0.90)
		CardDef.Type.MASTER:
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
		CardDef.Type.TOKEN:
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
		CardDef.Type.FIGHTER:
			return FIGHTER_COLOR
		CardDef.Type.TOKEN:
			return TOKEN_COLOR
		CardDef.Type.GROUNDS:
			return GROUNDS_COLOR
		_:
			return GUILD_COLORS.get(def.guild, GUILD_COLORS[""])
