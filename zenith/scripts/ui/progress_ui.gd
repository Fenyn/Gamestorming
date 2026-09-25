class_name ProgressUI
extends RefCounted
## Builders for the repeated rows of the journal and the win results: achievement cards, XP rows
## and result cards. Fixed layout stays in the scenes.

const PORTRAIT: float = 60.0


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
	p.add_theme_stylebox_override("panel", ZenithTheme.edged(edge, bg, ZenithTheme.RADIUS, 18, 12))
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
	# The status sits on the title line so the hint and reward below get the card's full width.
	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override("separation", 6)
	p.add_child(text)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	text.add_child(head)
	var unknown: bool = state == "unknown"
	var title: Label = label(str(row["title"]), "RowTitleLabel", Color(ZenithTheme.TEXT_SOFT, 0.6) if unknown else ZenithTheme.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var side: HBoxContainer = HBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_END
	side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side.add_theme_constant_override("separation", 10)
	head.add_child(side)
	if str(row["hint"]) != "":
		text.add_child(label(str(row["hint"]), "BodyLabel"))
	if str(row["reward"]) != "":
		var prefix: String = "Earned: " if state == "complete" else "Reward: "
		text.add_child(label(prefix + str(row["reward"]), "BodyLabel",
			ZenithTheme.ACCENT if state == "complete" else ZenithTheme.TEXT))
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
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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


## A character or school row: name, level chip, bar, XP numbers, and the next reward below. The
## chip and bar are always XP; `identity` (a school colour, or clear) tints the name only.
static func xp_row(name: String, standing: Dictionary, next_text: String, identity: Color, striped: bool) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.RAISED if striped else Color(0, 0, 0, 0),
		Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 12, 12))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	p.add_child(column)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var name_label: Label = label(name, "RowTitleLabel", identity.lightened(0.15) if identity.a > 0.0 else Color(0, 0, 0, 0))
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	row.add_child(name_label)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var level_chip: Label = chip("Lv %d" % int(standing["level"]), ZenithTheme.XP, true)
	level_chip.custom_minimum_size.x = 72
	row.add_child(level_chip)
	var bar: ProgressBar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 12
	bar.show_percentage = false
	bar.min_value = float(standing["from"])
	bar.max_value = float(maxi(int(standing["to"]), int(standing["from"]) + 1))
	bar.value = float(standing["xp"])
	bar.add_theme_stylebox_override("fill", ZenithTheme.box(ZenithTheme.XP, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 0, 0))
	var numbers: Label = label("%d / %d XP to Lv %d" % [int(standing["xp"]) - int(standing["from"]),
		int(standing["to"]) - int(standing["from"]), int(standing["level"]) + 1], "BodyLabel")
	numbers.autowrap_mode = TextServer.AUTOWRAP_OFF
	numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(numbers)
	column.add_child(bar)
	if next_text != "":
		column.add_child(label(next_text, "CaptionLabel"))
	return p


## One win result from AdventureProgress.record_win. The XP result is a set of filling bars;
## `delay` is when its fill starts, and `animate` false draws the bars already full.
static func result_card(entry: Dictionary, animate: bool = false, delay: float = 0.0) -> PanelContainer:
	if str(entry.get("kind", "")) == "xp" and entry.has("bars"):
		return xp_gain_card(entry.get("bars", []), animate, delay)
	var colour: Color = {"xp": ZenithTheme.XP, "level": ZenithTheme.XP, "school": ZenithTheme.XP,
		"achievement": ZenithTheme.ACCENT}.get(str(entry.get("kind", "")), ZenithTheme.FRAME)
	var p: PanelContainer = card(colour)
	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override("separation", 4)
	p.add_child(text)
	text.add_child(label(str(entry.get("tag", "")), "CaptionLabel", colour.lightened(0.1)))
	text.add_child(label(str(entry.get("title", "")), "RowTitleLabel"))
	for d in entry.get("details", []):
		text.add_child(label(str(d), "BodyLabel"))
	return p


const FILL_SECONDS: float = 0.9     # one level's worth of bar
const BAR_STAGGER: float = 0.25     # between one track's fill and the next


## One row per track that gained XP: name, level chip, the gain, and a bar that fills from where
## the track stood to where it stands now, rolling over at each level with a pulse on the chip.
static func xp_gain_card(bars: Array, animate: bool, delay: float) -> PanelContainer:
	var p: PanelContainer = card(ZenithTheme.XP)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	p.add_child(column)
	var tag: Label = label("XP", "CaptionLabel", ZenithTheme.XP.lightened(0.1))
	column.add_child(tag)
	for i in range(bars.size()):
		var track: Dictionary = bars[i]
		var segments: Array = track.get("segments", [])
		if segments.is_empty():
			continue
		var first: Dictionary = segments[0]
		var last: Dictionary = segments[segments.size() - 1]
		var rows: VBoxContainer = VBoxContainer.new()
		rows.add_theme_constant_override("separation", 6)
		column.add_child(rows)
		var head: HBoxContainer = HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		rows.add_child(head)
		var school: String = str(track.get("school", ""))
		var name_label: Label = label(str(track.get("name", "")), "RowTitleLabel",
			Palette.school_ui(school) if school != "" else Color(0, 0, 0, 0))
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		var gain: Label = label("+%d XP" % int(track.get("gained", 0)), "BodyLabel", ZenithTheme.XP.lightened(0.2))
		gain.autowrap_mode = TextServer.AUTOWRAP_OFF
		gain.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(gain)
		var level_chip: Label = chip("", ZenithTheme.XP, true)
		level_chip.custom_minimum_size.x = 84
		head.add_child(level_chip)
		var bar: ProgressBar = ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 14
		bar.add_theme_stylebox_override("background", ZenithTheme.box(ZenithTheme.BG_INPUT, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 0, 0))
		bar.add_theme_stylebox_override("fill", ZenithTheme.box(ZenithTheme.XP, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 0, 0))
		rows.add_child(bar)
		var reached: bool = int(last["end"]) >= int(last["to"])
		var final_level: int = int(last["level"]) + (1 if reached else 0)
		if not animate:
			_bar_segment(bar, last)
			bar.value = float(last["end"])
			level_chip.text = "Lv %d" % final_level
			continue
		_bar_segment(bar, first)
		bar.value = float(first["start"])
		level_chip.text = "Lv %d" % int(first["level"])
		var start_at: float = delay + BAR_STAGGER * i
		bar.ready.connect(func() -> void: _play_fill(bar, level_chip, segments, start_at), CONNECT_ONE_SHOT)
	return p


static func _bar_segment(bar: ProgressBar, segment: Dictionary) -> void:
	bar.min_value = float(segment["from"])
	bar.max_value = float(maxi(int(segment["to"]), int(segment["from"]) + 1))


static func _play_fill(bar: ProgressBar, level_chip: Label, segments: Array, start_at: float) -> void:
	var tween: Tween = bar.create_tween()
	tween.tween_interval(start_at)
	for segment in segments:
		var s: Dictionary = segment
		tween.tween_callback(func() -> void: _bar_segment(bar, s))
		tween.tween_callback(func() -> void: bar.value = float(s["start"]))
		var span: float = float(int(s["end"]) - int(s["start"])) / float(maxi(1, int(s["to"]) - int(s["from"])))
		tween.tween_property(bar, "value", float(s["end"]), maxf(0.2, FILL_SECONDS * span)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if int(s["end"]) >= int(s["to"]):
			tween.tween_callback(func() -> void: _level_up(level_chip, int(s["level"]) + 1))
			tween.tween_interval(0.35)


static func _level_up(level_chip: Label, level: int) -> void:
	level_chip.text = "Lv %d" % level
	level_chip.pivot_offset = level_chip.size * 0.5
	level_chip.modulate = Color(1.6, 1.6, 1.6)
	var pulse: Tween = level_chip.create_tween()
	pulse.tween_property(level_chip, "scale", Vector2.ONE * 1.2, 0.12)
	pulse.parallel().tween_property(level_chip, "modulate", Color.WHITE, 0.4)
	pulse.tween_property(level_chip, "scale", Vector2.ONE, 0.2)
