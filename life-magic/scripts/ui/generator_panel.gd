extends ScrollContainer

@onready var row_container: VBoxContainer = %RowContainer

var _generator_row_scene: PackedScene
var _rows: Dictionary = {}


func _ready() -> void:
	_generator_row_scene = preload("res://scenes/ui/generator_row.tscn")
	EventBus.generator_unlocked.connect(_on_generator_unlocked)

	_build_rows()


func _build_rows() -> void:
	for data in GeneratorManager.tier_data:
		if GameState.is_tier_unlocked(data.tier):
			_add_row(data)


func _on_generator_unlocked(tier: int) -> void:
	var data := GeneratorManager.get_tier_data(tier)
	if data and not _rows.has(tier):
		_add_row(data)


func _add_row(data: GeneratorData) -> void:
	var row := _generator_row_scene.instantiate()
	row.setup(data)
	row_container.add_child(row)
	_rows[data.tier] = row

	var keys := _rows.keys()
	keys.sort()
	for i in keys.size():
		var tier_key: int = keys[i]
		row_container.move_child(_rows[tier_key], i)
