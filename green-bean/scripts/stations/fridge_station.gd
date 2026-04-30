extends StaticBody3D

var _status_label: Label3D = null

func _ready() -> void:
	add_to_group("station")

	_status_label = Label3D.new()
	_status_label.text = "[E] Get milk\n(hold pitcher)"
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.3, 0.15)
	_status_label.pixel_size = 0.002
	_status_label.add_to_group("world_label")
	add_child(_status_label)

func interact(player: Player) -> void:
	var held := player.get_held_item()
	if held and held is Pitcher:
		var pitcher := held as Pitcher
		if pitcher.has_milk:
			if _status_label:
				_status_label.text = "Pitcher already has milk!"
			return
		pitcher.fill_milk()
		if _status_label:
			_status_label.text = "Milk added!\nTake to steam station"
	else:
		if _status_label:
			_status_label.text = "Hold a pitcher!\n[E] Get milk"
