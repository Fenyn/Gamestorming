class_name ProgressUI
extends RefCounted
## Builders for the repeated rows of the journal and the win results: achievement cards, XP rows
## and result cards. Fixed layout stays in the scenes.

const CHIP_WIDTH: float = 190.0
const PORTRAIT: float = 56.0
const XP_COLOUR: Color = Color(0.62, 0.55, 0.90)


static func label(text: String, variation: String, colour: Color = Color(0, 0, 0, 0)) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if colour.a > 0.0:
		l.add_theme_color_override("font_color", colour)
	return l


static func chip(text: String, colour: Color, filled: bool) -> Label:
	var l: Label = label(text, "CaptionLabel")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ZenithTheme.chip(l, colour, filled)
	return l


static func state_text(text: String, colour: Color) -> Label:
	var l: Label = label(text, "CaptionLabel", colour)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func card(edge: Color, bg: Color = ZenithTheme.RAISED_STRONG) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", ZenithTheme.edged(edge, bg, 6, 18, 14))
	return p


static func portrait(character: String, library: CardLibrary) -> Control:
	var rect: TextureRect = TextureRect.new()
	rect.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.clip_contents = true
	for id in library.all_ids():
		var def: CardDef = library.defs[id]
		if def.is_personality() and def.character == character and def.aspect == 1:
			rect.texture = CardFace.art_texture(def, 1)
			break
	return rect


## A heading row: portrait (when there is a character), name, and a right-aligned count.
static func group_header(title: String, count: String, character: String, library: CardLibrary) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	if character != "":
		var art: Control = portrait(character, library)
		row.add_child(art)
	var name_label: Label = label(title, "GroupLabel" if character != "" else "RowTitleLabel",
		ZenithTheme.TEXT if character != "" else ZenithTheme.TEXT_SOFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	if count != "":
		var c: Label = label(count, "BodyLabel")
		c.autowrap_mode = TextServer.AUTOWRAP_OFF
		c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(c)
	box.add_child(row)
	box.add_child(HSeparator.new())
	return box


## One journal row from AdventureAchievements.journal().
static func achievement_card(row: Dictionary) -> PanelContainer:
	var state: String = str(row["state"])
	var edge: Color = {"complete": ZenithTheme.ACCENT, "progress": ZenithTheme.ENERGY,
		"open": ZenithTheme.MIGHT, "unknown": ZenithTheme.MUTED}.get(state, ZenithTheme.MUTED)
	var bg: Color = ZenithTheme.BG_ACTIVE if state == "complete" else ZenithTheme.RAISED_STRONG
	var p: PanelContainer = card(edge, bg)
	p.custom_minimum_size.y = 96
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	p.add_child(line)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	line.add_child(text)
	var unknown: bool = state == "unknown"
	text.add_child(label(str(row["title"]), "RowTitleLabel", Color(ZenithTheme.TEXT_SOFT, 0.6) if unknown else ZenithTheme.TEXT))
	if str(row["hint"]) != "":
		text.add_child(label(str(row["hint"]), "BodyLabel"))
	if str(row["reward"]) != "":
		var prefix: String = "Earned: " if state == "complete" else "Reward: "
		text.add_child(label(prefix + str(row["reward"]), "BodyLabel",
			ZenithTheme.ACCENT if state == "complete" else ZenithTheme.TEXT))
	var side: VBoxContainer = VBoxContainer.new()
	side.custom_minimum_size.x = 150
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 8)
	line.add_child(side)
	var total: int = int(row["total"])
	var done: int = int(row["done"])
	match state:
		"complete":
			side.add_child(chip("SECRET" if bool(row.get("secret", false)) else "DONE", ZenithTheme.ACCENT, true))
		"unknown":
			side.add_child(state_text("HIDDEN", ZenithTheme.MUTED))
		_:
			if done > 0:
				side.add_child(chip("%d of %d" % [done, total], ZenithTheme.ENERGY, false))
			else:
				side.add_child(state_text("%d steps" % total if total > 1 else "OPEN", ZenithTheme.TEXT_SOFT))
	if total > 1 and not unknown:
		var pips: HBoxContainer = HBoxContainer.new()
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		pips.add_theme_constant_override("separation", 6)
		for i in range(total):
			var pip: Panel = Panel.new()
			pip.custom_minimum_size = Vector2(16, 16)
			pip.add_theme_stylebox_override("panel", ZenithTheme.pip(i < done, ZenithTheme.ACCENT if state == "complete" else ZenithTheme.ENERGY))
			pips.add_child(pip)
		side.add_child(pips)
	if unknown:
		p.modulate.a = 0.7
	return p


## A character or school row: name, level chip, bar, XP numbers, and the next reward below.
static func xp_row(name: String, standing: Dictionary, next_text: String, colour: Color, striped: bool) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.RAISED if striped else Color(0, 0, 0, 0),
		Color(0, 0, 0, 0), 4, 0, 14, 10))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	p.add_child(column)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var name_label: Label = label(name, "RowTitleLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	row.add_child(name_label)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var level_chip: Label = chip("Lv %d" % int(standing["level"]), colour, true)
	level_chip.custom_minimum_size.x = 72
	row.add_child(level_chip)
	var bar: ProgressBar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 10
	bar.show_percentage = false
	bar.min_value = float(standing["from"])
	bar.max_value = float(maxi(int(standing["to"]), int(standing["from"]) + 1))
	bar.value = float(standing["xp"])
	bar.add_theme_stylebox_override("background", ZenithTheme.box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 3, 0, 0, 0))
	bar.add_theme_stylebox_override("fill", ZenithTheme.box(colour, Color(0, 0, 0, 0), 3, 0, 0, 0))
	var numbers: Label = label("%d / %d XP to Lv %d" % [int(standing["xp"]) - int(standing["from"]),
		int(standing["to"]) - int(standing["from"]), int(standing["level"]) + 1], "BodyLabel")
	numbers.autowrap_mode = TextServer.AUTOWRAP_OFF
	numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(numbers)
	column.add_child(bar)
	if next_text != "":
		column.add_child(label(next_text, "CaptionLabel"))
	return p


## One win result from AdventureProgress.record_win.
static func result_card(entry: Dictionary) -> PanelContainer:
	var colour: Color = {"join": ZenithTheme.DEFEND, "xp": XP_COLOUR, "level": ZenithTheme.ENERGY,
		"school": ZenithTheme.ENERGY, "achievement": ZenithTheme.ACCENT}.get(str(entry.get("kind", "")), ZenithTheme.MIGHT)
	var p: PanelContainer = card(colour)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	p.add_child(row)
	var tag: Label = chip(str(entry.get("tag", "")), colour, true)
	tag.custom_minimum_size.x = CHIP_WIDTH
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(tag)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	text.add_child(label(str(entry.get("title", "")), "RowTitleLabel"))
	for d in entry.get("details", []):
		text.add_child(label(str(d), "BodyLabel"))
	return p
