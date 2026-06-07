extends StaticBody3D

@export var lie_down_duration: float = 1.0

var _sleeping := false


func get_interact_hint(_player: Node3D) -> String:
	return "[E] Sleep"


func interact(player: Node3D) -> void:
	if _sleeping:
		return
	_sleeping = true
	_do_sleep(player)


func _do_sleep(player: Node3D) -> void:
	TimeManager.paused = true

	# Lie down animation — tilt camera and lower it
	var camera: Camera3D = player.get_node("Camera3D") as Camera3D
	if camera:
		var tween: Tween = create_tween()
		var target_pos := Vector3(camera.position.x, 0.6, camera.position.z)
		var target_rot := Vector3(-1.4, camera.rotation.y, 0.1)
		tween.set_parallel(true)
		tween.tween_property(camera, "position", target_pos, lie_down_duration)
		tween.tween_property(camera, "rotation", target_rot, lie_down_duration)
		await tween.finished

	var fade: Node = get_tree().get_first_node_in_group("screen_fade")
	if fade and fade.has_method("fade_to_black"):
		await fade.fade_to_black(0.8)

	var restore: float = GameState.get_sleep_restore()
	GameState.fatigue = restore
	GameState.hunger = maxf(GameState.hunger - 0.1, 0.0)
	GameState.thirst = maxf(GameState.thirst - 0.1, 0.0)

	TimeManager.advance_to_morning()
	SaveManager.save_game()

	# Reset camera
	if camera:
		camera.position = Vector3(0, 1.7, 0)
		camera.rotation = Vector3(0, 0, 0)

	if fade and fade.has_method("show_day_text"):
		fade.show_day_text("Day %d" % GameState.day)
	if fade and fade.has_method("fade_from_black"):
		await fade.fade_from_black(0.8)

	TimeManager.paused = false
	_sleeping = false
