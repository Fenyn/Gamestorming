extends Node

const DAY_LENGTH := 600.0
const TIP_RATE := 0.20
const TIP_STAR_THRESHOLD := 5.0

const GRADE_THRESHOLDS := {
	"S": 4.5,
	"A": 4.0,
	"B": 3.0,
	"C": 2.0,
	"D": 1.0,
}

var day_timer := 0.0
var day_active := false
var prep_active := false
var _warned_timer := false
var total_earned := 0.0
var total_tips := 0.0
var total_spent := 0.0
var total_stars := 0.0
var drinks_reviewed := 0
var customers_served := 0
var customers_lost := 0

func _ready() -> void:
	EventBus.drink_handed_off.connect(_on_drink_handed_off)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.order_submitted.connect(_on_order_submitted)

func start_prep() -> void:
	prep_active = true
	day_active = false
	day_timer = 0.0
	total_earned = 0.0
	total_tips = 0.0
	total_spent = 0.0
	total_stars = 0.0
	drinks_reviewed = 0
	customers_served = 0
	customers_lost = 0
	_warned_timer = false
	EventBus.prep_started.emit()

func start_day() -> void:
	prep_active = false
	day_timer = DAY_LENGTH
	day_active = true
	_warned_timer = false
	SoundManager.play("day_start")
	EventBus.day_started.emit()

func _process(delta: float) -> void:
	if not day_active:
		return
	day_timer -= delta
	if day_timer <= 30.0 and not _warned_timer:
		_warned_timer = true
		SoundManager.play("timer_warning")
	if day_timer <= 0.0:
		day_timer = 0.0
		day_active = false
		SoundManager.stop_all_loops()
		SoundManager.play("day_end")
		EventBus.day_ended.emit()

func get_time_remaining() -> float:
	return day_timer

func add_expense(amount: float) -> void:
	total_spent += amount

func get_profit() -> float:
	return total_earned - total_spent

func get_average_stars() -> float:
	if drinks_reviewed <= 0:
		return 0.0
	return total_stars / float(drinks_reviewed)

func get_grade() -> String:
	var avg := get_average_stars()
	for grade in ["S", "A", "B", "C", "D"]:
		if avg >= GRADE_THRESHOLDS[grade]:
			return grade
	return "F"

func _on_order_submitted(data: Dictionary) -> void:
	var order: OrderData = data["order"]
	total_earned += order.base_price

func _on_drink_handed_off(data: Dictionary) -> void:
	customers_served += 1
	var stars: float = data.get("stars", 0.0)
	total_stars += stars
	drinks_reviewed += 1
	var tip: float = data.get("tip", 0.0)
	if tip > 0.0:
		total_tips += tip
		total_earned += tip

func _on_customer_left(_customer: Node3D, reason: String) -> void:
	if reason != "satisfied":
		customers_lost += 1
