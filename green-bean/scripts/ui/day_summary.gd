extends Control

## End-of-day card: grade, average review, the day's numbers, the bank after
## it, and the key to start the next day. Reads GameManager and UnlockManager
## once when shown.

@onready var _card: PanelContainer = %Card
@onready var _grade: Label = %Grade
@onready var _stars: HBoxContainer = %Stars
@onready var _numbers: GridContainer = %Numbers
@onready var _bank: Label = %Bank
@onready var _next: HBoxContainer = %Next

func _ready() -> void:
	var grade := GameManager.get_grade()
	_grade.text = grade
	if grade == "S":
		_grade.add_theme_color_override("font_color", UiStyle.AMBER)

	var avg := GameManager.get_average_stars()
	for i in range(5):
		var kind := UiIcon.Kind.STAR_EMPTY
		if avg >= float(i) + 1.0:
			kind = UiIcon.Kind.STAR_FULL
		elif avg >= float(i) + 0.5:
			kind = UiIcon.Kind.STAR_HALF
		_stars.add_child(UiIcon.make(kind, UiStyle.AMBER, 34))
	var avg_l := Label.new()
	avg_l.text = "  %.1f" % avg if GameManager.drinks_reviewed > 0 else ""
	avg_l.theme_type_variation = UiStyle.HUD_VALUE
	_stars.add_child(avg_l)

	_row("Served", str(GameManager.customers_served))
	if GameManager.customers_lost > 0:
		_row("Walked out", str(GameManager.customers_lost), UiStyle.RED)
	_row("Sales", "$%.2f" % (GameManager.total_earned - GameManager.total_tips))
	if GameManager.total_tips > 0.0:
		_row("Tips", "$%.2f" % GameManager.total_tips)
	if GameManager.total_spent > 0.0:
		_row("Supplies", "-$%.2f" % GameManager.total_spent)
	var profit := GameManager.get_profit()
	_row("Profit", "$%.2f" % profit, UiStyle.SAGE if profit >= 0.0 else UiStyle.RED, true)

	_bank.text = "Bank $%.2f      %d stars" % [UnlockManager.money, UnlockManager.stars]
	_next.add_child(KeyHint.make("Enter", "Next day", UiStyle.HUD_VALUE))

	# The one bit of motion: the card settles in.
	_card.pivot_offset = _card.size * 0.5
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "modulate:a", 1.0, 0.25)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _row(name: String, value: String, color: Color = UiStyle.CREMA, strong := false) -> void:
	var n := Label.new()
	n.text = name
	n.theme_type_variation = UiStyle.HUD_FLOAT if strong else UiStyle.HUD_MUTED
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := Label.new()
	v.text = value
	v.theme_type_variation = UiStyle.HUD_VALUE if strong else UiStyle.HUD_FLOAT
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_color_override("font_color", color)
	_numbers.add_child(n)
	_numbers.add_child(v)
