extends StaticBody3D

var _label: Label3D = null

func _ready() -> void:
	add_to_group("station")

	_label = StationUtils.create_status_label(self, Vector3(0, 0.25, 0.12))
	_label.text = "HAND OFF\n[Click] Place finished drink"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func receive_item(item: Node3D) -> bool:
	if not item is Cup:
		return false
	var cup := item as Cup
	if not cup.is_complete():
		if _label:
			_label.text = "Drink not finished!\nComplete all steps first"
		return false
	if not cup.order:
		return false
	if cup.order.handed_off:
		return false
	cup.order.handed_off = true

	var stars := cup.order.get_star_rating()
	var tip := 0.0
	if stars >= GameManager.TIP_STAR_THRESHOLD:
		tip = cup.order.base_price * GameManager.TIP_RATE

	if stars >= 4.0:
		SoundManager.play("review_good")
	else:
		SoundManager.play("review_bad")
	if tip > 0.0:
		SoundManager.play("tip_earned")

	EventBus.drink_handed_off.emit({
		"order": cup.order,
		"ticket_code": cup.order.ticket_code,
		"stars": stars,
		"tip": tip,
	})

	item.global_position = global_position + Vector3(0, 0.15, 0)
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true

	if _label:
		_label.text = _format_review(stars, tip)
		_label.modulate = _star_color(stars)

	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_callback(item.queue_free)
	tween.tween_callback(_reset_label)

	return true

func _format_review(stars: float, tip: float) -> String:
	var star_str := _star_text(stars)
	if tip > 0.0:
		return "%s\n+$%.2f tip!" % [star_str, tip]
	return star_str

func _star_text(stars: float) -> String:
	var full := int(stars)
	var has_half := (stars - full) >= 0.4
	var text := ""
	var filled := full + (1 if has_half else 0)
	for i in range(full):
		text += "*"
	if has_half:
		text += "."
	for i in range(5 - filled):
		text += "-"
	return "%s  %.1f / 5" % [text, stars]

func _star_color(stars: float) -> Color:
	if stars >= 5.0: return Color(1.0, 0.85, 0.0)
	if stars >= 4.0: return Color(0.3, 0.9, 0.3)
	if stars >= 3.0: return Color(1.0, 1.0, 1.0)
	if stars >= 2.0: return Color(1.0, 0.6, 0.2)
	return Color(1.0, 0.2, 0.2)

func _reset_label() -> void:
	if _label:
		_label.text = "HAND OFF\n[Click] Place finished drink"
		_label.modulate = Color.WHITE

func interact(_player: Player) -> void:
	pass
