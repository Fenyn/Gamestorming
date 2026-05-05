extends Node

const SECONDS_PER_DAY: float = 100.0
const LOOP_DURATION: float = 300.0

var gold: float = 0.0
var total_gold_this_loop: float = 0.0
var tickets: int = 0
var loop_count: int = 0
var loop_time_remaining: float = LOOP_DURATION
var current_day: int = 1
var loop_active: bool = false

var starting_gold_bonus: float = 0.0
var unlocked_train_types: Array[String] = ["handcar"]
var unlocked_builder_types: Array[String] = ["track_layer"]

var owned_trains: Dictionary = {}
var owned_builders: Dictionary = {}


func _process(delta: float) -> void:
	if not loop_active:
		return
	loop_time_remaining -= delta
	var new_day: int = 3 - int(loop_time_remaining / SECONDS_PER_DAY)
	new_day = clampi(new_day, 1, 3)
	if new_day != current_day:
		current_day = new_day
		EventBus.day_changed.emit(current_day)
	if loop_time_remaining <= 0.0:
		loop_time_remaining = 0.0
		loop_active = false
		EventBus.loop_ending.emit()


func start_loop() -> void:
	gold = starting_gold_bonus
	total_gold_this_loop = 0.0
	loop_time_remaining = LOOP_DURATION
	current_day = 1
	loop_active = true
	loop_count += 1
	owned_trains.clear()
	owned_builders.clear()
	EventBus.gold_changed.emit(gold)


func add_gold(amount: float) -> void:
	gold += amount
	total_gold_this_loop += amount
	EventBus.gold_changed.emit(gold)


func spend_gold(amount: float) -> bool:
	if gold < amount:
		EventBus.purchase_failed.emit("Not enough Gold")
		return false
	gold -= amount
	EventBus.gold_changed.emit(gold)
	return true


func add_tickets(amount: int) -> void:
	tickets += amount
	EventBus.tickets_changed.emit(tickets)


func spend_tickets(amount: int) -> bool:
	if tickets < amount:
		return false
	tickets -= amount
	EventBus.tickets_changed.emit(tickets)
	return true


func get_owned_count(type_id: String) -> int:
	if owned_trains.has(type_id):
		return owned_trains[type_id] as int
	if owned_builders.has(type_id):
		return owned_builders[type_id] as int
	return 0
