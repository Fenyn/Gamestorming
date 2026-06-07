class_name StoryEntryData
extends Resource

enum EntryCategory { MANUAL, LOG, MESSAGE, SYSTEM_REPORT, CLASSIFIED }

@export_group("Identity")
@export var entry_id: String = ""
@export var title: String = ""
@export var category: EntryCategory = EntryCategory.LOG

@export_group("Content")
@export_multiline var content: String = ""
@export var date_string: String = ""
@export var sort_order: int = 0

@export_group("Unlock")
@export var unlock_condition: String = "default"
