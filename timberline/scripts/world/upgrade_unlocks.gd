extends Node
## Turns purchased upgrades into world changes. Lives in main.tscn;
## station scenes spawn here so the catalog stays pure data/UI.

@export var splitting_block_scene: PackedScene
@export var splitting_block_spot: Vector3 = Vector3(2.2, 0.0, 1.6)

var _spawned_block: bool = false


func _ready() -> void:
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	# Upgrades restored from a save fire no signal; spawn what's owned.
	if GameManager.has_upgrade("splitting_block"):
		_spawn_block.call_deferred()


func _on_upgrade_purchased(upgrade_id: String) -> void:
	if upgrade_id == "splitting_block":
		_spawn_block()
		Fx.dust_puff(self, splitting_block_spot + Vector3.UP * 0.3, 0.8)


func _spawn_block() -> void:
	if _spawned_block:
		return
	_spawned_block = true
	var block: Node3D = splitting_block_scene.instantiate()
	get_parent().add_child(block)
	block.global_position = splitting_block_spot
