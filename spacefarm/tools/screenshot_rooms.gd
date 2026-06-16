extends SceneTree
## Renders each station room to user://room_shots/<room>.png for visual review.
##
## Run:  godot --path . --script tools/screenshot_rooms.gd --resolution 1280x720

const ROOMS_DIR: String = "res://scenes/station/rooms/"
const OUT_DIR: String = "user://room_shots"
const ROOM_FILES: Array[String] = [
	"hub", "living_quarters", "grow_bay_room", "grow_bay_b", "grow_bay_c",
	"grow_bay_d", "cargo_bay", "service_tunnel", "processing_lab",
	"advanced_processing", "hybridization_lab",
]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for file: String in ROOM_FILES:
		var packed: PackedScene = load(ROOMS_DIR + file + ".tscn") as PackedScene
		var room: BaseRoom = packed.instantiate() as BaseRoom
		root.add_child(room)
		var cam: Camera2D = Camera2D.new()
		var view: Vector2 = root.get_visible_rect().size
		var fit: float = minf(view.x / (room.room_width + 240.0), view.y / (room.room_height + 240.0))
		cam.zoom = Vector2(fit, fit)
		root.add_child(cam)
		cam.make_current()
		for i: int in 3:
			await process_frame
		var img: Image = root.get_texture().get_image()
		img.save_png("%s/%s.png" % [OUT_DIR, file])
		room.free()
		cam.free()
		print("shot %s" % file)
	print("saved to %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit()
