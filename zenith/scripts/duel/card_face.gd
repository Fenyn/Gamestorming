class_name CardFace
extends Control
## Draws one card face procedurally. Rendered once per definition into a texture by CardFaceCache,
## and also used directly for the hover zoom.
##
## Two layouts share the frame. Personalities (Fighters, Allies) get a portrait: tier box and
## name across the top, art filling the left, the ten-stage Might ladder down the right with the
## Surge badge under it, and the tier's power text along the bottom. Everything else gets the
## standard face: title, type chip, art that takes whatever the rules text leaves, the text box
## sized to its content, with a Vigor cost badge over the art and Endurance under the text.
## Long rules step the font down rather than push the art out.

const ART_DIR: String = "res://assets/card_art/"
const INK: Color = Color(0.10, 0.08, 0.06)
const CREAM: Color = Color(0.93, 0.90, 0.84)
const CONTENT_WIDTH: float = 452.0        # face width less the margins
const TEXT_SIZES: Array[int] = [24, 22, 20, 18, 16]
const STANDARD_TEXT_MAX: float = 330.0    # room for rules text before the art hits its floor
const PERSON_TEXT_MAX: float = 200.0
const STAGES: int = 10

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
@onready var p_tier_box: PanelContainer = $Person/Column/Head/TierBox
@onready var p_tier_num: Label = $Person/Column/Head/TierBox/Col/Num
@onready var p_tier_word: Label = $Person/Column/Head/TierBox/Col/Word
@onready var p_name: Label = $Person/Column/Head/Names/Name
@onready var p_tier_name: Label = $Person/Column/Head/Names/TierName
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


func show_def(def: CardDef, tier: int = 0) -> void:
	inner.visible = true
	var color: Color = Palette.frame_color(def)
	_style(frame, color)
	_style(inner, CREAM)
	var picture: Texture2D = art_texture(def, tier)
	if def.is_personality():
		margin.visible = false
		person.visible = true
		_show_person(def, tier, color, picture)
	else:
		person.visible = false
		margin.visible = true
		_show_standard(def, color, picture)


func _show_standard(def: CardDef, color: Color, picture: Texture2D) -> void:
	_style(art, color.darkened(0.35), 14)
	art_image.texture = picture
	art_image.visible = picture != null
	_mark_type(def, picture != null)
	title_label.text = def.title
	title_label.add_theme_color_override("font_color", INK)
	type_rest.text = _type_rest(def)
	type_rest.add_theme_color_override("font_color", INK)
	_fit_text(text_label, CardText.rules_text(def), STANDARD_TEXT_MAX)
	# Vigor cost as a round badge over the art, where the eye checks it first.
	var cost: int = 0
	if def.is_attack():
		cost = int(def.attack.get("cost_stages", 2 if def.attack_kind() == "art" else 0))
	cost_badge.visible = cost > 0
	cost_num.text = str(cost)
	_round(cost_badge, ZenithTheme.VIGOR.darkened(0.35), 34)
	cost_num.add_theme_color_override("font_color", Color.WHITE)
	cost_word.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	left_badge.text = ""
	right_badge.text = "Endurance %d" % def.endurance if def.endurance > 0 else ""
	badges.visible = left_badge.text != "" or right_badge.text != ""
	for l in [left_badge, right_badge]:
		l.add_theme_color_override("font_color", INK)


func _show_person(def: CardDef, tier: int, color: Color, picture: Texture2D) -> void:
	var t: int = tier if tier > 0 else def.lowest_tier()
	var td: Dictionary = def.tier_data(t)
	var dark: Color = color.darkened(0.45)
	_round(p_tier_box, dark, 12)
	p_tier_num.text = str(t)
	p_tier_num.add_theme_color_override("font_color", Color.WHITE)
	p_tier_word.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	p_name.text = def.title
	p_name.add_theme_color_override("font_color", INK)
	p_tier_name.text = CardText.tier_name(t).to_upper()
	p_tier_name.add_theme_color_override("font_color", Color(INK, 0.65))
	# Icon-only chip up here; the art glyph and the HUD already say Fighter or Ally in words.
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
		_round(_stage_rows[i], dark, 8, 8, 2)
		_stage_labels[i].add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		_stage_values[i].text = CardText.short_number(int(might[stage])) if might.size() > stage else ""
		_stage_values[i].add_theme_color_override("font_color", Color.WHITE)
	_round(p_surge, ZenithTheme.VIGOR.darkened(0.35), 12)
	p_surge_num.text = str(int(td.get("surge", 0)))
	p_surge_num.add_theme_color_override("font_color", Color.WHITE)
	p_surge_word.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_fit_text(p_text, "\n".join(CardText.tier_text(def, t)), PERSON_TEXT_MAX)


## Card art lives in assets/card_art/<id>.png; fighters may add <id>_t<tier>.png per tier.
## Missing art falls back to the type glyph.
static func art_texture(def: CardDef, tier: int = 0) -> Texture2D:
	var candidates: Array[String] = []
	if def.is_personality():
		var t: int = tier if tier > 0 else def.lowest_tier()
		candidates.append("%s%s_t%d.png" % [ART_DIR, def.id, t])
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


## Sets the text at the largest size from TEXT_SIZES whose wrapped height fits `max_height`,
## so a wordy card keeps its art and a short one keeps big type.
func _fit_text(label: KeywordLabel, plain: String, max_height: float) -> void:
	var font: Font = label.get_theme_font("normal_font")
	var chosen: int = TEXT_SIZES[TEXT_SIZES.size() - 1]
	for size in TEXT_SIZES:
		var h: float = font.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, CONTENT_WIDTH, size, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
		if h <= max_height:
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
## an art-less art box, and the round badge over real art. Tokens keep their number as the big
## glyph since the number is what matters at the table.
func _mark_type(def: CardDef, has_art: bool) -> void:
	_chip(type_chip, type_icon, type_name, def.type)
	var token: bool = def.type == CardDef.Type.TOKEN
	glyph.visible = not has_art and token
	glyph.text = str(def.token_number)
	glyph.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	glyph_icon.visible = not has_art and not token
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


## What follows the type chip: the guild, and any alignment gate.
func _type_rest(def: CardDef) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(CardText.guild_name(def.guild))
	if def.alignment_only != "":
		parts.append(def.alignment_only.capitalize() + "s only")
	return " · ".join(parts)
