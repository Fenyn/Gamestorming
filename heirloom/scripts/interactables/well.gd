extends StaticBody3D

const THIRST_RESTORE := 0.5


func interact(_player: Node3D) -> void:
	if not GameState.well_repaired:
		return
	GameState.thirst = clampf(GameState.thirst + THIRST_RESTORE, 0.0, 1.0)
	EventBus.need_changed.emit("thirst", GameState.thirst)
