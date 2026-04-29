extends ScrollContainer

@onready var row_container: VBoxContainer = %RowContainer

var _upgrade_row_scene: PackedScene
var _rows: Dictionary = {}


func _ready() -> void:
	_upgrade_row_scene = preload("res://scenes/ui/upgrade_row.tscn")
	EventBus.tick_fired.connect(func(_t): _refresh())
	_refresh()


func _refresh() -> void:
	for data in UpgradeManager.upgrade_data:
		if not UpgradeManager.is_unlocked(data.id):
			continue
		if UpgradeManager.is_maxed(data.id):
			if _rows.has(data.id):
				_rows[data.id].queue_free()
				_rows.erase(data.id)
			continue
		if not _rows.has(data.id):
			_add_row(data)


func _add_row(data: UpgradeData) -> void:
	var row := _upgrade_row_scene.instantiate()
	row.setup(data)
	row_container.add_child(row)
	_rows[data.id] = row
