extends Control
## The journal: a rail of characters, quests and schools, and one page per entry with its XP
## milestones, achievements and the routes to its decks. Next up shows the closest rewards.
## Read-only.

const RAIL_TILE_HEIGHT: float = 96.0
const NEXT_TILE_HEIGHT: float = 108.0
const NEXT_UP_MAX: int = 4
const PORTRAIT_RAIL: float = 72.0
const PORTRAIT_NEXT: float = 60.0
const PORTRAIT_STEP: float = 72.0
const PORTRAIT_PAGE: float = 144.0
const STICK_SCROLL: float = 1200.0   # page pixels a second at full right-stick tilt
const STICK_DEADZONE: float = 0.2

@onready var achieved_tile: StatTile = $Margin/Column/TitleRow/Achieved
@onready var decks_tile: StatTile = $Margin/Column/TitleRow/Decks
@onready var next_up: VBoxContainer = $Margin/Column/NextUp
@onready var next_tiles: HBoxContainer = $Margin/Column/NextUp/Tiles
@onready var rail_scroll: ScrollContainer = $Margin/Column/Body/Rail/Scroll
@onready var rail_list: VBoxContainer = $Margin/Column/Body/Rail/Scroll/Pad/List
@onready var page_scroll: ScrollContainer = $Margin/Column/Body/Page/Scroll
@onready var page: VBoxContainer = $Margin/Column/Body/Page/Scroll/Pad/Content
@onready var back_button: Button = $Margin/Column/Footer/Back

## One rail entry each: {kind: "character" | "quest" | "school", key, main}. `main` is true for a
## character with an open deck.
var _entries: Array[Dictionary] = []
var _tiles: Array[Button] = []
## Entry index -> the rail heading above it, for the first entry under each heading.
var _headings: Dictionary = {}
var _group: ButtonGroup = ButtonGroup.new()
var _rows: Array[Dictionary] = []
var _selected: int = -1
## Starter id -> its routes, and starter id -> reached only through a secret. Read once: both
## parse the data files on every call.
var _routes_of: Dictionary = {}
var _secret: Dictionary = {}
var _starters: Array[String] = []
var _stick: float = 0.0


func _ready() -> void:
	theme = SanctumUI.theme()
	SanctumUI.dress(self, $Margin/Column/TitleRow/Title as Label)
	back_button.pressed.connect(func() -> void: Session.leave_journal())
	if AdventureDev.flag("--dev-scratch=") != "":
		AdventureDev.use_scratch_saves()
	if AdventureDev.has_flag("--dev-sample"):
		AdventureDev.sample_meta()
	_rows = AdventureAchievements.journal(Session.unlocks, Session.library)
	_starters = AdventureDecks.playable_starters()
	for id in _starters:
		_routes_of[id] = AdventureAchievements.routes(id, Session.unlocks, Session.progress)
		_secret[id] = AdventureAchievements.secret_only(id)
	_collect_entries()
	_fill_counts()
	_fill_rail()
	_fill_next_up()
	SanctumUI.wire_buttons(self)
	var first: int = clampi(int(AdventureDev.flag("--dev-entry=")), 0, maxi(0, _tiles.size() - 1))
	if not _tiles.is_empty():
		_select(first)
		_focus_rail(first)
	AdventureDev.screenshot(self)


## Focus waits a frame: before the rail's first layout, follow_focus scrolls to stale positions.
func _focus_rail(index: int) -> void:
	await get_tree().process_frame
	_tiles[index].grab_focus()
	_reveal(index)


## Scrolls the rail to an entry and, when it is the first under a heading, the heading too.
func _reveal(index: int) -> void:
	rail_scroll.ensure_control_visible(_tiles[index])
	var heading: Control = _headings.get(index, null)
	if heading != null:
		rail_scroll.ensure_control_visible(heading)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Session.leave_journal()
	elif event.is_action_pressed("ui_page_down") or event.is_action_pressed("ui_page_up"):
		var step: int = int(page_scroll.size.y * 0.8)
		page_scroll.scroll_vertical += step if event.is_action_pressed("ui_page_down") else -step
		get_viewport().set_input_as_handled()


## The right stick scrolls the page while the rail keeps focus.
func _process(delta: float) -> void:
	var tilt: float = 0.0
	for device in Input.get_connected_joypads():
		var axis: float = Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
		if absf(axis) > absf(tilt):
			tilt = axis
	if absf(tilt) <= STICK_DEADZONE:
		_stick = 0.0
		return
	_stick += tilt * STICK_SCROLL * delta
	var whole: int = int(_stick)
	if whole != 0:
		page_scroll.scroll_vertical += whole
		_stick -= float(whole)


# --- Entries ------------------------------------------------------------------

## Characters with an open deck first, then everyone the player can already see a way to: XP,
## an authored track, a named achievement, or a deck with a route. Someone reached only through a
## secret stays off the rail. Then achievement groups that are not a character, then schools.
func _collect_entries() -> void:
	var mains: Array[String] = []
	var schools: Array[String] = []
	for id in Session.unlocks.available_starters():
		_add_unique(mains, AdventureDecks.character_of(AdventureDecks.family_of(id)))
		var deck: DeckList = DeckList.resolve(id)
		if deck != null:
			_add_unique(schools, deck.style)
	var others: Array[String] = []
	for id in _starters:
		if not Session.unlocks.is_open(id) and not _routes(id).is_empty():
			_add_unique(others, AdventureDecks.character_of(AdventureDecks.family_of(id)))
	for key in (AdventureProgress.data().get("tracks", {}) as Dictionary).keys():
		_add_unique(others, str(key))
	for key in Session.progress.personality_xp.keys():
		_add_unique(others, str(key))
	var quests: Array[String] = []
	for row in _rows:
		var group: String = str(row["group"])
		if group == str(row["character"]):
			_add_unique(others, group)
		else:
			_add_unique(quests, group)
	for c in mains:
		others.erase(c)
	others.sort()
	for key in Session.progress.school_xp.keys():
		_add_unique(schools, str(key))
	for c in mains:
		_entries.append({"kind": "character", "key": c, "main": true})
	for c in others:
		_entries.append({"kind": "character", "key": c, "main": false})
	for q in quests:
		_entries.append({"kind": "quest", "key": q, "main": false})
	for s in schools:
		_entries.append({"kind": "school", "key": s, "main": false})


func _add_unique(list: Array[String], value: String) -> void:
	if value != "" and not list.has(value):
		list.append(value)


func _routes(starter_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(_routes_of.get(starter_id, []))
	return out


## A locked deck the journal may show: one not reached only through a secret.
func _shown(starter_id: String) -> bool:
	return Session.unlocks.is_open(starter_id) or not bool(_secret.get(starter_id, false))


func _decks_of(character: String) -> Array[String]:
	var out: Array[String] = []
	for id in _starters:
		if AdventureDecks.character_of(AdventureDecks.family_of(id)) == character and _shown(id):
			out.append(id)
	return out


func _rows_in(group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in _rows:
		if str(row["group"]) == group:
			out.append(row)
	return out


func _done_count(rows: Array[Dictionary]) -> int:
	return rows.filter(func(r: Dictionary) -> bool: return str(r["state"]) == "complete").size()


func _fill_counts() -> void:
	achieved_tile.set_stat("Achievements", "%d of %d" % [_done_count(_rows), _rows.size()], "", ZenithTheme.TEXT)
	var open: int = 0
	var shown: int = 0
	for id in _starters:
		if Session.unlocks.is_open(id):
			open += 1
		if _shown(id):
			shown += 1
	decks_tile.set_stat("Decks open", "%d of %d" % [open, shown], "", ZenithTheme.TEXT)


# --- Rail ---------------------------------------------------------------------

func _fill_rail() -> void:
	var seen: Dictionary = {}
	for i in range(_entries.size()):
		var entry: Dictionary = _entries[i]
		var heading: String = _rail_heading(entry)
		if not seen.has(heading):
			seen[heading] = true
			var label: Control = ProgressUI.rail_label(heading)
			rail_list.add_child(label)
			_headings[i] = label
		var tile: Button = ProgressUI.tile_button(_rail_content(entry), RAIL_TILE_HEIGHT, true)
		tile.button_group = _group
		tile.pressed.connect(_select.bind(i))
		tile.focus_entered.connect(_select.bind(i))
		rail_list.add_child(tile)
		_tiles.append(tile)


func _rail_heading(entry: Dictionary) -> String:
	match str(entry["kind"]):
		"quest":
			return "Quests"
		"school":
			return "Schools"
	return "Your characters" if bool(entry["main"]) else "Allies and rivals"


func _rail_content(entry: Dictionary) -> Control:
	var key: String = str(entry["key"])
	var row: HBoxContainer = ProgressUI.hbox(ZenithTheme.GAP_S)
	var text: VBoxContainer = ProgressUI.vbox(ZenithTheme.GAP_XS)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	match str(entry["kind"]):
		"character":
			row.add_child(ProgressUI.portrait(key, Session.library, PORTRAIT_RAIL, _locked(entry)))
			text.add_child(ProgressUI.line(key, "RowTitleLabel"))
			var standing: Dictionary = Session.progress.personality_standing(key)
			var rows: Array[Dictionary] = _rows_in(key)
			var caption: String = "Lv %d" % int(standing["level"])
			if not rows.is_empty():
				caption += "  ·  %d of %d achievements" % [_done_count(rows), rows.size()]
			text.add_child(ProgressUI.line(caption, "CaptionLabel"))
			var bar: ProgressBar = ProgressUI.xp_bar(6)
			ProgressUI.set_standing(bar, standing)
			text.add_child(bar)
		"quest":
			var rows: Array[Dictionary] = _rows_in(key)
			text.add_child(ProgressUI.line(key, "RowTitleLabel"))
			text.add_child(ProgressUI.line("%d of %d achievements" % [_done_count(rows), rows.size()], "CaptionLabel"))
		"school":
			text.add_child(ProgressUI.line(key.capitalize(), "RowTitleLabel", Palette.school_ui(key)))
			var standing: Dictionary = Session.progress.school_standing(key)
			var library: Vector2i = AdventureProgress.school_library(key, Session.library, Session.collection)
			text.add_child(ProgressUI.line("Lv %d  ·  %d of %d cards" % [int(standing["level"]), library.x, library.y], "CaptionLabel"))
			var bar: ProgressBar = ProgressUI.xp_bar(6)
			ProgressUI.set_standing(bar, standing)
			text.add_child(bar)
	row.add_child(text)
	return row


## A character the player has not met and cannot start: greyed on the rail and the page.
func _locked(entry: Dictionary) -> bool:
	return not bool(entry["main"]) and int(Session.progress.personality_xp.get(str(entry["key"]), 0)) == 0


func _select(index: int) -> void:
	if index == _selected or index < 0 or index >= _entries.size():
		return
	_selected = index
	_tiles[index].set_pressed_no_signal(true)
	back_button.focus_neighbor_top = back_button.get_path_to(_tiles[index])
	_reveal.call_deferred(index)
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	var entry: Dictionary = _entries[index]
	match str(entry["kind"]):
		"character":
			_show_character(entry)
		"quest":
			_show_quest(str(entry["key"]))
		"school":
			_show_school(str(entry["key"]))
	page_scroll.scroll_vertical = 0


# --- Pages --------------------------------------------------------------------

## Picture (or none), name, a role caption, and the XP standing when there is one.
func _page_header(name: String, identity: Color, role: String, standing: Dictionary, picture: Control) -> void:
	var header: HBoxContainer = ProgressUI.hbox(ZenithTheme.GAP_L)
	page.add_child(header)
	if picture != null:
		header.add_child(picture)
	var column: VBoxContainer = ProgressUI.vbox(ZenithTheme.GAP_XS)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(column)
	column.add_child(ProgressUI.line(role.to_upper(), "CaptionLabel"))
	column.add_child(ProgressUI.line(name, "GroupLabel", identity))
	if standing.is_empty():
		return
	var numbers: HBoxContainer = ProgressUI.hbox(ZenithTheme.GAP_S)
	column.add_child(numbers)
	numbers.add_child(ProgressUI.chip("Lv %d" % int(standing["level"]), ZenithTheme.XP, true))
	numbers.add_child(ProgressUI.line(ProgressUI.xp_numbers(standing), "BodyLabel", Color(0, 0, 0, 0), false))
	var bar: ProgressBar = ProgressUI.xp_bar(12)
	ProgressUI.set_standing(bar, standing)
	column.add_child(bar)


func _show_character(entry: Dictionary) -> void:
	var character: String = str(entry["key"])
	var main: bool = bool(entry["main"])
	var progress: AdventureProgress = Session.progress
	_page_header(character, Color(0, 0, 0, 0), "Your character" if main else "Ally or rival",
		progress.personality_standing(character), ProgressUI.portrait(character, Session.library, PORTRAIT_PAGE, _locked(entry)))
	page.add_child(ProgressUI.label(_xp_how(main), "CaptionLabel"))

	var milestones: Array[Dictionary] = progress.milestones(character)
	page.add_child(ProgressUI.section("Milestones"))
	if milestones.is_empty():
		var next: Dictionary = progress.next_milestone(character, Session.library, Session.collection, Session.unlocks)
		page.add_child(ProgressUI.label("Each level: %s." % str(next["text"]) if not next.is_empty() else "Every milestone earned.", "BodyLabel"))
	else:
		var flow: HFlowContainer = _tile_flow()
		var next_found: bool = false
		for m in milestones:
			var state: String = "reached"
			if not bool(m["reached"]):
				state = "later" if next_found else "next"
				next_found = true
			flow.add_child(_milestone_tile(m, state))
		page.add_child(flow)

	var rows: Array[Dictionary] = _rows_in(character)
	if not rows.is_empty():
		_add_achievements(rows)

	var decks: Array[String] = _decks_of(character)
	if not decks.is_empty():
		var open: int = decks.filter(func(id: String) -> bool: return Session.unlocks.is_open(id)).size()
		page.add_child(ProgressUI.section("Decks", "%d of %d open" % [open, decks.size()]))
		var list: VBoxContainer = ProgressUI.vbox(ZenithTheme.GAP_S)
		for id in decks:
			var deck: DeckList = DeckList.resolve(id)
			list.add_child(ProgressUI.deck_row(AdventureProgress.deck_name(id), deck.style if deck != null else "",
				Session.unlocks.is_open(id), _routes(id)))
		page.add_child(list)


func _xp_how(main: bool) -> String:
	if main:
		return "Earns XP for every duel won as this character, more for bosses and a finished run."
	return "Earns XP while in play beside you in a won duel, and when you beat them."


func _tile_flow() -> HFlowContainer:
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", ZenithTheme.GAP_S)
	flow.add_theme_constant_override("v_separation", ZenithTheme.GAP_S)
	return flow


func _milestone_tile(m: Dictionary, state: String) -> PanelContainer:
	var reward: Dictionary = m["reward"]
	var starter: String = str(reward.get("starter", ""))
	var plate: String = ""
	var plate_colour: Color = ZenithTheme.TEXT_SOFT
	if starter != "":
		var deck: DeckList = DeckList.resolve(starter)
		plate = "%s DECK" % (deck.style.to_upper() if deck != null else "")
		plate_colour = Palette.school_ui(deck.style if deck != null else "")
	elif not (reward.get("abilities", []) as Array).is_empty():
		plate = "RUN START"
	return ProgressUI.milestone_tile("LV %d" % int(m["level"]),
		AdventureProgress.reward_text(reward, Session.library, null, Session.unlocks),
		AdventureProgress.reward_card(reward, Session.library), plate, plate_colour, state, Session.library)


func _add_achievements(rows: Array[Dictionary]) -> void:
	page.add_child(ProgressUI.section("Achievements", "%d of %d" % [_done_count(rows), rows.size()]))
	var list: VBoxContainer = ProgressUI.vbox(ZenithTheme.GAP_S)
	for row in rows:
		list.add_child(ProgressUI.achievement_row(row))
	page.add_child(list)


## A quest group: its reward's art in the header, and for an achievement whose steps each name a
## main, one portrait per step, lit once that step is done.
func _show_quest(group: String) -> void:
	var rows: Array[Dictionary] = _rows_in(group)
	var picture: Control = null
	for row in rows:
		var art: Control = _reward_picture(str(row["id"]))
		if art != null:
			picture = art
			break
	_page_header(group, Color(0, 0, 0, 0), "Quest", {}, picture)
	for row in rows:
		var steps: Control = _step_portraits(str(row["id"]))
		if steps != null:
			page.add_child(steps)
	_add_achievements(rows)


func _reward_picture(achievement_id: String) -> Control:
	for a in AdventureAchievements.all():
		if str(a.get("id", "")) != achievement_id:
			continue
		for id in a.get("cards", []):
			if Session.library.has(str(id)):
				var texture: Texture2D = CardFace.art_texture(Session.library.get_def(str(id)))
				if texture != null:
					var rect: TextureRect = TextureRect.new()
					rect.custom_minimum_size = Vector2(PORTRAIT_PAGE, PORTRAIT_PAGE)
					rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
					rect.clip_contents = true
					rect.texture = texture
					return rect
	return null


func _step_portraits(achievement_id: String) -> Control:
	for a in AdventureAchievements.all():
		if str(a.get("id", "")) != achievement_id:
			continue
		var steps: Array = a.get("steps", [])
		if steps.is_empty():
			return null
		for step in steps:
			if not (step as Dictionary).has("main"):
				return null
		var done: Array[int] = Session.unlocks.steps_done(achievement_id)
		var row: HBoxContainer = ProgressUI.hbox(ZenithTheme.GAP_L)
		for s in range(steps.size()):
			var who: String = str((steps[s] as Dictionary)["main"])
			var cell: VBoxContainer = ProgressUI.vbox(ZenithTheme.GAP_XS)
			cell.add_child(ProgressUI.portrait(who, Session.library, PORTRAIT_STEP, not done.has(s)))
			cell.add_child(ProgressUI.line(AdventureAchievements.short_name(who), "CaptionLabel",
				ZenithTheme.TEXT if done.has(s) else ZenithTheme.MUTED, false))
			cell.add_child(ProgressUI.chip("DONE" if done.has(s) else "TO DO", ZenithTheme.ACCENT if done.has(s) else ZenithTheme.MUTED, done.has(s)))
			row.add_child(cell)
		return row
	return null


func _show_school(school: String) -> void:
	var progress: AdventureProgress = Session.progress
	_page_header(school.capitalize(), Palette.school_ui(school), "School", progress.school_standing(school), null)
	page.add_child(ProgressUI.label("Earns XP for every run whose Mastery is %s. Each level adds cards of the school to your collection." % school.capitalize(), "CaptionLabel"))
	var library: Vector2i = AdventureProgress.school_library(school, Session.library, Session.collection)
	page.add_child(ProgressUI.section("Library", "%d of %d cards" % [library.x, library.y]))
	page.add_child(ProgressUI.label("Next level: %s." % progress.school_next_text(school, Session.library), "BodyLabel"))
	var masteries: Array = AdventureProgress.data().get("mastery_levels", [])
	if masteries.is_empty():
		return
	page.add_child(ProgressUI.section("Masteries"))
	var flow: HFlowContainer = _tile_flow()
	var now: int = progress.school_level(school)
	var next_found: bool = false
	for level in masteries:
		var id: String = AdventureProgress.school_mastery(school, int(level), Session.library)
		if id == "":
			continue
		var state: String = "reached"
		if int(level) > now:
			state = "later" if next_found else "next"
			next_found = true
		flow.add_child(ProgressUI.milestone_tile("LV %d" % int(level), AdventureProgress.card_name(Session.library.get_def(id)),
			id, "MASTERY", Palette.school_ui(school), state, Session.library))
	page.add_child(flow)


# --- Next up ------------------------------------------------------------------

## The closest locked deck first, then each main's next milestone, then the achievement chain
## furthest along. At most NEXT_UP_MAX.
func _fill_next_up() -> void:
	var tiles: Array[Button] = []
	var deck: Dictionary = _nearest_deck()
	if not deck.is_empty():
		tiles.append(_next_milestone_tile(str(deck["character"]), int(deck["level"]), str(deck["text"])))
	var achievement: Button = _next_achievement_tile()
	var room: int = NEXT_UP_MAX - (1 if achievement != null else 0)
	for entry in _entries:
		if tiles.size() >= room or str(entry["kind"]) != "character" or not bool(entry["main"]):
			continue
		var character: String = str(entry["key"])
		if not deck.is_empty() and str(deck["character"]) == character:
			continue
		var next: Dictionary = _next_of(character)
		if not next.is_empty():
			tiles.append(_next_milestone_tile(character, int(next["level"]), str(next["text"])))
	if achievement != null:
		tiles.append(achievement)
	next_up.visible = not tiles.is_empty()
	for tile in tiles:
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next_tiles.add_child(tile)
	for i in range(tiles.size(), NEXT_UP_MAX):
		var filler: Control = Control.new()
		filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next_tiles.add_child(filler)


## A character's next level with a reward, in short: {level, text}, or {}.
func _next_of(character: String) -> Dictionary:
	var progress: AdventureProgress = Session.progress
	for m in progress.milestones(character):
		if not bool(m["reached"]):
			return {"level": int(m["level"]), "text": AdventureProgress.reward_short(m["reward"], Session.library)}
	var next: Dictionary = progress.next_milestone(character, Session.library, Session.collection, Session.unlocks)
	return {} if next.is_empty() else {"level": int(next["level"]), "text": str(next["text"])}


## The unopened deck an authored track opens with the least XP still to earn: {character, level, text}.
func _nearest_deck() -> Dictionary:
	var best: Dictionary = {}
	var best_to_go: int = 0
	for character in (AdventureProgress.data().get("tracks", {}) as Dictionary).keys():
		for m in Session.progress.milestones(str(character)):
			var starter: String = str((m["reward"] as Dictionary).get("starter", ""))
			if starter == "" or bool(m["reached"]) or Session.unlocks.is_open(starter):
				continue
			var to_go: int = Session.progress.personality_xp_to(str(character), int(m["level"]))
			if best.is_empty() or to_go < best_to_go:
				best_to_go = to_go
				best = {"character": str(character), "level": int(m["level"]),
					"text": AdventureProgress.reward_short(m["reward"], Session.library)}
	return best


func _entry_of(key: String) -> int:
	for i in range(_entries.size()):
		if str(_entries[i]["key"]) == key and str(_entries[i]["kind"]) != "school":
			return i
	return -1


func _next_milestone_tile(character: String, level: int, reward_line: String) -> Button:
	var progress: AdventureProgress = Session.progress
	var to_go: int = progress.personality_xp_to(character, level)
	var tile: Button = _next_tile(character, character, reward_line, "Lv %d  ·  %d XP to go" % [level, to_go], ZenithTheme.XP, _entry_of(character))
	var bar: ProgressBar = ProgressUI.xp_bar(6)
	var d: Dictionary = AdventureProgress.data()
	var curve: Array = d.get("personality_levels", [0])
	var step: int = int(d.get("past_end_step", 0))
	var standing: Dictionary = progress.personality_standing(character)
	bar.min_value = float(standing["from"])
	bar.max_value = float(maxi(AdventureProgress.threshold_of(level, curve, step), int(standing["from"]) + 1))
	bar.value = float(standing["xp"])
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(tile.get_meta("text") as VBoxContainer).add_child(bar)
	return tile


func _next_achievement_tile() -> Button:
	var best: Dictionary = {}
	for row in _rows:
		if str(row["state"]) != "progress":
			continue
		if best.is_empty() or float(row["done"]) / float(row["total"]) > float(best["done"]) / float(best["total"]):
			best = row
	if best.is_empty():
		return null
	var group: String = str(best["group"])
	var who: String = str(best["character"]) if group == str(best["character"]) else ""
	return _next_tile(who, "Achievement: %s" % str(best["title"]), str(best["reward"]),
		"%d of %d steps" % [int(best["done"]), int(best["total"])], ZenithTheme.TEXT_SOFT, _entry_of(group))


func _next_tile(character: String, heading: String, reward_line: String, sub: String, sub_colour: Color, entry_index: int) -> Button:
	var row: HBoxContainer = ProgressUI.hbox(ZenithTheme.GAP_S)
	if character != "":
		row.add_child(ProgressUI.portrait(character, Session.library, PORTRAIT_NEXT))
	var text: VBoxContainer = ProgressUI.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_child(ProgressUI.line(heading.to_upper(), "CaptionLabel"))
	text.add_child(ProgressUI.line(reward_line, "BodyLabel", ZenithTheme.TEXT))
	text.add_child(ProgressUI.line(sub, "CaptionLabel", sub_colour))
	row.add_child(text)
	var tile: Button = ProgressUI.tile_button(row, NEXT_TILE_HEIGHT, false)
	tile.set_meta("text", text)
	tile.tooltip_text = reward_line
	if entry_index >= 0:
		tile.pressed.connect(func() -> void:
			_tiles[entry_index].grab_focus()
			_select(entry_index))
	return tile
