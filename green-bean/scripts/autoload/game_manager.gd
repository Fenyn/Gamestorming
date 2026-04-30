extends Node

const DAY_LENGTH := 180.0
const GRADE_THRESHOLDS := {
	"S": 0.95,
	"A": 0.85,
	"B": 0.70,
	"C": 0.55,
	"D": 0.40,
}

var day_timer := 0.0
var day_active := false
var total_possible_earnings := 0.0
var total_earned := 0.0
var customers_served := 0
var customers_lost := 0

func _ready() -> void:
	EventBus.drink_handed_off.connect(_on_drink_handed_off)
	EventBus.customer_left.connect(_on_customer_left)

func start_day() -> void:
	day_timer = DAY_LENGTH
	day_active = true
	total_possible_earnings = 0.0
	total_earned = 0.0
	customers_served = 0
	customers_lost = 0
	EventBus.day_started.emit()

func _process(delta: float) -> void:
	if not day_active:
		return
	day_timer -= delta
	if day_timer <= 0.0:
		day_timer = 0.0
		day_active = false
		EventBus.day_ended.emit()

func get_time_remaining() -> float:
	return day_timer

func add_possible_earnings(amount: float) -> void:
	total_possible_earnings += amount

func add_earned(amount: float) -> void:
	total_earned += amount

func get_grade() -> String:
	if total_possible_earnings <= 0.0:
		return "F"
	var ratio := total_earned / total_possible_earnings
	for grade in ["S", "A", "B", "C", "D"]:
		if ratio >= GRADE_THRESHOLDS[grade]:
			return grade
	return "F"

func get_earned_ratio() -> float:
	if total_possible_earnings <= 0.0:
		return 0.0
	return total_earned / total_possible_earnings

func _on_drink_handed_off(_data: Dictionary, _earned: float) -> void:
	customers_served += 1

func _on_customer_left(_customer: Node3D, reason: String) -> void:
	if reason != "satisfied":
		customers_lost += 1
