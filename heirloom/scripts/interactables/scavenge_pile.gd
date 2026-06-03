extends StaticBody3D

@export var material_id: String = "wood_plank"
@export var material_name: String = "Wood Plank"
@export var yield_amount: int = 1
@export var uses: int = 3
@export var respawn_days: int = 0

var _uses_remaining: int = 0
var _depleted := false


func _ready() -> void:
	_uses_remaining = uses


func interact(_player: Node3D) -> void:
	if _depleted:
		return

	GameState.add_material(material_id, yield_amount)
	_uses_remaining -= 1

	if _uses_remaining <= 0:
		_depleted = true
		_hide()


func _hide() -> void:
	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
