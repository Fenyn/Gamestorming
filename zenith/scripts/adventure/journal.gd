extends Control
## The achievement journal and every character's and school's XP. Read-only.

const TWO_COLUMN_WIDTH: float = 900.0

@onready var achievements_list: VBoxContainer = $Margin/Column/Body/AchievementsPanel/Inner/Achievements/Scroll/Pad/List
@onready var progress_list: VBoxContainer = $Margin/Column/Body/ProgressPanel/Inner/Progress/Scroll/Pad/List
@onready var achieved_tile: StatTile = $Margin/Column/TitleRow/Achieved
@onready var back_button: Button = $Margin/Column/Footer/Back

var _grids: Array[GridContainer] = []


func _ready() -> void:
	theme = SanctumUI.theme()
	SanctumUI.dress(self, $Margin/Column/TitleRow/Title as Label)
	back_button.pressed.connect(func() -> void: Session.leave_journal())
	if AdventureDev.flag("--dev-scratch=") != "":
		AdventureDev.use_scratch_saves()
	if AdventureDev.has_flag("--dev-sample"):
		AdventureDev.sample_meta()
	_fill_achievements()
	_fill_progress()
	achievements_list.resized.connect(_fit_columns)
	_fit_columns()
	SanctumUI.wire_buttons(self)
	AdventureDev.screenshot(self)


func _fill_achievements() -> void:
	var rows: Array[Dictionary] = AdventureAchievements.journal(Session.unlocks, Session.library)
	var groups: Array[String] = []
	for row in rows:
		if not groups.has(str(row["group"])):
			groups.append(str(row["group"]))
	var completed: int = 0
	for group in groups:
		var in_group: Array[Dictionary] = []
		for row in rows:
			if str(row["group"]) == group:
				in_group.append(row)
		var done: int = in_group.filter(func(r: Dictionary) -> bool: return str(r["state"]) == "complete").size()
		completed += done
		var section: VBoxContainer = VBoxContainer.new()
		section.add_theme_constant_override("separation", 12)
		var character: String = group if _is_character(group) else ""
		section.add_child(ProgressUI.group_header(group, "%d of %d" % [done, in_group.size()], character, Session.library))
		var grid: GridContainer = GridContainer.new()
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		for row in in_group:
			var entry: PanelContainer = ProgressUI.achievement_card(row)
			entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(entry)
		section.add_child(grid)
		_grids.append(grid)
		achievements_list.add_child(section)
	achieved_tile.set_stat("Achievements", "%d of %d" % [completed, rows.size()], "", ZenithTheme.TEXT)


func _fill_progress() -> void:
	var progress: AdventureProgress = Session.progress
	var mains: Array[String] = []
	var schools: Array[String] = []
	for id in Session.unlocks.available_starters():
		var family: String = AdventureDecks.family_of(id)
		var character: String = AdventureDecks.character_of(family)
		if not mains.has(character):
			mains.append(character)
		var deck: DeckList = DeckList.resolve(id)
		if deck != null and not schools.has(deck.style):
			schools.append(deck.style)
	var others: Array[String] = []
	for key in progress.personality_xp.keys():
		if not mains.has(str(key)):
			others.append(str(key))
	others.sort()
	for key in progress.school_xp.keys():
		if not schools.has(str(key)):
			schools.append(str(key))
	if progress.personality_xp.is_empty() and progress.school_xp.is_empty():
		progress_list.add_child(ProgressUI.label("Win duels to earn XP for your character, the people who fight beside you, and your deck's school.", "BodyLabel"))
	_add_section("Your characters", mains, false)
	if not others.is_empty():
		_add_section("Allies and rivals", others, false)
	_add_section("Schools", schools, true)


func _add_section(title: String, keys: Array[String], school: bool) -> void:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.add_child(ProgressUI.group_header(title, "", "", Session.library))
	var progress: AdventureProgress = Session.progress
	for i in range(keys.size()):
		var key: String = keys[i]
		var standing: Dictionary = progress.school_standing(key) if school else progress.personality_standing(key)
		var next_text: String = ""
		var identity: Color = Color(0, 0, 0, 0)
		if school:
			next_text = "Level %d  ·  %s" % [progress.school_level(key) + 1, progress.school_next_text(key, Session.library)]
			identity = Palette.school_ui(key)
		else:
			var next: Dictionary = progress.next_milestone(key, Session.library, Session.collection, Session.unlocks)
			if next.is_empty():
				next_text = "All milestones earned"
			elif str(next["text"]) != "":
				next_text = "Level %d  ·  %s" % [int(next["level"]), str(next["text"])]
		section.add_child(ProgressUI.xp_row(key.capitalize() if school else key, standing, next_text, identity, i % 2 == 0))
	progress_list.add_child(section)


func _is_character(name: String) -> bool:
	for id in Session.library.all_ids():
		var def: CardDef = Session.library.defs[id]
		if def.is_personality() and def.character == name:
			return true
	return false


func _fit_columns() -> void:
	var columns: int = 2 if achievements_list.size.x >= TWO_COLUMN_WIDTH else 1
	for grid in _grids:
		grid.columns = columns
