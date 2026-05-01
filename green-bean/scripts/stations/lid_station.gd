extends StaticBody3D

var _status_label: Label3D = null

func _ready() -> void:
	add_to_group("station")
	_status_label = StationUtils.create_status_label(self)
	_update_label(null)

func interact(player: Player) -> void:
	var held := player.get_held_item()
	if not held is Cup:
		_update_label(null)
		return
	var cup := held as Cup
	if cup.has_lid:
		if _status_label:
			_status_label.text = "Already has a lid"
		return
	cup.has_lid = true
	SoundManager.play("lid_snap")
	if _status_label:
		_status_label.text = "Lid added!"
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(func(): _update_label(null))

func _update_label(_held: Node3D) -> void:
	if _status_label:
		_status_label.text = "LID DISPENSER\n[E] Hold cup to lid"
