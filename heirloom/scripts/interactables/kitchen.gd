extends StaticBody3D

const RAW_RESTORE := 0.3
const COOKED_RESTORE := 0.45


func interact(_player: Node3D) -> void:
	var restore: float = COOKED_RESTORE if GameState.stove_fixed else RAW_RESTORE

	var has_food: bool = GameState.inventory.get("food", 0) as int > 0
	if has_food:
		var count: int = GameState.inventory.get("food", 0) as int
		GameState.inventory["food"] = count - 1
		GameState.hunger = clampf(GameState.hunger + restore, 0.0, 1.0)
		EventBus.need_changed.emit("hunger", GameState.hunger)
