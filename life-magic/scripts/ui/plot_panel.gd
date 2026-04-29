extends ScrollContainer

@onready var row_container: VBoxContainer = %RowContainer

var _plot_card_scene: PackedScene
var _cards: Dictionary = {}


func _ready() -> void:
	_plot_card_scene = preload("res://scenes/ui/plot_card.tscn")
	EventBus.plot_unlocked.connect(_on_plot_unlocked)
	_build_cards()


func _build_cards() -> void:
	for data in PlotManager.plot_data:
		var state: Dictionary = GameState.plots.get(data.id, {})
		if state.get("unlocked", false):
			_add_card(data)


func _on_plot_unlocked(plot_id: String) -> void:
	var data := PlotManager.get_plot_data(plot_id)
	if data and not _cards.has(plot_id):
		_add_card(data)


func _add_card(data: PlotData) -> void:
	var card := _plot_card_scene.instantiate()
	card.setup(data)
	row_container.add_child(card)
	_cards[data.id] = card
