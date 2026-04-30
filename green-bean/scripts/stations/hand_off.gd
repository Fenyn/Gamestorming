extends StaticBody3D

var _label: Label3D = null

func _ready() -> void:
	add_to_group("station")

	_label = Label3D.new()
	_label.text = "HAND OFF\n[Click] Place finished drink"
	_label.font_size = 12
	_label.position = Vector3(0, 0.25, 0.12)
	_label.pixel_size = 0.002
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)

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

	var earned := cup.order.get_earned_amount()
	GameManager.add_earned(earned)
	EventBus.drink_handed_off.emit(
		{"order": cup.order, "ticket_code": cup.order.ticket_code},
		earned
	)

	item.global_position = global_position + Vector3(0, 0.15, 0)
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true

	if _label:
		_label.text = "$%.2f earned!" % earned

	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(item.queue_free)
	tween.tween_callback(func(): _label.text = "HAND OFF\n[Click] Place finished drink")

	return true

func interact(_player: Player) -> void:
	pass
