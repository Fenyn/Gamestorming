## Dev spike: instances main.tscn, waits for tree generation, saves
## screenshots to user://dev_shots, prints their absolute paths, quits.
## Run rendered (not --headless):
##   godot --path timberline res://scenes/dev/dev_shot.tscn

extends Node3D

const SHOT_DIR := "user://dev_shots"


func _ready() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	add_child(main_scene.instantiate())
	_capture()


func _capture() -> void:
	await _wait_frames(15)
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_save_shot("trees_main.png")

	# Close-up of the cabin with the forest behind it.
	var cam := get_viewport().get_camera_3d()
	cam.global_position = Vector3(7.0, 3.0, 4.0)
	cam.look_at(Vector3(0.0, 2.0, -4.0))
	await _wait_frames(5)
	_save_shot("cabin_close.png")

	# High front view of the cabin roof and gable.
	cam.global_position = Vector3(6.0, 9.0, 5.0)
	cam.look_at(Vector3(0.0, 3.0, -4.0))
	await _wait_frames(5)
	_save_shot("cabin_high.png")

	# High overview of the clearing, pond, path, road, and sell bin.
	cam.global_position = Vector3(34.0, 26.0, -18.0)
	cam.look_at(Vector3(-4.0, 0.0, 18.0))
	await _wait_frames(5)
	_save_shot("overworld.png")

	get_tree().quit()


func _save_shot(file_name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path := SHOT_DIR + "/" + file_name
	img.save_png(path)
	print("shot: ", ProjectSettings.globalize_path(path))


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
