class_name ProgressUI
extends RefCounted
## Builders for the repeated rows of the journal and the win results: rail and next-up tiles,
## achievement rows, milestone tiles, deck rows, XP bars and result cards. Fixed layout stays in
## the scenes.

const MILESTONE_WIDTH: float = 216.0
const MILESTONE_ART: Vector2 = Vector2(192, 108)

static var _portraits: Dictionary = {}   # character -> Texture2D, or null when no art


static func label(text: String, variation: String, colour: Color = Color(0, 0, 0, 0)) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if colour.a > 0.0:
		l.add_theme_color_override("font_color", colour)
	return l


## A one-line label. `clip` trims it with an ellipsis, which also drops its minimum width to
## nothing, so a label that must show in full inside an HBox passes false.
static func line(text: String, variation: String, colour: Color = Color(0, 0, 0, 0), clip: bool = true) -> Label:
	var l: Label = label(text, variation, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	if clip:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


static func chip(text: String, colour: Color, filled: bool) -> Label:
	var l: Label = label(text, "CaptionLabel")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ZenithTheme.chip(l, colour, filled)
	return l


static func card(edge: Color, bg: Color = ZenithTheme.RAISED) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", ZenithTheme.edged(edge, bg, ZenithTheme.RADIUS, ZenithTheme.GAP, ZenithTheme.GAP_S))
	return p


static func hbox(separation: int) -> HBoxContainer:
	var b: HBoxContainer = HBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func vbox(separation: int) -> VBoxContainer:
	var b: VBoxContainer = VBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


## A page section heading: the title, an optional count on the right, and a rule under both.
static func section(title: String, count: String = "") -> Control:
	var box: VBoxContainer = vbox(ZenithTheme.GAP_XS)
	var row: HBoxContainer = hbox(ZenithTheme.GAP_S)
	var name_label: Label = line(title, "RowTitleLabel", ZenithTheme.TEXT_SOFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	if count != "":
		row.add_child(line(count, "BodyLabel", Color(0, 0, 0, 0), false))
	box.add_child(row)
	box.add_child(HSeparator.new())
	return box


## A rail group label: small capitals over a rule.
static func rail_label(title: String) -> Control:
	var box: VBoxContainer = vbox(ZenithTheme.GAP_XS)
	box.add_child(line(title.to_upper(), "CaptionLabel"))
	box.add_child(HSeparator.new())
	return box


## The top square of a character's first Aspect art, so a tall portrait keeps its head.
static func portrait_texture(character: String, library: CardLibrary) -> Texture2D:
	if _portraits.has(character):
		return _portraits[character]
	var out: Texture2D = null
	for id in library.all_ids():
		var def: CardDef = library.defs[id]
		if def.is_personality() and def.character == character and def.aspect == 1:
			var art: Texture2D = CardFace.art_texture(def, 1)
			if art != null:
				var side: float = minf(art.get_width(), art.get_height())
				var top: AtlasTexture = AtlasTexture.new()
				top.atlas = art
				top.region = Rect2((art.get_width() - side) * 0.5, 0.0, side, side)
				out = top
			break
	_portraits[character] = out
	return out


## A framed square portrait. `locked` greys it for a character the player cannot start yet;
## `mirrored` flips it to face left.
static func portrait(character: String, library: CardLibrary, size: float, locked: bool = false, mirrored: bool = false) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.BORDER, ZenithTheme.RADIUS, 1, 1, 1))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rect: TextureRect = TextureRect.new()
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.clip_contents = true
	rect.texture = portrait_texture(character, library)
	rect.flip_h = mirrored
	if locked:
		rect.modulate = ZenithTheme.TEXT_DISABLED
	frame.add_child(rect)
	return frame


## The one XP bar: a sunken track with a 1 px rule, so an empty bar still reads as a bar.
static func xp_bar(height: float) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = height
	bar.add_theme_stylebox_override("background", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.BORDER, ZenithTheme.RADIUS, 1, 0, 0))
	bar.add_theme_stylebox_override("fill", ZenithTheme.box(ZenithTheme.XP, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 0, 0))
	return bar


## Fills a bar to a {level, xp, from, to} standing.
static func set_standing(bar: ProgressBar, standing: Dictionary) -> void:
	bar.min_value = float(standing["from"])
	bar.max_value = float(maxi(int(standing["to"]), int(standing["from"]) + 1))
	bar.value = float(standing["xp"])


## "70 / 250 XP to Lv 5".
static func xp_numbers(standing: Dictionary) -> String:
	return "%d / %d XP to Lv %d" % [int(standing["xp"]) - int(standing["from"]),
		int(standing["to"]) - int(standing["from"]), int(standing["level"]) + 1]


## A selectable tile holding `content`: the theme's TileButton, with the content laid over it and
## blind to the mouse so the button takes every click.
static func tile_button(content: Control, min_height: float, toggle: bool) -> Button:
	var b: Button = Button.new()
	b.theme_type_variation = &"TileButton"
	b.toggle_mode = toggle
	b.custom_minimum_size.y = min_height
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", ZenithTheme.GAP)
	pad.add_theme_constant_override("margin_right", ZenithTheme.GAP)
	pad.add_theme_constant_override("margin_top", ZenithTheme.GAP_S)
	pad.add_theme_constant_override("margin_bottom", ZenithTheme.GAP_S)
	pad.add_child(content)
	b.add_child(pad)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ignore_mouse(pad)
	return b


static func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_mouse(child as Control)


## One journal row from AdventureAchievements.journal(). The state is the edge and one chip:
## done is a bone badge, a started chain an iron tag with its steps, an open one a muted tag.
static func achievement_row(row: Dictionary) -> PanelContainer:
	var state: String = str(row["state"])
	if state == "unknown":
		return _hidden_row(row)
	var edge: Color = {"complete": ZenithTheme.ACCENT, "progress": ZenithTheme.FRAME}.get(state, ZenithTheme.FRAME_DIM)
	var p: PanelContainer = card(edge)
	var text: VBoxContainer = vbox(ZenithTheme.GAP_XS)
	p.add_child(text)
	var head: HBoxContainer = hbox(ZenithTheme.GAP_S)
	text.add_child(head)
	var title: Label = label(str(row["title"]), "RowTitleLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var total: int = int(row["total"])
	match state:
		"complete":
			head.add_child(chip("SECRET" if bool(row.get("secret", false)) else "DONE", ZenithTheme.ACCENT, true))
		"progress":
			head.add_child(chip("%d of %d" % [int(row["done"]), total], ZenithTheme.FRAME, false))
		_:
			head.add_child(chip("%d STEPS" % total if total > 1 else "OPEN", ZenithTheme.MUTED, false))
	if str(row["hint"]) != "":
		text.add_child(label(str(row["hint"]), "BodyLabel"))
	if str(row["reward"]) != "":
		text.add_child(label(("Earned: " if state == "complete" else "Reward: ") + str(row["reward"]), "BodyLabel", ZenithTheme.TEXT))
	return p


## A hidden achievement before its first step: a sunken slot led by its teaser.
static func _hidden_row(row: Dictionary) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.BORDER, ZenithTheme.RADIUS, 1, ZenithTheme.GAP, ZenithTheme.GAP_S))
	var row_box: HBoxContainer = hbox(ZenithTheme.GAP_S)
	p.add_child(row_box)
	var teaser: Label = label(str(row["hint"]) if str(row["hint"]) != "" else "An achievement not yet found.", "BodyLabel")
	teaser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.add_child(teaser)
	row_box.add_child(chip("HIDDEN", ZenithTheme.MUTED, false))
	return p


## One level of a track, naming its reward in full. `state` is "reached", "next" or "later"; only
## the next one is ringed. A card reward shows its art; anything else a sunken plate naming what
## it is, in `plate_colour`.
static func milestone_tile(level_text: String, reward: String, card_id: String, plate: String,
		plate_colour: Color, state: String, library: CardLibrary) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.custom_minimum_size.x = MILESTONE_WIDTH
	var next: bool = state == "next"
	p.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT if state == "later" else ZenithTheme.RAISED,
		ZenithTheme.XP if next else ZenithTheme.BORDER, ZenithTheme.RADIUS, 2 if next else 1, ZenithTheme.GAP_S, ZenithTheme.GAP_S))
	var column: VBoxContainer = vbox(ZenithTheme.GAP_XS)
	p.add_child(column)
	var head: HBoxContainer = hbox(ZenithTheme.GAP_XS)
	column.add_child(head)
	var level_label: Label = line(level_text, "CaptionLabel", ZenithTheme.TEXT if state != "later" else ZenithTheme.MUTED)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(level_label)
	if state == "reached":
		head.add_child(chip("EARNED", ZenithTheme.ACCENT, false))
	elif next:
		head.add_child(chip("NEXT", ZenithTheme.XP, true))
	var texture: Texture2D = null
	if card_id != "" and library.has(card_id):
		texture = CardFace.art_texture(library.get_def(card_id), library.get_def(card_id).aspect)
	if texture != null:
		var art: TextureRect = TextureRect.new()
		art.custom_minimum_size = MILESTONE_ART
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.clip_contents = true
		art.texture = texture
		if state == "later":
			art.modulate = ZenithTheme.TEXT_DISABLED
		column.add_child(art)
	else:
		var box: PanelContainer = PanelContainer.new()
		box.custom_minimum_size = MILESTONE_ART
		box.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, ZenithTheme.GAP_XS, ZenithTheme.GAP_XS))
		var name_label: Label = label(plate, "CaptionLabel", plate_colour if state != "later" else ZenithTheme.MUTED)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		column.add_child(box)
	column.add_child(label(reward, "CaptionLabel", ZenithTheme.TEXT_SOFT if state != "later" else ZenithTheme.MUTED))
	return p


## One deck of a character: its name on a school edge, OPEN or LOCKED, and each route that opens it
## with how far along it is.
static func deck_row(deck_name: String, school: String, open: bool, routes: Array[Dictionary]) -> PanelContainer:
	var p: PanelContainer = card(Palette.school_ui(school))
	var column: VBoxContainer = vbox(ZenithTheme.GAP_XS)
	p.add_child(column)
	var head: HBoxContainer = hbox(ZenithTheme.GAP_S)
	column.add_child(head)
	var title: Label = line(deck_name, "RowTitleLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(chip("OPEN", ZenithTheme.ACCENT, true) if open else chip("LOCKED", ZenithTheme.MUTED, false))
	if open:
		return p
	if routes.is_empty():
		column.add_child(label("A hidden route.", "BodyLabel", ZenithTheme.MUTED))
	for route in routes:
		var row: HBoxContainer = hbox(ZenithTheme.GAP_S)
		var what: Label = label(str(route["text"]), "BodyLabel", ZenithTheme.TEXT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(what)
		row.add_child(line("%d of %d" % [int(route["done"]), int(route["total"])], "CaptionLabel", Color(0, 0, 0, 0), false))
		column.add_child(row)
		if str(route.get("hint", "")) != "":
			column.add_child(label(str(route["hint"]), "CaptionLabel", ZenithTheme.TEXT_SOFT))
	return p


## One win result from AdventureProgress.record_win. The XP result is a set of filling bars;
## `delay` is when its fill starts, and `animate` false draws the bars already full.
static func result_card(entry: Dictionary, animate: bool = false, delay: float = 0.0) -> PanelContainer:
	if str(entry.get("kind", "")) == "xp" and entry.has("bars"):
		return xp_gain_card(entry.get("bars", []), animate, delay)
	var colour: Color = {"xp": ZenithTheme.XP, "level": ZenithTheme.XP, "school": ZenithTheme.XP,
		"achievement": ZenithTheme.ACCENT}.get(str(entry.get("kind", "")), ZenithTheme.FRAME)
	var p: PanelContainer = card(colour, ZenithTheme.RAISED_STRONG)
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
	var p: PanelContainer = card(ZenithTheme.XP, ZenithTheme.RAISED_STRONG)
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
		var bar: ProgressBar = xp_bar(12)
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
