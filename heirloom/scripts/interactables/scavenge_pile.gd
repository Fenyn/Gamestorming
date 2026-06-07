extends StaticBody3D

@export var material_id: String = "salvage_part"
@export var material_name: String = "Salvage Part"
@export var spawn_scene: PackedScene = null
@export var uses: int = 3

var _uses_remaining: int = 0
var _depleted := false


func _ready() -> void:
	_uses_remaining = uses


func get_interact_hint(player: Node3D) -> String:
	if _depleted:
		return ""
	if player.has_held_item():
		return ""
	return "[E] Scavenge %s (%d left)" % [material_name, _uses_remaining]


func interact(player: Node3D) -> void:
	if _depleted:
		return
	if player.has_held_item():
		return

	_uses_remaining -= 1

	if spawn_scene:
		var item: Node3D = spawn_scene.instantiate()
		get_parent().add_child(item)
		item.global_position = global_position + Vector3(0, 0.5, 0)
		player.pickup_item(item)
	else:
		GameState.add_material(material_id)

	if _uses_remaining <= 0:
		_depleted = true
		_hide()


func _hide() -> void:
	for child: Node in get_children():
		if child.name == "Model":
			(child as Node3D).visible = false
