class_name StationTerminal
extends PanelContainer

var _selected_entry: StoryEntryData = null

@onready var _entry_list: VBoxContainer = %EntryList
@onready var _content_title: Label = %ContentTitle
@onready var _content_date: Label = %ContentDate
@onready var _content_body: RichTextLabel = %ContentBody
@onready var _category_label: Label = %CategoryLabel


func _ready() -> void:
	visible = false


func on_opened() -> void:
	_refresh_entries()
	_clear_content()
	EventBus.terminal_opened.emit()


func on_closed() -> void:
	EventBus.terminal_closed.emit()


func _refresh_entries() -> void:
	_clear_list(_entry_list)
	var entries: Array[StoryEntryData] = _get_unlocked_entries()
	entries.sort_custom(func(a: StoryEntryData, b: StoryEntryData) -> bool: return a.sort_order < b.sort_order)

	for entry: StoryEntryData in entries:
		var btn: Button = Button.new()
		btn.text = "[%s] %s" % [_category_short(entry.category), entry.title]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_entry_selected.bind(entry))
		_entry_list.add_child(btn)

	if entries.is_empty():
		var label: Label = Label.new()
		label.text = "No entries available"
		label.modulate = Color(0.5, 0.5, 0.5, 1)
		_entry_list.add_child(label)


func _on_entry_selected(entry: StoryEntryData) -> void:
	_selected_entry = entry
	_content_title.text = entry.title
	_content_date.text = entry.date_string
	_category_label.text = StoryEntryData.EntryCategory.keys()[entry.category]
	_content_body.text = entry.content


func _clear_content() -> void:
	_content_title.text = "Select an entry"
	_content_date.text = ""
	_category_label.text = ""
	_content_body.text = ""


func _get_unlocked_entries() -> Array[StoryEntryData]:
	var result: Array[StoryEntryData] = []
	for entry: Resource in Database.get_all_story_entries():
		var e: StoryEntryData = entry as StoryEntryData
		if e.unlock_condition == "default" or GameState.unlocked_story_entries.has(e.entry_id):
			result.append(e)
	return result


func _category_short(cat: StoryEntryData.EntryCategory) -> String:
	match cat:
		StoryEntryData.EntryCategory.MANUAL: return "MAN"
		StoryEntryData.EntryCategory.LOG: return "LOG"
		StoryEntryData.EntryCategory.MESSAGE: return "MSG"
		StoryEntryData.EntryCategory.SYSTEM_REPORT: return "SYS"
		StoryEntryData.EntryCategory.CLASSIFIED: return "CLS"
	return "???"


func _clear_list(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()
