class_name ArenaPrewarm
extends Node
## Compiles the duel's shaders under the Compatibility renderer (the web build), which compiles a
## shader on its first draw and holds the page while it does. The duel's own pieces are drawn one at
## a time into a hidden SubViewport by the duel's loading screen through `finish`, which counts them.
## The menus only render the card back, the one step that held the page under 50 ms on a first visit
## in headless Chrome; building the hidden arena alone took 0.9 s and every draw that compiles took
## 0.1 to 3.4 s. To re-measure, run a debug web export with `--dev-warm-log` on a fresh profile: every
## step prints its time. The pieces stay alive afterwards: they keep the compiled shaders, which the
## duel's materials share, from being freed. Session owns one per page load.

const DUEL_SCENE: String = "res://scenes/duel/duel.tscn"
const CARD_SCENE: String = "res://scenes/duel/card_3d.tscn"
const FACE_CACHE_SCENE: String = "res://scenes/duel/card_face_cache.tscn"
## The duel scene's nodes that draw or light the arena, in the order they are lit up.
const PIECES: Array[String] = ["WorldEnvironment", "Sun", "TableKey", "Table", "PhaseTrack", "NearDuelist",
	"FarDuelist", "ArenaVeil", "Fx", "Atmosphere"]
const START_DELAY: float = 1.0      # lets the first screen draw before the card back renders
const FX_DRAWS: int = 4             # each effect part is drawn this often, since particles draw a few frames in
const VIEW_SIZE: Vector2i = Vector2i(480, 270)

signal finished
signal menu_done
signal _step_ended

var done: bool = false
var menu_finished: bool = false
var _halted: bool = false
var _foreground: bool = false
var _busy: bool = false
var _log: bool = false
var _steps: Array[Dictionary] = []
var _next: int = 0
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _world: Node3D = null
var _home: Transform3D = Transform3D.IDENTITY
var _pieces: Array[GeometryInstance3D] = []
var _lights: Array[Light3D] = []
var _effect: Node3D = null
var _faces: CardFaceCache = null
var _back: Texture2D = null
var _duel_scene: PackedScene = null


static func wanted() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility" \
		and DisplayServer.get_name() != "headless"


## An online or replay duel opened: the menus stop drawing here, so the two do not compete.
func stop() -> void:
	_halted = true


## Runs every step left, one draw a frame, for the duel's loading screen. `progress` gets the
## step's number among those left and their count, before a frame is drawn with it, so the line
## moves before each stall.
func finish(progress: Callable) -> void:
	_foreground = true
	while _busy:
		await _step_ended
	remaining()
	var first: int = _next
	var count: int = _steps.size() - first
	while _next < _steps.size():
		progress.call(_next - first, count)
		await RenderingServer.frame_post_draw
		await _run_step()
	_complete()


## The steps `finish` will run, once the arena is built.
func remaining() -> int:
	if _steps.is_empty():
		var from: int = Time.get_ticks_msec()
		_build()
		_plan()
		if _log:
			print("prewarm %-34s %5d ms" % ["build", Time.get_ticks_msec() - from])
	return _steps.size() - _next


func _ready() -> void:
	_log = AdventureDev.has_flag("--dev-warm-log")
	_run_menus()


func _run_menus() -> void:
	await get_tree().create_timer(START_DELAY).timeout
	if _foreground or _halted or not _steps.is_empty():
		return
	_busy = true
	var from: int = Time.get_ticks_msec()
	await _card_back()
	if _log:
		print("prewarm %-34s %5d ms  (menus)" % ["card back", Time.get_ticks_msec() - from])
	_busy = false
	_step_ended.emit()
	menu_finished = true
	menu_done.emit()


func _complete() -> void:
	if done:
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	done = true
	menu_finished = true
	menu_done.emit()
	finished.emit()
	if _log:
		print("prewarm done")


## The table unlit, each light and then its shadow, each mesh with the camera aimed at it, three
## whole views, each top-level part of each pack effect on its own, a card back, two faces and a
## table card. The card back is there only when the menus did not render it.
func _plan() -> void:
	if _back == null:
		_add("card back", _card_back, 0)
	_add("unlit table", _unlit_table)
	for light in _lights:
		_add(str(light.name), _light_on.bind(light))
		if light.shadow_enabled:
			_add(str(light.name) + " shadow", _shadow_on.bind(light))
		light.shadow_enabled = false
	for piece in _pieces.slice(1):
		_add(str(piece.get_path()).get_slice("Arena/", 1), _piece_on.bind(piece))
	for i in range(3):
		_add(["view home", "view far", "view lead-in"][i], _view.bind(i))
	for effect in DuelFx.PREWARM_EFFECTS:
		var probe: Node3D = EffectBlocks.make(effect)
		for child in probe.get_children():
			if child is Node3D:
				_add(effect + "/" + str(child.name), _effect_part.bind(effect, str(child.name)), FX_DRAWS)
		probe.free()
	_add("card face 1", _card_face.bind(0), 0)
	_add("card face 2", _card_face.bind(1), 0)
	_add("table card", _table_card)


func _add(step_name: String, run: Callable, draws: int = 1) -> void:
	_steps.append({"name": step_name, "run": run, "draws": draws})


## Runs the next step, then draws the hidden arena as often as it asks.
func _run_step() -> void:
	_busy = true
	var step: Dictionary = _steps[_next]
	_next += 1
	var from: int = Time.get_ticks_msec()
	var run: Callable = step["run"]
	await run.call()
	for i in range(int(step["draws"])):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	if _log:
		print("prewarm %-34s %5d ms%s" % [str(step["name"]), Time.get_ticks_msec() - from, "" if _foreground else "  (menus)"])
	_busy = false
	_step_ended.emit()


## Moves the duel scene's arena pieces into an own-world SubViewport. The duel scene's root and
## the rest of it never enter the tree, so the duel's script does not run. The packed scene stays
## loaded, so opening the duel does not read it again.
func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = VIEW_SIZE
	_viewport.positional_shadow_atlas_size = get_tree().root.positional_shadow_atlas_size
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_world = Node3D.new()
	_world.name = "Arena"
	_viewport.add_child(_world)
	_duel_scene = load(DUEL_SCENE) as PackedScene
	var duel: Node = _duel_scene.instantiate()
	var lens: Camera3D = duel.get_node("CameraRig/Camera")
	_home = Transform3D(Basis.looking_at(TableCamera.LOOK_AT - lens.position), lens.position)
	_camera = Camera3D.new()
	_camera.fov = lens.fov
	_camera.near = lens.near
	_camera.far = lens.far
	_world.add_child(_camera)
	_camera.make_current()
	for piece_name in PIECES:
		var piece: Node = duel.get_node(piece_name)
		duel.remove_child(piece)
		_disown(piece, duel)
		_world.add_child(piece)
	duel.free()
	_collect(_world)
	for piece in _pieces:
		piece.visible = false
	for light in _lights:
		light.visible = false


## The first lit piece compiles a variant per kind of light, so the lights come on one at a time.
func _unlit_table() -> void:
	_pieces[0].visible = true
	_camera.transform = _home


func _light_on(light: Light3D) -> void:
	light.visible = true


func _shadow_on(light: Light3D) -> void:
	light.shadow_enabled = true


func _piece_on(piece: GeometryInstance3D) -> void:
	piece.visible = true
	var box: AABB = piece.global_transform * piece.get_aabb()
	var reach: float = maxf(box.size.length() * 1.2, 1.5)
	var centre: Vector3 = box.get_center()
	_camera.look_at_from_position(centre + Vector3(0.0, 0.6, 1.0).normalized() * reach, centre)


func _view(which: int) -> void:
	var veil: Node3D = _world.get_node("ArenaVeil")
	veil.visible = false
	var views: Array[Transform3D] = [
		_home,
		Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * _home,
		Transform3D(Basis.looking_at(TableCamera.INTRO_LOOK - TableCamera.INTRO_FROM), TableCamera.INTRO_FROM),
	]
	_camera.transform = views[which]


## One top-level part of a pack effect with the others hidden, so the power-up's particles and its
## ring, or the impact's particles and its light, compile in draws of their own. The copy is made
## without the play tweens, so the light keeps its energy until its draw.
func _effect_part(effect: String, part: String) -> void:
	_camera.transform = _home
	if _effect == null or str(_effect.get_meta("effect", "")) != effect:
		if _effect != null:
			_effect.free()
		_effect = EffectBlocks.make(effect)
		_effect.set_meta("effect", effect)
		_effect.position = Vector3.UP * 0.06
		_effect.scale *= 0.001
		EffectBlocks.tint(_effect, Color.WHITE)
		_world.get_node("Fx").add_child(_effect)
	for child in _effect.get_children():
		if child is Node3D:
			(child as Node3D).visible = child.name == part
			if child is GPUParticles3D and child.name == part:
				(child as GPUParticles3D).restart()


func _card_back() -> void:
	_faces = (load(FACE_CACHE_SCENE) as PackedScene).instantiate()
	add_child(_faces)
	_back = await _faces.render_back()


func _card_face(which: int) -> void:
	if _effect != null:
		_effect.free()
		_effect = null
	var session: Node = get_parent()
	var decks: Array[DeckList] = session.get("decks")
	var library: CardLibrary = session.get("library") as CardLibrary
	if decks.is_empty() or library == null:
		return
	var deck: DeckList = decks[0]
	var id: String = ""
	if which == 0 and not deck.duelist_ids.is_empty():
		id = deck.duelist_ids[0]
	elif which == 1 and not deck.cards.is_empty():
		id = deck.cards[0]
	var def: CardDef = library.defs.get(id)
	await _faces.render_def(def)


func _table_card() -> void:
	var card: Card3D = (load(CARD_SCENE) as PackedScene).instantiate()
	_world.add_child(card)
	card.position = Vector3(0.0, 0.05, 0.6)
	card.set_textures(_back, _back)


func _collect(node: Node) -> void:
	if node is GeometryInstance3D and ((node as GeometryInstance3D).visible or node.name == "ArenaVeil"):
		_pieces.append(node as GeometryInstance3D)
	elif node is Light3D and (node as Light3D).visible:
		_lights.append(node as Light3D)
	for child in node.get_children():
		_collect(child)


func _disown(node: Node, owner_node: Node) -> void:
	if node.owner == owner_node:
		node.owner = null
	for child in node.get_children():
		_disown(child, owner_node)
