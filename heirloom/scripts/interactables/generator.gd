extends StaticBody3D

const FUEL_PER_HOUR := 0.042
const FUEL_PER_JERRYCAN := 0.5
const MAX_FUEL := 1.0

var fuel: float = 0.0
var running: bool = false


func _ready() -> void:
	EventBus.hour_changed.connect(_on_hour_changed)


func get_interact_hint(player: Node3D) -> String:
	if not GameState.is_upgrade_complete("generator"):
		return ""

	var held: Node3D = player.get_held_item() as Node3D
	if held and held.get("item_id") == "jerrycan":
		return "[E] Fill generator (%.0f%% fuel)" % (fuel * 100.0)

	if running:
		return "[E] Stop generator (%.0f%% fuel)" % (fuel * 100.0)

	if fuel > 0.0:
		return "[E] Start generator (%.0f%% fuel)" % (fuel * 100.0)

	return "[E] Generator (no fuel — need jerry can)"


func interact(player: Node3D) -> void:
	if not GameState.is_upgrade_complete("generator"):
		return

	var held: Node3D = player.get_held_item() as Node3D
	if held and held.get("item_id") == "jerrycan":
		_refuel(player)
		return

	if running:
		_stop()
	elif fuel > 0.0:
		_start()


func _refuel(player: Node3D) -> void:
	fuel = clampf(fuel + FUEL_PER_JERRYCAN, 0.0, MAX_FUEL)
	var can: Node3D = player.get_held_item()
	player.drop_held_item()
	can.queue_free()


func _start() -> void:
	running = true


func _stop() -> void:
	running = false


func _on_hour_changed(_hour: int) -> void:
	if not running:
		return
	fuel -= FUEL_PER_HOUR
	if fuel <= 0.0:
		fuel = 0.0
		running = false
