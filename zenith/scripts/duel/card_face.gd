class_name CardFace
extends Control
## Draws one card face procedurally. Rendered once per definition into a texture by CardFaceCache,
## and also used directly for the hover zoom.
##
## Two layouts share the frame. Personalities (Duelists, Allies) get a portrait: aspect box and
## name across the top, art filling the left, the ten-stage Might ladder down the right with the
## Surge badge under it, and the aspect's power text in a fixed box along the bottom. Everything
## else gets the standard face: title, type chip, an art box of a set height for that type, a
## Energy cost badge over the art, and the rules text in the fixed box that remains, with
## Endurance under it. Boxes never move between cards of one type; the text shrinks to fit.

const ART_DIR: String = "res://assets/card_art/"
const INK: Color = Color(0.10, 0.08, 0.06)
const CREAM: Color = Color(0.93, 0.90, 0.84)
const CONTENT_WIDTH: float = 452.0        # face width less the margins
const CONTENT_HEIGHT: float = 664.0
const TEXT_SIZES: Array[int] = [24, 22, 20, 18, 17, 16, 15, 14, 13, 12]
## Art box height per type, twice the art canvas in the roster (226 wide) so pictures fill the
## box without cropping. Cards that act (Strikes, Arts, Combat, Seals) carry little text and get
## the tall picture; cards that stay in play carry rules and get the shorter one.
const ART_HEIGHTS: Dictionary = {
	CardDef.Type.STRIKE: 320, CardDef.Type.ART: 320, CardDef.Type.COMBAT: 300, CardDef.Type.SEAL: 320,
	CardDef.Type.NON_COMBAT: 240, CardDef.Type.DRILL: 240, CardDef.Type.GROUNDS: 240,
	CardDef.Type.MASTERY: 200, CardDef.Type.RELIC: 200,
}
const STANDARD_FIXED: float = 44.0 + 36.0 + 30.0 + 4.0 * 8.0   # title, type row, badges, gaps
const PERSON_TEXT_HEIGHT: float = 150.0
const STAGES: int = CardInstance.MAX_STAGE

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
@onready var text_label: KeywordLabel = $Margin/Column/Text
@onready var badges: HBoxContainer = $Margin/Column/Badges
@onready var left_badge: Label = $Margin/Column/Badges/Left
@onready var right_badge: Label = $Margin/Column/Badges/Right

@onready var person: MarginContainer = $Person
@onready var p_aspect_box: PanelContainer = $Person/Column/Head/AspectBox
@onready var p_aspect_num: Label = $Person/Column/Head/AspectBox/Col/Num
@onready var p_aspect_word: Label = $Person/Column/Head/AspectBox/Col/Word
@onready var p_name: Label = $Person/Column/Head/Names/Name
@onready var p_aspect_name: Label = $Person/Column/Head/Names/AspectRow/AspectName
@onready var p_fervor: HBoxContainer = $Person/Column/Head/Names/AspectRow/Fervor
@onready var p_type_chip: PanelContainer = $Person/Column/Head/TypeChip
@onready var p_type_icon: TypeIcon = $Person/Column/Head/TypeChip/Row/Icon
@onready var p_art: Panel = $Person/Column/Body/Art
@onready var p_art_image: TextureRect = $Person/Column/Body/Art/Image
@onready var p_glyph_icon: TypeIcon = $Person/Column/Body/Art/GlyphIcon
@onready var p_ladder: VBoxContainer = $Person/Column/Body/Side/Ladder
@onready var p_surge: PanelContainer = $Person/Column/Body/Side/Surge
@onready var p_surge_num: Label = $Person/Column/Body/Side/Surge/Col/Num
@onready var p_surge_word: Label = $Person/Column/Body/Side/Surge/Col/Word
@onready var p_text: KeywordLabel = $Person/Column/Text

var _stage_rows: Array[PanelContainer] = []
var _fervor_pips: Array[Panel] = []
var _stage_labels: Array[Label] = []
var _stage_values: Array[Label] = []


func _ready() -> void:
	# Ten fixed rungs, top rung is stage 10. Built once; only the numbers change per face.
	for i in range(STAGES):
		var row: PanelContainer = PanelContainer.new()
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var stage: Label = Label.new()
		stage.text = str(STAGES - i)
		stage.custom_minimum_size = Vector2(24, 0)
		stage.add_theme_font_size_override("font_size", 14)
		stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(stage)
		var value: Label = Label.new()
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 19)
		h.add_child(value)
		row.add_child(h)
		p_ladder.add_child(row)
		_stage_rows.append(row)
		_stage_labels.append(stage)
		_stage_values.append(value)


## `energy` is live Energy for a personality in play (-1 for none): the rung for the current stage
## lights up. `standing` is the owning player when the card is a duelist in play: Fervor pips
## appear under the name, one per point needed, and the Surge badge shows the live Recover gain.
func show_def(def: CardDef, aspect: int = 0, energy: int = -1, standing: SeatPlayer = null) -> void:
	inner.visible = true
	var color: Color = Palette.frame_color(def)
	_style(frame, color)
	_style(inner, CREAM)
	var picture: Texture2D = art_texture(def, aspect)
	if def.is_personality():
		margin.visible = false
		person.visible = true
		_show_person(def, aspect, color, picture, energy, standing)
	else:
		person.visible = false
		margin.visible = true
		_show_standard(def, color, picture)


func _show_standard(def: CardDef, color: Color, picture: Texture2D) -> void:
	var art_height: float = float(ART_HEIGHTS.get(def.type, 280))
	art.custom_minimum_size = Vector2(0, art_height)
	_style(art, color.darkened(0.35), 14)
	art_image.texture = picture
	art_image.visible = picture != null
	_mark_type(def, picture != null)
	title_label.text = def.title
	title_label.add_theme_color_override("font_color", INK)
	type_rest.text = _type_rest(def)
	type_rest.add_theme_color_override("font_color", INK)
	_fit_text(text_label, CardText.rules_text(def), CONTENT_HEIGHT - STANDARD_FIXED - art_height)
	# Energy cost as a round badge over the art, where the eye checks it first.
	var cost: int = 0
	if def.is_attack():
		cost = int(def.attack.get("cost_stages", 2 if def.attack_kind() == "art" else 0))
	cost_badge.visible = cost > 0
	cost_num.text = str(cost)
	# The base attack in the other corner: what the card adds before the table and the modifiers.
	var badge: Dictionary = CardText.attack_badge(def)
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
	left_badge.text = ""
	right_badge.text = "Endurance %d" % def.endurance if def.endurance > 0 else ""
	for l in [left_badge, right_badge]:
		l.add_theme_color_override("font_color", INK)


func _show_person(def: CardDef, aspect: int, color: Color, picture: Texture2D, energy: int = -1, standing: SeatPlayer = null) -> void:
	var t: int = aspect if aspect > 0 else def.lowest_aspect()
	var td: Dictionary = def.aspect_data(t)
	var dark: Color = color.darkened(0.45)
	_round(p_aspect_box, dark, 12)
	p_aspect_num.text = str(t)
	p_aspect_num.add_theme_color_override("font_color", Color.WHITE)
	p_aspect_word.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	p_name.text = def.title
	p_name.add_theme_color_override("font_color", INK)
	p_aspect_name.text = CardText.aspect_name(t, def).to_upper()
	p_aspect_name.add_theme_color_override("font_color", Color(INK, 0.65))
	# Icon-only chip up here; the art glyph and the HUD already say Duelist or Ally in words.
	_round(p_type_chip, Palette.type_ink(def.type), 8, 6, 6)
	p_type_icon.type = def.type
	p_type_icon.color = Color.WHITE
	_style(p_art, color.darkened(0.35), 14)
	p_art_image.texture = picture
	p_art_image.visible = picture != null
	p_glyph_icon.visible = picture == null
	p_glyph_icon.type = def.type
	p_glyph_icon.color = Color(1, 1, 1, 0.3)
	var might: Array = td.get("might", [])
	for i in range(STAGES):
		var stage: int = STAGES - i
		var lit: bool = stage == energy
		_round(_stage_rows[i], ZenithTheme.ENERGY.darkened(0.15) if lit else dark, 8, 8, 2)
		_stage_labels[i].add_theme_color_override("font_color", Color(1, 1, 1, 0.95 if lit else 0.55))
		_stage_values[i].text = CardText.short_number(int(might[stage])) if might.size() > stage else ""
		_stage_values[i].add_theme_color_override("font_color", Color.WHITE)
	var spent: bool = energy == 0
	_round(p_surge, (ZenithTheme.WARN if spent else ZenithTheme.ENERGY).darkened(0.35), 12)
	p_fervor.visible = standing != null
	if standing != null:
		_show_fervor(standing.fervor, standing.fervor_needed)
	p_surge_num.text = str(standing.recover_gain if standing != null else int(td.get("surge", 0)))
	p_surge_num.add_theme_color_override("font_color", Color.WHITE)
	p_surge_word.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_fit_text(p_text, "\n".join(CardText.aspect_text(def, t)), PERSON_TEXT_HEIGHT)


## One pip per point of Fervor needed, on the aspect-name line so the head keeps its height and
## the art box its shape; the row grows or shrinks as effects move the mark.
func _show_fervor(fervor: int, needed: int) -> void:
	while _fervor_pips.size() < needed:
		var pip: Panel = Panel.new()
		pip.custom_minimum_size = Vector2(14, 14)
		p_fervor.add_child(pip)
		_fervor_pips.append(pip)
	for i in range(_fervor_pips.size()):
		_fervor_pips[i].visible = i < needed
		var style: StyleBoxFlat = ZenithTheme.pip(true, ZenithTheme.ACCENT if i < fervor else Color(INK, 0.15), true)
		_fervor_pips[i].add_theme_stylebox_override("panel", style)


## Card art lives in assets/card_art/<id>.png; duelists may add <id>_a<aspect>.png per aspect.
## Missing art falls back to the type glyph.
static func art_texture(def: CardDef, aspect: int = 0) -> Texture2D:
	var candidates: Array[String] = []
	if def.is_personality():
		var t: int = aspect if aspect > 0 else def.lowest_aspect()
		candidates.append("%s%s_a%d.png" % [ART_DIR, def.id, t])
	candidates.append("%s%s.png" % [ART_DIR, def.id])
	for path in candidates:
		if ResourceLoader.exists(path, "Texture2D"):
			return load(path) as Texture2D
	return null


func show_back() -> void:
	_style(frame, Palette.BACK_COLOR)
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


## Sets the text at the largest size from TEXT_SIZES whose wrapped height fits the box, so a
## wordy card and a short one share the same layout and only the type size differs. The
## keyword markup may bold a word or two, so a little headroom is kept in the measure.
func _fit_text(label: KeywordLabel, plain: String, box_height: float) -> void:
	var font: Font = label.get_theme_font("normal_font")
	var chosen: int = TEXT_SIZES[TEXT_SIZES.size() - 1]
	for size in TEXT_SIZES:
		var h: float = font.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, CONTENT_WIDTH - 6.0, size, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
		if h <= box_height - 6.0:
			chosen = size
			break
	label.add_theme_font_size_override("normal_font_size", chosen)
	label.add_theme_font_size_override("bold_font_size", chosen)
	label.add_theme_color_override("default_color", INK)
	label.set_plain(plain)


func _style(panel: Panel, color: Color, radius: int = 22) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
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


## What follows the type chip: the school, and any alignment gate.
func _type_rest(def: CardDef) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(CardText.school_name(def.school))
	if def.alignment_only != "":
		parts.append(def.alignment_only.capitalize() + "s only")
	return " · ".join(parts)
