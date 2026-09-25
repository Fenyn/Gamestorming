class_name CardFace
extends Control
## Draws one card face procedurally. Rendered once per definition into a texture by CardFaceCache,
## and also used directly for the hover zoom.
##
## Two layouts share the frame. Personalities (Duelists, Allies) get a portrait: aspect box, name,
## and title with the type line across the top, art filling the left, the Might ladder (stages
## 10 to 0, banded by the Strike Table) down the right with the Surge badge under it,
## and the power text in a fixed box along the bottom. Everything else gets the standard face:
## title, type chip, an art box of a set height for that type, an Energy cost badge over the art,
## and the rules text in the fixed box that remains. Both set their text in RulesLayout blocks in
## an inset panel, with bookkeeping chips under it. Boxes never move between cards of one type;
## the text shrinks to fit.

const ART_DIR: String = "res://assets/card_art/"
const INK: Color = Color(0.10, 0.08, 0.06)
const CREAM: Color = Color(0.88, 0.84, 0.75)
const CONTENT_WIDTH: float = 452.0        # face width less the margins
const CONTENT_HEIGHT: float = 664.0
const TEXT_SIZES: Array[int] = [24, 22, 20, 18, 17, 16, 15, 14, 13, 12]
## The group line beside the type chip, largest first. Its width is what the chip leaves over.
const TYPE_REST_SIZES: Array[int] = [22, 20, 18, 17, 16, 15, 14]
const TYPE_CHIP_SIZE: int = 24          # the chip's own font size, from the scene
const TYPE_CHIP_FIXED: float = 30.0 + 8.0 + 20.0   # icon, gap, chip padding
const TYPE_ROW_GAP: float = 10.0
## Art box height per type, twice the art canvas in the roster (226 wide) so pictures fill the
## box without cropping. Cards that act (Strikes, Arts, Combat, Seals) carry little text and get
## the tall picture; cards that stay in play carry rules and get the shorter one.
const ART_HEIGHTS: Dictionary = {
	CardDef.Type.STRIKE: 320, CardDef.Type.ART: 320, CardDef.Type.COMBAT: 300, CardDef.Type.SEAL: 320,
	CardDef.Type.NON_COMBAT: 240, CardDef.Type.DRILL: 240, CardDef.Type.GROUNDS: 240,
	CardDef.Type.MASTERY: 200, CardDef.Type.RELIC: 200,
}
const STANDARD_FIXED: float = 44.0 + 36.0 + 3.0 * 8.0   # title, type row, gaps
const PERSON_TEXT_HEIGHT: float = 150.0
const RUNG_HEIGHT: float = 28.0
## Padding inside the text box and the ladder box.
const PAD_X: float = 10.0
const PAD_Y: float = 6.0
const LADDER_PAD: float = 6.0
const PARA_GAP: int = 6
const INDENT_PX: float = 32.0
const TAG_HEIGHT: float = 30.0
const TAG_FONT: int = 24
const STAMP_WIDTH: float = 124.0
## Endurance stamps sit in the iron of the HUD frames, off the blue that means defending.
const STAMP_IRON: Color = Color("3d3935")
const LEAD_INK: Color = Color("5c4128")
const PERSON_DARK: Color = Color("3b3226")
const LIT_FALLBACK: Color = Color("8fe0b8")
const LIT_LIGHTEN: float = 0.25
## The bone outer rule on a Signature frame, in face pixels. The face is 512 wide and drawn at
## about a quarter of that in the hand, so 6 here is the 1 to 2 px the player actually sees.
const SIGNATURE_EDGE: int = 6
const STAGES: int = CardInstance.MAX_STAGE
## Personality portraits are painted on a clear background, so the art box behind them shows the
## colour of the deck the card is being shown for: its Mastery's school hue, darkened. Callers
## that know the deck pass it as `backdrop`; a clear colour means `default_backdrop`, which the
## adventure screens set to the run deck and is the neutral dark everywhere else.
const BACKDROP_DARKEN: float = 0.72
const NEUTRAL_BACKDROP: Color = Color(0.11, 0.10, 0.10)
const NO_BACKDROP: Color = Color(0, 0, 0, 0)

## Kenney border rules inlaid in the frame band (tools/import_map_art.py writes them). Per style:
## the texture's corner size in its own pixels, and how far in from the card edge it sits so its
## lines land inside the band. Squarer frame corners suit the squared rules.
const CARD_RULES_DIR: String = "res://assets/ui/card_rules/"
const RULE_STYLES: Dictionary = {"inner_rule": [48, 6], "double": [32, 0], "notched": [32, -2]}
const RULE_LIGHTEN: float = 0.45
const FRAME_RADIUS: int = 8
const BODY_RADIUS: int = 10
const PLACEHOLDER_SEPIA: Color = Color(1.0, 0.86, 0.66)

static var default_backdrop: Color = NEUTRAL_BACKDROP
## Sets the band letters on the Might ladder. CardFaceCache hands it the session's table; with
## none the ladder prints no bands.
static var strike_table: StrikeTable = null

@onready var frame: Panel = $Frame
@onready var inner: Panel = $Inner
@onready var margin: MarginContainer = $Margin
@onready var art: Panel = $Margin/Column/Art
@onready var art_image: TextureRect = $Margin/Column/Art/Image
@onready var glyph: Label = $Margin/Column/Art/Glyph
@onready var glyph_icon: TypeIcon = $Margin/Column/Art/GlyphIcon
@onready var corner: Panel = $Margin/Column/Art/Corner
@onready var corner_icon: TypeIcon = $Margin/Column/Art/Corner/Icon
@onready var cost_badge: PanelContainer = $Margin/Column/Art/Cost
@onready var cost_num: Label = $Margin/Column/Art/Cost/Column/Num
@onready var cost_word: Label = $Margin/Column/Art/Cost/Column/Word
@onready var attack_badge: PanelContainer = $Margin/Column/Art/Attack
@onready var attack_kind: Label = $Margin/Column/Art/Attack/Column/Kind
@onready var attack_num: Label = $Margin/Column/Art/Attack/Column/Num
@onready var attack_word: Label = $Margin/Column/Art/Attack/Column/Word
@onready var title_label: Label = $Margin/Column/Title
@onready var type_chip: PanelContainer = $Margin/Column/TypeRow/TypeChip
@onready var type_icon: TypeIcon = $Margin/Column/TypeRow/TypeChip/Row/Icon
@onready var type_name: Label = $Margin/Column/TypeRow/TypeChip/Row/Name
@onready var type_rest: Label = $Margin/Column/TypeRow/Rest
@onready var words_box: PanelContainer = $Margin/Column/Words
@onready var tags_row: HFlowContainer = $Margin/Column/Words/Col/Tags
@onready var text_label: KeywordLabel = $Margin/Column/Words/Col/Text
@onready var stamps: VBoxContainer = $Margin/Column/Art/Stamps

@onready var person: MarginContainer = $Person
@onready var p_aspect_box: PanelContainer = $Person/Column/Head/AspectBox
@onready var p_aspect_num: Label = $Person/Column/Head/AspectBox/Col/Num
@onready var p_aspect_word: Label = $Person/Column/Head/AspectBox/Col/Word
@onready var p_name: Label = $Person/Column/Head/Names/Name
@onready var p_aspect_name: Label = $Person/Column/Head/Names/AspectRow/AspectName
@onready var p_art: Panel = $Person/Column/Body/Art
@onready var p_art_image: TextureRect = $Person/Column/Body/Art/Image
@onready var p_glyph_icon: TypeIcon = $Person/Column/Body/Art/GlyphIcon
@onready var p_ladder_box: PanelContainer = $Person/Column/Body/Side/LadderBox
@onready var p_ladder: VBoxContainer = $Person/Column/Body/Side/LadderBox/Ladder
@onready var p_surge: PanelContainer = $Person/Column/Body/Side/Stats/Surge
@onready var p_surge_num: Label = $Person/Column/Body/Side/Stats/Surge/Col/Num
@onready var p_surge_word: Label = $Person/Column/Body/Side/Stats/Surge/Col/Word
@onready var p_words: PanelContainer = $Person/Column/Words
@onready var p_tags: HFlowContainer = $Person/Column/Words/Col/Tags
@onready var p_text: KeywordLabel = $Person/Column/Words/Col/Text

var _rule: Panel = null
var _stage_rows: Array[PanelContainer] = []   # the rung's own pill, stage 10 first
var _stage_frames: Array[PanelContainer] = [] # the whole row, which carries the band rule
var _stage_tags: Array[PanelContainer] = []
var _stage_letters: Array[Label] = []
var _stage_labels: Array[Label] = []
var _stage_values: Array[Label] = []


func _ready() -> void:
	# The rule sits over the colour band and under the cream body, so only the band shows it.
	_rule = Panel.new()
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_rule)
	move_child(_rule, frame.get_index() + 1)
	_rule.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Eleven fixed rungs, stage 10 at the top down to stage 0. Built once; only the numbers change.
	# Each row is a band tag (shown where a Strike Table band starts) and the rung's pill.
	for i in range(STAGES + 1):
		var frame_row: PanelContainer = PanelContainer.new()
		frame_row.custom_minimum_size = Vector2(0, RUNG_HEIGHT)
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		var tag: PanelContainer = PanelContainer.new()
		tag.custom_minimum_size = Vector2(22, 20)
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var letter: Label = Label.new()
		letter.add_theme_font_size_override("font_size", 16)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_child(letter)
		h.add_child(tag)
		var pill: PanelContainer = PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inside: HBoxContainer = HBoxContainer.new()
		var stage: Label = Label.new()
		stage.text = str(STAGES - i)
		stage.add_theme_font_size_override("font_size", 16)
		inside.add_child(stage)
		var value: Label = Label.new()
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 24)
		inside.add_child(value)
		pill.add_child(inside)
		h.add_child(pill)
		frame_row.add_child(h)
		p_ladder.add_child(frame_row)
		_stage_frames.append(frame_row)
		_stage_tags.append(tag)
		_stage_letters.append(letter)
		_stage_rows.append(pill)
		_stage_labels.append(stage)
		_stage_values.append(value)


## `energy` is live Energy for a personality in play (-1 for none): the rung for the current stage
## lights up in the deck's Mastery colour. `_standing` is kept for callers; the face prints only
## what is on the card.
## `backdrop` is the deck colour behind a personality portrait (see NO_BACKDROP). `table_base` is
## the Strike Table result for the matchup the card is shown in, -1 outside a duel.
func show_def(def: CardDef, aspect: int = 0, energy: int = -1, _standing: SeatPlayer = null, backdrop: Color = NO_BACKDROP, table_base: int = -1) -> void:
	inner.visible = true
	var color: Color = Palette.frame_color(def)
	_style(frame, color, FRAME_RADIUS, Palette.frame_edge(def))
	_rule_style(def, color)
	_inner_style(def)
	var picture: Texture2D = art_texture(def, aspect)
	if def.is_personality():
		margin.visible = false
		person.visible = true
		_show_person(def, aspect, picture, energy, resolve_backdrop(backdrop))
	else:
		person.visible = false
		margin.visible = true
		_show_standard(def, color, picture, table_base)


func _show_standard(def: CardDef, color: Color, picture: Texture2D, table_base: int = -1) -> void:
	var art_height: float = float(ART_HEIGHTS.get(def.type, 280))
	art.custom_minimum_size = Vector2(0, art_height)
	_style(art, color.darkened(0.35), FRAME_RADIUS)
	art_image.texture = picture
	art_image.visible = picture != null
	art_image.self_modulate = placeholder_tint(picture)
	_mark_type(def, picture != null)
	title_label.text = def.title
	title_label.add_theme_color_override("font_color", INK)
	var title_rule: StyleBoxFlat = StyleBoxFlat.new()
	title_rule.draw_center = false
	title_rule.border_color = Color(INK, 0.3)
	title_rule.border_width_bottom = 2
	title_rule.content_margin_bottom = 2
	title_label.add_theme_stylebox_override("normal", title_rule)
	_fit_type_rest(def)
	type_rest.add_theme_color_override("font_color", INK)
	var text_box: StyleBoxFlat = _box_style(PAD_X, PAD_Y)
	words_box.add_theme_stylebox_override("panel", text_box)
	var room: float = CONTENT_HEIGHT - STANDARD_FIXED - art_height - 4.0
	_place_rules(text_label, CardText.rules_text(def), room, _inset(text_box), tags_row, stamps)
	# Energy cost as a round badge over the art, where the eye checks it first.
	var cost: int = 0
	if def.is_attack():
		cost = int(def.attack.get("cost_stages", 2 if def.attack_kind() == "art" else 0))
	cost_badge.visible = cost > 0
	cost_num.text = str(cost)
	# The base attack in the other corner: what the card adds before the table and the modifiers.
	var badge: Dictionary = CardText.attack_badge(def, table_base)
	attack_badge.visible = not badge.is_empty()
	if not badge.is_empty():
		attack_kind.text = str(badge["kind"]).to_upper()
		attack_num.text = str(badge["num"])
		var word: String = str(badge["word"])
		if str(badge["extra"]) != "":
			word += "  " + str(badge["extra"])
		attack_word.text = word.to_upper()
		_round(attack_badge, Palette.type_ink(def.type), 14, 10, 4)
		attack_kind.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		attack_num.add_theme_color_override("font_color", Color.WHITE)
		attack_word.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_round(cost_badge, ZenithTheme.ENERGY.darkened(0.35), 34)
	cost_num.add_theme_color_override("font_color", Color.WHITE)
	cost_word.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))


func _show_person(def: CardDef, aspect: int, picture: Texture2D, energy: int = -1, backdrop: Color = NEUTRAL_BACKDROP) -> void:
	# A personality card is one Aspect, so the card decides which number and row it shows.
	var t: int = def.aspect if def.aspect > 0 else aspect
	var td: Dictionary = def.aspect_data(t)
	_round(p_aspect_box, PERSON_DARK, 12)
	p_aspect_num.text = str(t)
	p_aspect_num.add_theme_color_override("font_color", Color.WHITE)
	p_aspect_word.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	p_name.text = def.title
	p_name.add_theme_color_override("font_color", INK)
	var name_font: Font = p_name.get_theme_font("font")
	var name_room: float = CONTENT_WIDTH - 64.0 - 10.0
	p_name.add_theme_font_size_override("font_size", 32 if name_font.get_string_size(def.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x <= name_room else 16)
	# An untitled card prints its line's word, or nothing: "Aspect 1" only repeats the box. The
	# type line rides on the same row, which leaves the Power box its full height.
	var head_parts: PackedStringArray = PackedStringArray()
	for part in [def.aspect_title if def.aspect_title != "" else def.variant, person_type_line(def)]:
		if str(part) != "":
			head_parts.append(str(part).to_upper())
	p_aspect_name.text = "  ·  ".join(head_parts)
	p_aspect_name.add_theme_color_override("font_color", Color(INK, 0.7))
	_style(p_art, backdrop, FRAME_RADIUS)
	p_art_image.texture = picture
	p_art_image.visible = picture != null
	p_art_image.self_modulate = placeholder_tint(picture)
	p_glyph_icon.visible = picture == null
	p_glyph_icon.type = def.type
	p_glyph_icon.color = Color(1, 1, 1, 0.3)
	_show_ladder(td.get("might", []), energy, backdrop)
	# The printed rate only. The live gain is a fact about the player, not the card.
	_round(p_surge, PERSON_DARK, 10)
	p_surge_num.text = str(int(td.get("surge", 0)))
	p_surge_num.add_theme_color_override("font_color", lit_color(backdrop))
	p_surge_word.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	var words: StyleBoxFlat = _box_style(PAD_X, PAD_Y)
	p_words.add_theme_stylebox_override("panel", words)
	p_ladder_box.add_theme_stylebox_override("panel", _box_style(LADDER_PAD, LADDER_PAD))
	var plain: String = "\n".join(CardText.aspect_text(def, t))
	_place_rules(p_text, plain, PERSON_TEXT_HEIGHT, _inset(words), p_tags, null)


## The inset panel that holds a card's words or its ladder: a shade darker than the cream, with
## a thin rule.
func _box_style(pad_x: float, pad_y: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	box.bg_color = CREAM.darkened(0.07)
	box.border_color = Color(INK, 0.28)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	return box


static func _inset(box: StyleBox) -> Vector2:
	return Vector2(box.content_margin_left + box.content_margin_right, box.content_margin_top + box.content_margin_bottom)


## Stage 10 down to 0. Numbers sit in ink on the cream; a hairline and a letter tag mark where a
## Strike Table band starts; the live stage is a pill in the deck's Mastery colour.
func _show_ladder(might: Array, energy: int, backdrop: Color) -> void:
	var lit_fill: Color = lit_color(backdrop)
	var lit_ink: Color = lit_ink_color(lit_fill)
	var prev_band: int = -1
	for i in range(STAGES + 1):
		var stage: int = STAGES - i
		var value: int = int(might[stage]) if might.size() > stage else 0
		var band: int = strike_table.band(value) if strike_table != null else -1
		var starts: bool = strike_table != null and band != prev_band
		prev_band = band
		var rule: StyleBoxFlat = StyleBoxFlat.new()
		rule.draw_center = false
		if starts and i > 0:
			rule.border_color = Color(INK, 0.35)
			rule.border_width_top = 2
			rule.content_margin_top = 2
		_stage_frames[i].add_theme_stylebox_override("panel", rule)
		_stage_tags[i].self_modulate.a = 1.0 if starts else 0.0
		_stage_letters[i].text = CardText.band_letter(band) if starts else ""
		_stage_letters[i].add_theme_color_override("font_color", CREAM)
		_round(_stage_tags[i], Color(INK, 0.75), 3, 0, 0)
		var lit: bool = stage == energy
		var pill: StyleBoxFlat = StyleBoxFlat.new()
		pill.draw_center = lit
		pill.bg_color = lit_fill
		pill.set_corner_radius_all(6)
		pill.content_margin_left = 6
		pill.content_margin_right = 6
		if lit:
			pill.border_color = lit_fill.darkened(0.55)
			pill.set_border_width_all(2)
		_stage_rows[i].add_theme_stylebox_override("panel", pill)
		_stage_labels[i].add_theme_color_override("font_color", Color(lit_ink, 0.9) if lit else Color(INK, 0.5))
		_stage_values[i].text = CardText.short_number(value) if might.size() > stage else ""
		_stage_values[i].add_theme_color_override("font_color", lit_ink if lit else INK)


## Bloodline, alignment gate and tags, in words, over the Power text.
static func person_type_line(def: CardDef) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if def.bloodline != "":
		parts.append(CardText.bloodline_name(def.bloodline))
	if def.alignment_only != "":
		parts.append(def.alignment_only.capitalize() + " only")
	for tag in def.raw.get("tags", []):
		parts.append(CardText.keyword_name(str(tag)))
	return " · ".join(parts)


## The live-stage colour: the deck's Mastery hue that `backdrop` was darkened from, lifted so it
## reads on the cream. With no deck named, a neutral mint. `deep` skips the lift: the table's
## see-through bar washes out over the cream unless its colour starts at full depth.
static func lit_color(backdrop: Color, deep: bool = false) -> Color:
	var b: Color = resolve_backdrop(backdrop)
	if b.is_equal_approx(NEUTRAL_BACKDROP):
		return LIT_FALLBACK.darkened(LIT_LIGHTEN) if deep else LIT_FALLBACK
	var keep: float = 1.0 - BACKDROP_DARKEN
	var hue: Color = Color(b.r / keep, b.g / keep, b.b / keep)
	return hue if deep else hue.lightened(LIT_LIGHTEN)


static func lit_ink_color(fill: Color) -> Color:
	return INK if fill.get_luminance() > 0.45 else Color.WHITE


## The deck's Mastery school hue, darkened for a portrait backdrop; neutral when it has none.
static func mastery_backdrop(deck: DeckList, library: CardLibrary) -> Color:
	if deck == null or library == null:
		return NEUTRAL_BACKDROP
	var mastery: CardDef = library.defs.get(deck.mastery_id)
	if mastery == null:
		return NEUTRAL_BACKDROP
	var hue: Color = Palette.SCHOOL_COLORS.get(mastery.school, Palette.SCHOOL_COLORS[""])
	return hue.darkened(BACKDROP_DARKEN)


## A clear colour stands for "no deck named": the default backdrop.
static func resolve_backdrop(backdrop: Color) -> Color:
	return backdrop if backdrop.a > 0.0 else default_backdrop


## Card art lives in assets/card_art/<group>/<id>.png, where the group is the id's first word
## (pyre_strike_07 is in pyre/). Ids are generic and never follow a title, so a rename leaves the
## art alone. An .svg of the same name is taken when no painting is there yet, which is how the
## placeholder crests are picked up. Missing art falls back to the type glyph. `aspect` is kept so
## callers need not know which is which.
static func art_texture(def: CardDef, aspect: int = 0) -> Texture2D:
	var _unused: int = aspect
	var stem: String = art_path(def.id)
	for path in [stem + ".png", stem + ".svg"]:
		if ResourceLoader.exists(path, "Texture2D"):
			return load(path) as Texture2D
	return null


## The art path for a card id, without the extension.
static func art_path(id: String) -> String:
	return "%s%s/%s" % [ART_DIR, id.get_slice("_", 0), id]


func show_back() -> void:
	_style(frame, Palette.BACK_COLOR)
	_rule.visible = false
	inner.visible = false
	margin.visible = false
	person.visible = false


## Rung rects in face pixels, stage 10 first; valid after a personality layout.
func ladder_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var origin: Vector2 = get_global_rect().position
	for row in _stage_rows:
		var r: Rect2 = row.get_global_rect()
		out.append(Rect2(r.position - origin, r.size))
	return out


## Sets a card's rules text and its chips. Chips go in `row`, the first line inside the text box.
## A stat chip (Endurance) becomes a stamp in `stamp_box` over the art instead, where the art has
## room for one; a personality passes null.
func _place_rules(label: KeywordLabel, plain: String, box_height: float, inset: Vector2, row: HFlowContainer, stamp_box: VBoxContainer) -> void:
	var layout: Dictionary = RulesLayout.build(plain)
	var chips: Array[Dictionary] = []
	var stamped: Array[Dictionary] = []
	for t in layout["tags"]:
		if stamp_box != null and _stamp_parts(t).size() > 0:
			stamped.append(t)
		else:
			chips.append(t)
	var font: Font = label.get_theme_font("normal_font")
	box_height -= _tag_rows(chips, font, CONTENT_WIDTH - inset.x) * (TAG_HEIGHT + 6.0)
	_fit_rules(label, layout, box_height, inset)
	_show_tags(row, chips)
	row.visible = not chips.is_empty()
	if stamp_box != null:
		_show_stamps(stamp_box, stamped)


## Rules text set as RulesLayout blocks: the gate as a muted line on top, each block its own
## paragraph with its lead-in in capitals, branches indented. The text takes the largest size
## from TEXT_SIZES whose blocks fit, so a wordy card and a short one share the layout and only the
## type size differs. `inset` is the padding the box takes from the content width and from
## `box_height`.
func _fit_rules(label: KeywordLabel, layout: Dictionary, box_height: float, inset: Vector2) -> void:
	var font: Font = label.get_theme_font("normal_font")
	var width: float = CONTENT_WIDTH - 6.0 - inset.x
	var room: float = box_height - inset.y - 6.0
	var chosen: int = TEXT_SIZES[TEXT_SIZES.size() - 1]
	for size in TEXT_SIZES:
		if _rules_height(layout, font, width, size) <= room:
			chosen = size
			break
	label.add_theme_font_size_override("normal_font_size", chosen)
	label.add_theme_font_size_override("bold_font_size", chosen)
	label.add_theme_color_override("default_color", INK)
	label.add_theme_constant_override("paragraph_separation", PARA_GAP)
	label.bbcode_enabled = true
	var muted: String = Color(INK, 0.6).to_html()
	var out: PackedStringArray = PackedStringArray()
	for g in layout["gate"]:
		out.append("[color=#%s]%s[/color]" % [muted, KeywordText.escape(str(g).to_upper())])
	for p in layout["paras"]:
		var body: String = ""
		if bool(p["aside"]):
			body = "[color=#%s]%s[/color]" % [muted, KeywordText.escape(str(p["text"]))]
		else:
			body = KeywordText.bbcode(str(p["text"]))
		if str(p["lead"]) != "":
			body = "[color=#%s]%s[/color] %s" % [LEAD_INK.to_html(false), KeywordText.escape(str(p["lead"]).to_upper()), body]
		if bool(p["indent"]):
			body = "[indent]%s[/indent]" % body
		out.append(body)
	label.text = "\n".join(out)


func _rules_height(layout: Dictionary, font: Font, width: float, size: int) -> float:
	var flags: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	var h: float = 0.0
	var n: int = 0
	for g in layout["gate"]:
		h += font.get_multiline_string_size(str(g).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, flags).y
		n += 1
	for p in layout["paras"]:
		var s: String = (str(p["lead"]).to_upper() + " " + str(p["text"])).strip_edges()
		h += font.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, width - (INDENT_PX if bool(p["indent"]) else 0.0), size, -1, flags).y
		n += 1
	return h + PARA_GAP * maxi(0, n - 1)


## How many rows the chips wrap to across `width`.
func _tag_rows(tags: Array, font: Font, width: float) -> int:
	if tags.is_empty():
		return 0
	var rows: int = 1
	var x: float = 0.0
	for t in tags:
		var w: float = font.get_string_size(str(t["word"]), HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT).x + 16.0
		if x > 0.0 and x + 6.0 + w > width:
			rows += 1
			x = 0.0
		x += (6.0 if x > 0.0 else 0.0) + w
	return rows


## RulesLayout chips in `row`, reusing the chips from the last face. Bookkeeping is a quiet ink
## chip; a chip with a role takes that keyword's colour.
func _show_tags(row: Container, tags: Array[Dictionary]) -> void:
	var pool: Array = []
	for c in row.get_children():
		if c.has_meta("tag_chip"):
			pool.append(c)
	while pool.size() < tags.size():
		var chip: PanelContainer = PanelContainer.new()
		chip.set_meta("tag_chip", true)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var l: Label = Label.new()
		l.add_theme_font_size_override("font_size", TAG_FONT)
		chip.add_child(l)
		row.add_child(chip)
		pool.append(chip)
	for i in range(pool.size()):
		var chip: PanelContainer = pool[i] as PanelContainer
		chip.visible = i < tags.size()
		if i < tags.size():
			var role: String = str(tags[i]["role"])
			var l: Label = chip.get_child(0) as Label
			l.text = str(tags[i]["word"])
			if role == "":
				_round(chip, Color(INK, 0.16), 5, 8, 1)
				l.add_theme_color_override("font_color", Color(INK, 0.85))
			else:
				_round(chip, KeywordText.color_for(role, false), 5, 8, 1)
				l.add_theme_color_override("font_color", CREAM)


## "ENDURANCE 2" -> ["2", "ENDURANCE"]; empty for a chip that is not a stat.
static func _stamp_parts(tag: Dictionary) -> PackedStringArray:
	var word: String = str(tag["word"])
	if word.begins_with("ENDURANCE "):
		return PackedStringArray([word.trim_prefix("ENDURANCE "), "ENDURANCE"])
	return PackedStringArray()


## Stat chips as round stamps over the bottom-right of the art, like the Energy cost badge.
func _show_stamps(box: VBoxContainer, tags: Array[Dictionary]) -> void:
	while box.get_child_count() < tags.size():
		var stamp: PanelContainer = PanelContainer.new()
		stamp.custom_minimum_size = Vector2(STAMP_WIDTH, 0)
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", -4)
		for size in [32, 16]:
			var l: Label = Label.new()
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override("font_size", size)
			l.add_theme_color_override("font_color", CREAM)
			col.add_child(l)
		stamp.add_child(col)
		box.add_child(stamp)
	for i in range(box.get_child_count()):
		var stamp: PanelContainer = box.get_child(i) as PanelContainer
		stamp.visible = i < tags.size()
		if i < tags.size():
			var parts: PackedStringArray = _stamp_parts(tags[i])
			var col: VBoxContainer = stamp.get_child(0) as VBoxContainer
			(col.get_child(0) as Label).text = parts[0]
			(col.get_child(1) as Label).text = parts[1]
			var box_style: StyleBoxFlat = StyleBoxFlat.new()
			box_style.bg_color = STAMP_IRON
			box_style.set_corner_radius_all(14)
			box_style.border_color = CREAM
			box_style.set_border_width_all(3)
			box_style.content_margin_top = 4
			box_style.content_margin_bottom = 4
			stamp.add_theme_stylebox_override("panel", box_style)


## The cream body. A Signature card gets a second rule just inside the frame, a bone line no
## school card has, so the group reads from across the table and not only by the frame's colour.
func _inner_style(def: CardDef) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = CREAM
	box.set_corner_radius_all(BODY_RADIUS)
	box.anti_aliasing = true
	if def.is_signature():
		box.border_color = Palette.SIGNATURE_RULE
		box.set_border_width_all(5)
	inner.add_theme_stylebox_override("panel", box)


## Placeholder art (the `.svg` sketches and crests that stand in until a painting arrives) is drawn
## in a warm sepia, so a card without its painting reads as a pencil study rather than a grey
## debug image next to the painted ones. A painting is drawn as it is.
static func placeholder_tint(picture: Texture2D) -> Color:
	if picture != null and picture.resource_path.ends_with(".svg"):
		return PLACEHOLDER_SEPIA
	return Color.WHITE


## The Kenney border drawn in the frame's colour band, lighter than the band so it reads as an
## inlaid rule. Personalities take the double line, Signature cards the notched one (in their bone
## rule colour), everything else the inner rule.
func _rule_style(def: CardDef, color: Color) -> void:
	var style: String = "double" if def.is_personality() else ("notched" if def.is_signature() else "inner_rule")
	var spec: Array = RULE_STYLES[style]
	var tex: Texture2D = load(CARD_RULES_DIR + style + ".png") as Texture2D if ResourceLoader.exists(CARD_RULES_DIR + style + ".png") else null
	_rule.visible = tex != null
	if tex == null:
		return
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = tex
	box.set_texture_margin_all(int(spec[0]))
	box.draw_center = false
	box.modulate_color = Palette.SIGNATURE_RULE if def.is_signature() else color.lightened(RULE_LIGHTEN)
	_rule.add_theme_stylebox_override("panel", box)
	var inset: float = float(spec[1])
	_rule.offset_left = inset
	_rule.offset_top = inset
	_rule.offset_right = -inset
	_rule.offset_bottom = -inset


## `edge` draws a thin outer rule on the frame. Only the Signature group uses it, so its obsidian
## frame has an outline on the dark table instead of vanishing into it.
func _style(panel: Panel, color: Color, radius: int = 22, edge: Color = Color(0, 0, 0, 0)) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	if edge.a > 0.0:
		box.border_color = edge
		box.set_border_width_all(SIGNATURE_EDGE)
		box.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", box)


func _round(panel: PanelContainer, color: Color, radius: int, pad_x: int = 4, pad_y: int = 2) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	panel.add_theme_stylebox_override("panel", box)


## Icon plus type name in the type's ink.
func _chip(chip: PanelContainer, icon: TypeIcon, name_label: Label, type: CardDef.Type) -> void:
	_round(chip, Palette.type_ink(type), 8, 10, 3)
	icon.type = type
	icon.color = Color.WHITE
	name_label.text = str(CardText.TYPE_LABELS.get(type, "Card")).to_upper()
	name_label.add_theme_color_override("font_color", Color.WHITE)


## Every type mark on the standard face in one place: the chip under the title, the big icon in
## an art-less art box, and the round badge over real art. Seals keep their number as the big
## glyph since the number is what matters at the table.
func _mark_type(def: CardDef, has_art: bool) -> void:
	_chip(type_chip, type_icon, type_name, def.type)
	var seal: bool = def.type == CardDef.Type.SEAL
	glyph.visible = not has_art and seal
	glyph.text = str(def.seal_number)
	glyph.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	glyph_icon.visible = not has_art and not seal
	glyph_icon.type = def.type
	glyph_icon.color = Color(1, 1, 1, 0.3)
	corner.visible = has_art
	var badge: StyleBoxFlat = StyleBoxFlat.new()
	badge.bg_color = Palette.type_ink(def.type)
	badge.set_corner_radius_all(26)
	badge.border_color = CREAM
	badge.set_border_width_all(3)
	corner.add_theme_stylebox_override("panel", badge)
	corner_icon.type = def.type
	corner_icon.color = Color.WHITE


## What follows the type chip: the card's group, and any alignment gate. A Signature card says so
## here and names its character, which is the identity the group stands for.
## A Seal, a Grounds and a Relic now answer `card_group()` with their own group, whose word is the
## type word, so printing it here would read "SEAL · Seal". The chip beside it already says it.
func _type_rest(def: CardDef) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var group: String = CardText.card_group_line(def)
	if group != CardText.type_label(def):
		parts.append(group)
	if def.alignment_only != "":
		parts.append(def.alignment_only.capitalize() + "s only")
	return " · ".join(parts)


## The group line is the one row whose length the card does not control: a Signature card prints
## a character's name after the word. It steps down through TYPE_REST_SIZES until it fits the
## space the type chip leaves, so the longest name in the data still reads instead of trimming to
## an ellipsis. The chip is measured rather than read from the tree, since nothing has laid out yet.
func _fit_type_rest(def: CardDef) -> void:
	var text: String = _type_rest(def)
	type_rest.text = text
	var font: Font = type_rest.get_theme_font("font")
	var chip_word: String = str(CardText.TYPE_LABELS.get(def.type, "Card")).to_upper()
	var chip: float = TYPE_CHIP_FIXED + font.get_string_size(chip_word, HORIZONTAL_ALIGNMENT_LEFT, -1, TYPE_CHIP_SIZE).x
	var room: float = CONTENT_WIDTH - chip - TYPE_ROW_GAP
	var chosen: int = TYPE_REST_SIZES[TYPE_REST_SIZES.size() - 1]
	for size in TYPE_REST_SIZES:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= room:
			chosen = size
			break
	type_rest.add_theme_font_size_override("font_size", chosen)
