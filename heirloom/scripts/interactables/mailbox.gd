extends StaticBody3D

var _has_mail := false
var _mail_text: String = ""


func _ready() -> void:
	EventBus.bill_paid.connect(func(amount: float) -> void:
		_set_mail("Land payment of $%.0f received.\nBalance: $%.2f" % [amount, GameState.money]))
	EventBus.bill_missed.connect(func(consecutive: int) -> void:
		if consecutive < 2:
			_set_mail("WARNING: Payment missed!\nYou owe $%.0f.\nMiss one more and you lose everything." % Economy.MONTHLY_BILL))
	EventBus.day_started.connect(func(day: int) -> void:
		if day == 1:
			_set_mail("Rent is due this month: $%.0f" % Economy.MONTHLY_BILL))


func get_interact_hint(_player: Node3D) -> String:
	if _has_mail:
		return "[E] Check Mail"
	return ""


func interact(_player: Node3D) -> void:
	if not _has_mail:
		return

	var dialogue_ui: Node = get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui and dialogue_ui.has_method("show_dialogue"):
		dialogue_ui.show_dialogue("Mailbox", _mail_text)
	_has_mail = false


func _set_mail(text: String) -> void:
	_has_mail = true
	_mail_text = text
