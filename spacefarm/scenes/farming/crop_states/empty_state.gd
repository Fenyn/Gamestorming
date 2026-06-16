class_name CropEmptyState
extends BaseState


func enter(_msg: Dictionary = {}) -> void:
	var tile: CropTile = owner as CropTile
	tile.clear_crop()


func interact(_player: Node2D) -> void:
	if GameState.is_active_tool("trowel"):
		if not GameState.spend_energy(CropTile.ENERGY_TILL):
			return
		state_machine.transition_to(&"Tilled")
	elif GameState.get_active_item_id() != "":
		EventBus.notification_requested.emit("Till the soil first (select trowel)")
