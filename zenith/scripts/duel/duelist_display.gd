class_name DuelistDisplay
extends Node3D
## Persistent, camera-facing resource fixture anchored in the playspace.
## Accepts only the public seat view and the same event snapshots used by the table.

@export var reduced_motion: bool = false
@onready var surface: Sprite3D = $Surface
@onready var viewport: SubViewport = $ReadoutViewport
@onready var readout: DuelistReadout = $ReadoutViewport/Readout


func _ready() -> void:
	surface.texture = viewport.get_texture()


func refresh(view: SeatView, player_index: int, viewer: int, live: Dictionary = {}) -> void:
	if not is_node_ready() or player_index >= view.players.size():
		return
	readout.reduced_motion = reduced_motion
	readout.refresh(view, player_index, viewer, live)


## Preview only: outlined Energy segments distinguish projected spending from resolution.
func preview_energy(cost: int = 0) -> void:
	readout.preview_cost = maxi(0, cost)
	readout.queue_redraw()
