extends Control
## The achievement journal: every achievement the player may know about, grouped by character, and
## the XP standing of each character and school. Reads Session only; nothing here changes a save.

@onready var achievements_list: VBoxContainer = $Margin/Column/Body/Achievements/Scroll/List
@onready var progress_list: VBoxContainer = $Margin/Column/Body/Progress/Scroll/List
@onready var back_button: Button = $Margin/Column/Footer/Back


func _ready() -> void:
	theme = SanctumUI.theme()
	SanctumUI.dress(self, $Margin/Column/TitleRow/Title as Label)
	back_button.pressed.connect(func() -> void: Session.go_to_adventure())
	_fill_achievements()
	_fill_progress()
	SanctumUI.wire_buttons(self)
	AdventureDev.screenshot(self)


func _fill_achievements() -> void:
	var last_character: String = ""
	for row in AdventureAchievements.journal(Session.unlocks):
		var character: String = str(row["character"])
		if character != last_character:
			last_character = character
			_add_label(achievements_list, character.to_upper(), ZenithTheme.MUTED, 13)
		var state: String = str(row["state"])
		var mark: String = "Done" if state == "complete" else "%d/%d" % [int(row["done"]), int(row["total"])]
		var colour: Color = ZenithTheme.ACCENT if state == "complete" else ZenithTheme.TEXT
		if state == "unknown":
			colour = ZenithTheme.MUTED
		_add_label(achievements_list, "%s    %s" % [str(row["title"]), mark], colour, 17)
		if str(row["hint"]) != "":
			_add_label(achievements_list, str(row["hint"]), ZenithTheme.MUTED, 14)


func _fill_progress() -> void:
	var progress: AdventureProgress = Session.progress
	var characters: Array = progress.personality_xp.keys()
	characters.sort()
	_add_label(progress_list, "CHARACTERS", ZenithTheme.MUTED, 13)
	if characters.is_empty():
		_add_label(progress_list, "No XP yet.", ZenithTheme.MUTED, 15)
	for character in characters:
		_add_label(progress_list, "%s    level %d, %d XP" % [str(character),
			progress.personality_level(str(character)), int(progress.personality_xp[character])],
			ZenithTheme.TEXT, 16)
	var schools: Array = progress.school_xp.keys()
	schools.sort()
	_add_label(progress_list, "SCHOOLS", ZenithTheme.MUTED, 13)
	if schools.is_empty():
		_add_label(progress_list, "No XP yet.", ZenithTheme.MUTED, 15)
	for school in schools:
		_add_label(progress_list, "%s    level %d, %d XP" % [str(school).capitalize(),
			progress.school_level(str(school)), int(progress.school_xp[school])], ZenithTheme.TEXT, 16)


func _add_label(parent: VBoxContainer, text: String, colour: Color, size: int) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
