extends StaticBody3D

const THIRST_RESTORE := 0.5
const PUMP_TIME := 2.0

var _pumping := false
var _pump_progress: float = 0.0
var _pump_player: Node3D = null
var _pump_for_can := false


func get_interact_hint(player: Node3D) -> String:
	if not GameState.well_repaired:
		return "[E] Broken Well"
	if _pumping:
		return "Pumping... (hold E)"
	var held: Node3D = player.get_held_item() as Node3D
	if held and held.has_method("is_filled"):
		var status: String = held.get_status() as String
		return "[Hold E] Fill watering can (%s)" % status
	return "[Hold E] Pump water"


func interact(player: Node3D) -> void:
	if not GameState.well_repaired:
		return
	if _pumping:
		return

	_pumping = true
	_pump_progress = 0.0
	_pump_player = player

	var held: Node3D = player.get_held_item() as Node3D
	_pump_for_can = held != null and held.has_method("fill")


func _process(delta: float) -> void:
	if not _pumping:
		return

	if not Input.is_action_pressed("interact"):
		_cancel_pump()
		return

	_pump_progress += delta
	if _pump_progress >= PUMP_TIME:
		_finish_pump()


func _finish_pump() -> void:
	if _pump_for_can and _pump_player and is_instance_valid(_pump_player):
		var held: Node3D = _pump_player.get_held_item() as Node3D
		if held and held.has_method("fill"):
			held.fill()
	else:
		GameState.thirst = clampf(GameState.thirst + THIRST_RESTORE, 0.0, 1.0)
		EventBus.need_changed.emit("thirst", GameState.thirst)

	_cancel_pump()


func _cancel_pump() -> void:
	_pumping = false
	_pump_progress = 0.0
	_pump_player = null
	_pump_for_can = false
