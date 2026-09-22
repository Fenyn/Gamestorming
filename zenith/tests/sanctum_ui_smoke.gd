extends SceneTree
## Scouting, run results, and decorative scene isolation. Builds an unsaved run only.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var session: Node = root.get_node("Session")
	session.run = AdventureRun.begin("root_seals_start", 12345)
	session.ladder = AdventureLadder.load_for("root_seals_start", 12345)
	session.run.stage = 3
	var stage: Control = load("res://scenes/adventure/stage.tscn").instantiate()
	# Headless rendering never emits frame_post_draw. Cache fixture textures so the
	# real sheet can render immediately without leaving pending card-face coroutines.
	var cache: CardFaceCache = stage.get_node("CardFaceCache")
	var placeholder: ImageTexture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	for value: Variant in session.library.defs.values():
		var def: CardDef = value
		if def.is_personality():
			for aspect: Dictionary in def.aspects:
				cache._cache[CardFaceCache.key_for(def, int(aspect.get("aspect", 1)))] = placeholder
		else:
			cache._cache[CardFaceCache.key_for(def)] = placeholder
	root.add_child(stage)
	await create_timer(0.5).timeout
	var route: Variant = stage.ladder_list.get_child(0)
	_check(route._buttons.size() == session.ladder.size(), "The route must show exactly the real ladder's rounds")
	_check(not stage.duel_button.disabled and stage.duel_button.visible, "The current round must be ready to enter")
	route._buttons[6].pressed.emit()
	_check(stage.duel_button.disabled, "Scouting a future round must disable entering that round")
	_check(session.run.stage == 3, "Scouting must not advance or change the run")
	_check(stage.next_sheet.tag.text.contains("SCOUTING"), "Scouted rounds must be explicitly labeled")
	route._buttons[3].pressed.emit()
	_check(not stage.duel_button.disabled, "Returning to the current round must restore the duel action")
	_check(stage.next_sheet.tag.text == "NEXT CHALLENGER", "Current opponent must regain the next-challenger label")
	for button: Button in route._buttons:
		_check(Rect2(Vector2.ZERO, route.size).encloses(Rect2(button.position, button.size)), "Every round must fit inside the route")
	for status: String in ["won", "lost"]:
		session.run.status = status
		stage._refresh()
		await process_frame
		_check(stage.run_over_panel.visible and not stage.next_sheet.visible, "Completed runs must show a result instead of the next opponent")
		_check(not stage.duel_button.visible and stage.new_run_button.visible, "Run results must offer a new run, not another stage")
	stage.queue_free()
	await process_frame
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var hall: SanctumSet = SanctumSet.new()
	hall.menu_mode = false
	world.add_child(hall)
	_check(hall.find_children("*", "Camera3D", true, false).is_empty(), "Combat architecture must never install another camera")
	_check(hall.find_children("*", "WorldEnvironment", true, false).is_empty(), "Combat architecture must preserve the duel's environment")
	ArcaneBackdrop.reduced_motion = true
	var before: float = hall._clock
	hall._process(0.5)
	_check(hall._clock == before and not hall._dust.visible, "Reduced motion must freeze the portal and hide hall dust")
	_check(not hall._portal.visible, "Reduced motion must hide the pack's TIME-driven portal")
	for flame: Node3D in hall._flames:
		_check(not flame.visible and not flame.get_node("Flame").emitting, "Reduced motion must stop brazier particles")
	ArcaneBackdrop.reduced_motion = false
	world.queue_free()
	await process_frame
	print("Sanctum UI smoke: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
