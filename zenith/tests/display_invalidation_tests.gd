extends SceneTree
## Resource textures must wake for visual changes and remain idle on an unchanged table.

var checks: int = 0
var failures: int = 0
var requests: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 3, 4)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var card: Card3D = load("res://scenes/duel/card_3d.tscn").instantiate()
	world.add_child(card)
	# Load client scripts after autoloads exist, rather than compiling them with this SceneTree.
	var display: Node3D = load("res://scenes/duel/duelist_display.tscn").instantiate()
	world.add_child(display)
	display.surface.pixel_size = 0.001
	display.life_transform.origin = Vector3(0.8, 0, 0)
	display.readout.redraw_requested.connect(func() -> void: requests += 1)
	display.anchor_to_card(card, camera)
	_check(requests > 0, "Initial anchoring requests a resource texture")
	var initial: int = requests
	for i in range(100):
		display.anchor_to_card(card, camera)
	_check(requests == initial, "100 stationary frames request no additional texture redraws")
	display.readout.duelist_bounds = display.readout.duelist_bounds
	display.readout.card_bounds = display.readout.card_bounds
	_check(requests == initial, "Equal projected bounds do not invalidate layout")
	display.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	display.preview_energy(3)
	_check(requests == initial + 1, "Changed Energy preview requests one redraw")
	_check(display.viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "Preview wakes the viewport for one frame")
	display.preview_energy(3)
	_check(requests == initial + 1, "Unchanged preview does not redraw")
	display.preview_energy()
	_check(requests == initial + 2, "Leaving a preview removes its projected cost")
	var before_move: int = requests
	card.front.position.x += 0.1
	display.anchor_to_card(card, camera)
	_check(requests > before_move, "Animated card geometry invalidates anchoring")
	before_move = requests
	camera.position.z += 1.0
	display.anchor_to_card(card, camera)
	_check(requests > before_move, "Camera movement invalidates anchoring")
	before_move = requests
	camera.fov += 5.0
	display.anchor_to_card(card, camera)
	_check(requests > before_move, "Camera projection changes invalidate anchoring")
	before_move = requests
	display.life_transform.origin.x += 1.0
	display.anchor_to_card(card, camera)
	_check(requests > before_move, "Life pile movement updates the resource cluster")
	display.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	display.readout._set_flash(0.5)
	_check(display.viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "Flash animation wakes the resource viewport")
	world.queue_free()
	await process_frame
	print("display invalidation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
