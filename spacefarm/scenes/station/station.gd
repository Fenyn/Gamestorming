class_name Station
extends Node2D

const FADE_DURATION: float = 0.3
const DAY_TRANSITION_PAUSE: float = 1.0
const SEASON_TRANSITION_PAUSE: float = 2.0
const MILESTONE_DISPLAY_TIME: float = 3.0
const NOTIFICATION_DURATION: float = 2.0
const ROOM_TRANSITION_DELAY: float = 0.1
const SEASON_REPLENISH_MIN: int = 4
const FADE_CANVAS_LAYER: int = 100

const ROOM_DISPLAY_NAMES: Dictionary = {
	"hub": "The Commons",
	"living_quarters": "Crew Quarters",
	"cargo_bay": "Cargo Hold",
	"service_tunnel": "Maintenance Corridor",
	"grow_bay": "Grow Chamber Alpha",
	"grow_bay_b": "Grow Chamber Beta",
	"grow_bay_c": "Grow Chamber Gamma",
	"grow_bay_d": "Grow Chamber Delta",
	"processing_lab": "Workshop",
	"advanced_processing": "Research Lab",
	"hybridization_lab": "Bio-Lab",
}

## Doors opened when a module unlocks: module_id -> [[room_id, direction, target_room], ...]
const MODULE_DOORS: Dictionary = {
	"processing_lab": [["hub", "west", "processing_lab"]],
	"advanced_processing": [["processing_lab", "south", "advanced_processing"]],
	"hybridization_lab": [["processing_lab", "west", "hybridization_lab"]],
	"grow_ring_b": [["grow_bay", "east", "grow_bay_b"]],
	"grow_ring_c": [["grow_bay_b", "south", "grow_bay_c"]],
	"grow_ring_d": [["grow_bay_c", "west", "grow_bay_d"], ["grow_bay", "south", "grow_bay_d"]],
}

var _rooms: Dictionary = {}
var _current_room: BaseRoom = null
var _transitioning: bool = false
var _player: CharacterBody2D = null
var _canvas_modulate: CanvasModulate = null
var _deferred_moves: Dictionary = {}
var _crew_transit_paths: Dictionary = {}
var _slept_in_bed: bool = false

@onready var _interact_hint: Label = %InteractHint
@onready var _day_label: Label = %DayLabel
@onready var _seed_info: Label = %SeedInfo
@onready var _room_name: Label = %RoomName
@onready var _directive_name: Label = %DirectiveName
@onready var _directive_progress: Label = %DirectiveProgress
@onready var _terminal_panel: StationTerminal = $Overlays/TerminalPanel
@onready var _hybridizer_panel: HybridizerPanel = $Overlays/HybridizerPanel
@onready var _comms_panel: CommsPanel = $Overlays/CommsPanel
@onready var _inventory_panel: InventoryPanel = $Overlays/InventoryPanel
@onready var _pause_menu: PauseMenu = $Overlays/PauseMenu
@onready var _day_summary: DaySummaryPanel = $DaySummary
@onready var _dialogue_panel: DialoguePanel = $Overlays/DialoguePanel
@onready var _supply_board: SupplyBoard = $Overlays/SupplyBoard

var _active_overlay: Control = null


func _ready() -> void:
	_player = $Player
	_canvas_modulate = $CanvasModulate

	for child: Node in $Rooms.get_children():
		if child is BaseRoom:
			var room: BaseRoom = child as BaseRoom
			_rooms[room.room_id] = room

	_connect_all_exit_zones()
	_connect_cargo_pods()
	_connect_hybridizers()
	_connect_station_interactables()
	_spawn_crew()

	EventBus.interact_hint_changed.connect(_on_interact_hint_changed)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.season_ended.connect(_on_season_ended)
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.cargo_shipped.connect(_on_cargo_shipped)
	EventBus.module_unlocked.connect(_on_module_unlocked)
	EventBus.notification_requested.connect(_on_notification)

	_current_room = _rooms.get("living_quarters", null) as BaseRoom
	_apply_unlocked_modules()
	_update_day_label()
	_update_seed_info()
	_update_room_name()
	_update_directive_display()
	_update_lighting(TimeManager.current_hour)
	TimeManager.start_day()
	GameState.restore_crop_tiles()


func _process(_delta: float) -> void:
	if not _transitioning:
		_update_day_label()
		_process_deferred_moves()


# --- Overlay Management ---

func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return

	if event.is_action_pressed("pause"):
		if _active_overlay != null:
			_close_active_overlay()
		else:
			_open_overlay(_pause_menu)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("open_inventory"):
		if _active_overlay == _inventory_panel:
			_close_active_overlay()
		elif _active_overlay == null:
			_open_overlay(_inventory_panel)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") and _active_overlay != null:
		_close_active_overlay()
		get_viewport().set_input_as_handled()
		return


func _open_overlay(panel: Control) -> void:
	if _active_overlay != null:
		_close_active_overlay()
	_active_overlay = panel
	panel.visible = true
	if panel == _pause_menu:
		get_tree().paused = true
		InputManager.set_mode(InputContext.Mode.MENU)
	elif panel == _terminal_panel or panel == _comms_panel:
		InputManager.set_mode(InputContext.Mode.CUTSCENE)
	else:
		InputManager.set_mode(InputContext.Mode.MENU)

	if panel.has_method("on_opened"):
		panel.on_opened()


func _close_active_overlay() -> void:
	if _active_overlay == null:
		return
	if _active_overlay == _pause_menu:
		get_tree().paused = false
	if _active_overlay.has_method("on_closed"):
		_active_overlay.on_closed()
	_active_overlay.visible = false
	_active_overlay = null
	InputManager.set_mode(InputContext.Mode.GAMEPLAY)


# --- Room Transitions ---

func _connect_all_exit_zones() -> void:
	for room: BaseRoom in _rooms.values():
		for child: Node in room.get_children():
			if child is ExitZone:
				var zone: ExitZone = child as ExitZone
				zone.body_entered.connect(_on_exit_zone_entered.bind(zone))


func _on_exit_zone_entered(body: Node2D, zone: ExitZone) -> void:
	if body != _player:
		return
	if _transitioning:
		return
	if zone.target_room == "":
		return
	_transition_to_room(zone.target_room, zone.target_entrance)


func _transition_to_room(target_room_id: String, from_direction: String) -> void:
	var target: BaseRoom = _rooms.get(target_room_id, null) as BaseRoom
	if target == null:
		push_warning("Room not found: %s" % target_room_id)
		return

	_transitioning = true
	InputManager.set_mode(InputContext.Mode.DISABLED)
	_player.velocity = Vector2.ZERO

	var camera: Camera2D = _player.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false

	var fade: ColorRect = _get_or_create_fade()
	fade.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

	var opposite: String = _get_opposite_direction(from_direction)
	var entrance_pos: Vector2 = target.get_entrance_position(opposite)
	_player.global_position = entrance_pos
	_current_room = target
	_update_room_name()

	await get_tree().create_timer(ROOM_TRANSITION_DELAY).timeout

	camera.position_smoothing_enabled = true
	var tween2: Tween = create_tween()
	tween2.tween_property(fade, "modulate:a", 0.0, FADE_DURATION)
	await tween2.finished

	InputManager.set_mode(InputContext.Mode.GAMEPLAY)
	_transitioning = false


# --- Day/Night Cycle ---

func _update_lighting(hour: int) -> void:
	if _canvas_modulate == null:
		return

	var color: Color = Color.WHITE
	if hour <= 7:
		var t: float = float(hour - 6) / 2.0
		color = Color(0.6, 0.5, 0.4, 1).lerp(Color(0.85, 0.8, 0.7, 1), clampf(t, 0.0, 1.0))
	elif hour <= 9:
		var t: float = float(hour - 7) / 2.0
		color = Color(0.85, 0.8, 0.7, 1).lerp(Color(1.0, 1.0, 1.0, 1), clampf(t, 0.0, 1.0))
	elif hour <= 16:
		color = Color(1.0, 1.0, 1.0, 1)
	elif hour <= 18:
		var t: float = float(hour - 16) / 2.0
		color = Color(1.0, 1.0, 1.0, 1).lerp(Color(0.85, 0.7, 0.5, 1), clampf(t, 0.0, 1.0))
	elif hour <= 20:
		var t: float = float(hour - 18) / 2.0
		color = Color(0.85, 0.7, 0.5, 1).lerp(Color(0.4, 0.4, 0.6, 1), clampf(t, 0.0, 1.0))
	else:
		color = Color(0.35, 0.35, 0.55, 1)

	_canvas_modulate.color = color


# --- Day/Season Transitions ---

func _on_day_ended(day: int) -> void:
	if GameState.day > TimeManager.DAYS_PER_SEASON:
		return
	_do_day_transition(day)


func _do_day_transition(ended_day: int) -> void:
	_transitioning = true
	InputManager.set_mode(InputContext.Mode.DISABLED)
	_player.velocity = Vector2.ZERO

	var rested: bool = _slept_in_bed
	_slept_in_bed = false

	var fade: ColorRect = _get_or_create_fade()
	fade.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

	_day_label.text = "Day %d complete" % ended_day
	GameState.wake_up(rested)
	_day_summary.show_summary(ended_day, rested)
	await _day_summary.continue_requested

	_update_lighting(TimeManager.DAY_START_HOUR)
	TimeManager.start_day()
	GameState.save_game()
	EventBus.notification_requested.emit("Game saved.")
	_update_day_label()
	_update_seed_info()

	var tween2: Tween = create_tween()
	tween2.tween_property(fade, "modulate:a", 0.0, FADE_DURATION)
	await tween2.finished

	InputManager.set_mode(InputContext.Mode.GAMEPLAY)
	_transitioning = false


func _on_season_ended(season: int) -> void:
	_replenish_seeds()
	_do_season_transition(season)


func _replenish_seeds() -> void:
	for crop_id: String in GameState.unlocked_crops:
		var seed_id: String = crop_id + "_seed"
		var current: int = GameState.get_item_count(seed_id)
		if current < SEASON_REPLENISH_MIN:
			GameState.add_seeds(crop_id, SEASON_REPLENISH_MIN - current)


func _do_season_transition(season: int) -> void:
	_transitioning = true
	InputManager.set_mode(InputContext.Mode.DISABLED)
	_player.velocity = Vector2.ZERO

	var fade: ColorRect = _get_or_create_fade()
	fade.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

	_day_label.text = "Season %d complete" % season
	GameState.wake_up(_slept_in_bed)
	_slept_in_bed = false
	await get_tree().create_timer(SEASON_TRANSITION_PAUSE).timeout

	TimeManager.advance_to_next_season()
	GameState.save_game()
	_update_day_label()
	_update_seed_info()
	_update_lighting(TimeManager.DAY_START_HOUR)

	var tween2: Tween = create_tween()
	tween2.tween_property(fade, "modulate:a", 0.0, FADE_DURATION)
	await tween2.finished

	InputManager.set_mode(InputContext.Mode.GAMEPLAY)
	_transitioning = false


# --- Signal Handlers ---

func _on_interact_hint_changed(text: String) -> void:
	_interact_hint.text = text


func _on_hour_changed(hour: int) -> void:
	_update_day_label()
	_update_lighting(hour)
	_update_crew_positions(hour)


func _on_day_started(_day: int) -> void:
	_update_day_label()
	_update_seed_info()


func _on_crop_harvested(_pos: Vector2i, _crop_id: String, _quality: float) -> void:
	_update_seed_info()


func _on_notification(message: String) -> void:
	_interact_hint.text = message
	await get_tree().create_timer(NOTIFICATION_DURATION).timeout
	if _interact_hint.text == message:
		_interact_hint.text = ""


func _on_cargo_shipped(_items: Dictionary) -> void:
	_update_seed_info()
	_update_directive_display()
	_check_directive_completion()


func _on_module_unlocked(module_id: String) -> void:
	_apply_module_unlock(module_id)


## Re-opens airlocks for modules already unlocked in a loaded save.
func _apply_unlocked_modules() -> void:
	for module_id: String in GameState.unlocked_modules:
		_apply_module_unlock(module_id)


func _apply_module_unlock(module_id: String) -> void:
	if not MODULE_DOORS.has(module_id):
		return
	for door: Array in MODULE_DOORS[module_id]:
		var room: BaseRoom = _rooms.get(door[0], null) as BaseRoom
		if room == null:
			continue
		room.unlock_airlock(door[1], door[2])
		_reconnect_exit_zones_for_room(room)


func _reconnect_exit_zones_for_room(room: BaseRoom) -> void:
	for child: Node in room.get_children():
		if child is ExitZone:
			var zone: ExitZone = child as ExitZone
			if not zone.body_entered.is_connected(_on_exit_zone_entered):
				zone.body_entered.connect(_on_exit_zone_entered.bind(zone))


# --- Cargo Pod ---

func _connect_cargo_pods() -> void:
	for room: BaseRoom in _rooms.values():
		for child: Node in room.get_children():
			if child is CargoPod:
				var pod: CargoPod = child as CargoPod
				pod.pod_opened.connect(_on_pod_opened.bind(pod))


func _on_pod_opened(_pod: CargoPod) -> void:
	_open_overlay(_supply_board)


func _connect_hybridizers() -> void:
	for room: BaseRoom in _rooms.values():
		for child: Node in room.get_children():
			if child is Hybridizer:
				var hyb: Hybridizer = child as Hybridizer
				hyb.hybridizer_opened.connect(_on_hybridizer_opened.bind(hyb))


func _on_hybridizer_opened(hyb: Hybridizer) -> void:
	_hybridizer_panel.set_hybridizer(hyb)
	_open_overlay(_hybridizer_panel)


func _connect_station_interactables() -> void:
	for room: BaseRoom in _rooms.values():
		for child: Node in room.get_children():
			if child is StationInteractable:
				var obj: StationInteractable = child as StationInteractable
				obj.interacted.connect(_on_station_interactable.bind(obj.interactable_name))


func _on_station_interactable(interactable_name: String) -> void:
	match interactable_name:
		"TERMINAL":
			_open_overlay(_terminal_panel)
		"COMMS":
			_open_overlay(_comms_panel)
		"BED":
			_sleep()


# --- Directives ---

const DIRECTIVE_CHAIN: Array[String] = ["directive_1", "directive_2"]


func _update_directive_display() -> void:
	var directive: MilestoneData = Database.get_milestone(GameState.active_directive_id) as MilestoneData
	if directive == null:
		_directive_name.text = "ALL DIRECTIVES COMPLETE"
		_directive_progress.text = ""
		return
	_directive_name.text = "DIRECTIVE %d: %s" % [directive.directive_number, directive.display_name]
	if directive.required_food_units > 0:
		_directive_progress.text = "%d / %d food units shipped" % [
			GameState.food_shipped_total, directive.required_food_units
		]
	elif not directive.required_items.is_empty():
		var parts: Array[String] = []
		for item_id: String in directive.required_items:
			var needed: int = directive.required_items[item_id]
			var shipped: int = GameState.items_shipped.get(item_id, 0)
			parts.append("%s: %d/%d" % [item_id, shipped, needed])
		_directive_progress.text = ", ".join(parts)


func _check_directive_completion() -> void:
	var directive: MilestoneData = Database.get_milestone(GameState.active_directive_id) as MilestoneData
	if directive == null:
		return
	if not _is_directive_met(directive):
		return

	GameState.unlocked_milestones[directive.milestone_id] = true
	GameState.directives_completed += 1

	for crop_id: String in directive.unlocked_crops:
		if not GameState.unlocked_crops.has(crop_id):
			GameState.unlocked_crops.append(crop_id)
			GameState.add_seeds(crop_id, 4)

	for module_id: String in directive.unlocked_modules:
		if not GameState.unlocked_modules.has(module_id):
			GameState.unlocked_modules.append(module_id)
			EventBus.module_unlocked.emit(module_id)

	for entry_id: String in directive.unlocked_story_entries:
		if not GameState.unlocked_story_entries.has(entry_id):
			GameState.unlocked_story_entries.append(entry_id)
			EventBus.story_entry_unlocked.emit(entry_id)

	EventBus.milestone_unlocked.emit(directive.milestone_id)
	_advance_to_next_directive()
	_show_milestone_popup(directive)


func _is_directive_met(directive: MilestoneData) -> bool:
	if directive.required_food_units > 0:
		if GameState.food_shipped_total < directive.required_food_units:
			return false
	if not directive.required_items.is_empty():
		for item_id: String in directive.required_items:
			var needed: int = directive.required_items[item_id]
			var shipped: int = GameState.items_shipped.get(item_id, 0)
			if shipped < needed:
				return false
	return true


func _advance_to_next_directive() -> void:
	var current_index: int = DIRECTIVE_CHAIN.find(GameState.active_directive_id)
	if current_index >= 0 and current_index + 1 < DIRECTIVE_CHAIN.size():
		GameState.active_directive_id = DIRECTIVE_CHAIN[current_index + 1]
		GameState.food_shipped_total = 0
		GameState.items_shipped.clear()
	else:
		GameState.active_directive_id = ""


func _show_milestone_popup(directive: MilestoneData) -> void:
	_transitioning = true
	InputManager.set_mode(InputContext.Mode.DISABLED)

	var fade: ColorRect = _get_or_create_fade()
	fade.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.8, FADE_DURATION)
	await tween.finished

	_day_label.text = "DIRECTIVE COMPLETE: %s" % directive.display_name
	_seed_info.text = directive.lore_hint
	await get_tree().create_timer(MILESTONE_DISPLAY_TIME).timeout

	_update_day_label()
	_update_seed_info()
	_update_directive_display()

	var tween2: Tween = create_tween()
	tween2.tween_property(fade, "modulate:a", 0.0, FADE_DURATION)
	await tween2.finished

	InputManager.set_mode(InputContext.Mode.GAMEPLAY)
	_transitioning = false


# --- HUD Updates ---

func _update_day_label() -> void:
	_day_label.text = "%s Day %d | %s | %s" % [
		TimeManager.get_day_name(), GameState.day,
		TimeManager.get_season_name(), TimeManager.get_time_string()
	]


func _update_seed_info() -> void:
	var parts: Array[String] = []
	var all_seeds: Dictionary = GameState.get_all_seeds()
	for seed_id: String in all_seeds:
		var crop_id: String = seed_id.substr(0, seed_id.length() - 5)
		var crop: CropData = Database.get_crop(crop_id)
		var crop_name: String = crop.get_active_name() if crop else crop_id
		parts.append("%s:%d" % [crop_name, all_seeds[seed_id]])
	var harvested: Dictionary = GameState.get_all_harvested()
	var h_parts: Array[String] = []
	for crop_id: String in harvested:
		h_parts.append("%s:%d" % [crop_id, harvested[crop_id]])
	var text: String = "Seeds: %s" % " | ".join(parts) if parts.size() > 0 else "Seeds: none"
	if h_parts.size() > 0:
		text += "  Crops: %s" % " | ".join(h_parts)
	_seed_info.text = text


func _update_room_name() -> void:
	if _current_room:
		_room_name.text = ROOM_DISPLAY_NAMES.get(_current_room.room_id, _current_room.room_id.to_upper().replace("_", " "))


# --- Crew ---

const CREW_SCENE: PackedScene = preload("res://scenes/crew/crew_member.tscn")

func _spawn_crew() -> void:
	for contact: ContactData in Database.get_all_contacts():
		var room: BaseRoom = _rooms.get(contact.location_claim, null) as BaseRoom
		if room == null:
			continue
		if not _is_room_unlocked(room.room_id):
			continue
		var member: CrewMember = CREW_SCENE.instantiate() as CrewMember
		member.position = _get_safe_position(room)
		room.add_child(member)
		member.setup(contact)
		member.crew_interacted.connect(_on_crew_interacted)


func _get_safe_position(room: BaseRoom) -> Vector2:
	var inset: float = float(BaseRoom.TILE_SIZE) * 2.0
	var hw: float = room.room_width / 2.0 - inset
	var hh: float = room.room_height / 2.0 - inset
	return Vector2(randf_range(-hw, hw), randf_range(-hh, hh))


func _update_crew_positions(hour: int) -> void:
	for member: Node in get_tree().get_nodes_in_group("crew_members"):
		if not member is CrewMember:
			continue
		var crew: CrewMember = member as CrewMember
		var target_room_id: String = CrewManager.get_scheduled_room(crew.crew_id, hour)
		if target_room_id == "":
			continue
		if crew.get_parent() is BaseRoom and (crew.get_parent() as BaseRoom).room_id == target_room_id:
			_deferred_moves.erase(crew.crew_id)
			continue
		if crew.is_busy():
			_deferred_moves[crew.crew_id] = target_room_id
			continue
		_execute_crew_move(crew, target_room_id)


func _process_deferred_moves() -> void:
	if _deferred_moves.is_empty():
		return
	var to_execute: Array[Array] = []
	for crew_id: String in _deferred_moves:
		var target_room_id: String = _deferred_moves[crew_id]
		for member: Node in get_tree().get_nodes_in_group("crew_members"):
			if not member is CrewMember:
				continue
			var crew: CrewMember = member as CrewMember
			if crew.crew_id != crew_id:
				continue
			if crew.get_state_name() == &"Transit":
				break
			if crew.get_state_name() == &"Talking":
				break
			to_execute.append([crew, target_room_id])
			break
	for entry: Array in to_execute:
		_execute_crew_move(entry[0] as CrewMember, entry[1] as String)


func _execute_crew_move(crew: CrewMember, target_room_id: String) -> void:
	if not _is_room_unlocked(target_room_id):
		return
	if crew.get_state_name() == &"Transit":
		_crew_transit_paths.erase(crew.crew_id)
		crew.transition_state(&"Idle")
	var current_room: BaseRoom = crew.get_parent() as BaseRoom
	if current_room == null:
		return
	var path: Array[String] = _find_room_path(current_room.room_id, target_room_id)
	if path.is_empty():
		var target_room: BaseRoom = _rooms.get(target_room_id, null) as BaseRoom
		if target_room:
			_instant_crew_move(crew, target_room)
		return
	_crew_transit_paths[crew.crew_id] = path
	var transit_node: CrewTransitState = crew.get_node("StateMachine/Transit") as CrewTransitState
	if transit_node == null:
		var target_room: BaseRoom = _rooms.get(target_room_id, null) as BaseRoom
		if target_room:
			_instant_crew_move(crew, target_room)
		return
	if not transit_node.arrived_at_exit.is_connected(_on_crew_at_exit):
		transit_node.arrived_at_exit.connect(_on_crew_at_exit)
	_start_next_hop(crew)


func _start_next_hop(crew: CrewMember) -> void:
	var path: Array = _crew_transit_paths.get(crew.crew_id, [])
	if path.is_empty():
		_crew_transit_paths.erase(crew.crew_id)
		crew.transition_state(&"Idle")
		return
	var next_room_id: String = path[0]
	var current_room: BaseRoom = crew.get_parent() as BaseRoom
	if current_room:
		var exit_dir: String = _get_exit_direction_to(current_room, next_room_id)
		crew.transition_state(&"Transit", {
			"target_room": next_room_id,
			"exit_direction": exit_dir,
		})
	else:
		var target_room: BaseRoom = _rooms.get(next_room_id, null) as BaseRoom
		if target_room:
			_instant_crew_move(crew, target_room)
		path.pop_front()


func _on_crew_at_exit(crew_id: String) -> void:
	var path: Array = _crew_transit_paths.get(crew_id, [])
	if path.is_empty():
		return
	var next_room_id: String = path.pop_front()
	var next_room: BaseRoom = _rooms.get(next_room_id, null) as BaseRoom
	var crew: CrewMember = _find_crew_member(crew_id)
	if crew == null:
		_crew_transit_paths.erase(crew_id)
		return
	if next_room == null:
		crew.transition_state(&"Idle")
		_crew_transit_paths.erase(crew_id)
		return
	var current_room: BaseRoom = crew.get_parent() as BaseRoom
	var exit_dir: String = ""
	if current_room:
		exit_dir = _get_exit_direction_to(current_room, next_room_id)
	var enter_dir: String = _get_opposite_direction(exit_dir) if exit_dir != "" else _get_entrance_direction(next_room)
	if crew.get_parent():
		crew.get_parent().remove_child(crew)
	var entrance_pos: Vector2 = next_room.get_entrance_position(enter_dir)
	crew.position = entrance_pos - next_room.global_position
	next_room.add_child(crew)
	if path.is_empty():
		_crew_transit_paths.erase(crew_id)
		crew.home_position = _get_safe_position(next_room)
		var transit_node: CrewTransitState = crew.get_node("StateMachine/Transit") as CrewTransitState
		if transit_node:
			transit_node.begin_enter(entrance_pos)
		else:
			crew.transition_state(&"Idle")
	else:
		_start_next_hop(crew)


func _instant_crew_move(crew: CrewMember, target_room: BaseRoom) -> void:
	if crew.get_parent():
		crew.get_parent().remove_child(crew)
	crew.position = _get_safe_position(target_room)
	crew.home_position = crew.position
	target_room.add_child(crew)
	crew.transition_state(&"Idle")


func _find_crew_member(crew_id: String) -> CrewMember:
	for member: Node in get_tree().get_nodes_in_group("crew_members"):
		if member is CrewMember and (member as CrewMember).crew_id == crew_id:
			return member as CrewMember
	return null


func _get_entrance_direction(room: BaseRoom) -> String:
	for dir_name: String in ["south", "west", "east", "north"]:
		if room.has_entrance(dir_name):
			return dir_name
	return "south"


# --- Room Graph Pathfinding ---

func _get_room_neighbors(room: BaseRoom) -> Dictionary:
	var neighbors: Dictionary = {}
	for dir_name: String in ["north", "south", "east", "west"]:
		var target_id: String = room.get_exit_target(dir_name)
		if target_id != "" and _rooms.has(target_id):
			neighbors[dir_name] = target_id
	return neighbors


func _find_room_path(from_id: String, to_id: String) -> Array[String]:
	if from_id == to_id:
		return []
	var queue: Array[String] = [from_id]
	var visited: Dictionary = {from_id: ""}
	while queue.size() > 0:
		var current_id: String = queue.pop_front()
		var current_room: BaseRoom = _rooms.get(current_id, null) as BaseRoom
		if current_room == null:
			continue
		var neighbors: Dictionary = _get_room_neighbors(current_room)
		for dir_name: String in neighbors:
			var neighbor_id: String = neighbors[dir_name]
			if visited.has(neighbor_id):
				continue
			visited[neighbor_id] = current_id
			if neighbor_id == to_id:
				return _reconstruct_path(visited, from_id, to_id)
			queue.append(neighbor_id)
	return []


func _reconstruct_path(visited: Dictionary, from_id: String, to_id: String) -> Array[String]:
	var path: Array[String] = []
	var current: String = to_id
	while current != from_id:
		path.push_front(current)
		current = visited[current]
	return path


func _get_exit_direction_to(room: BaseRoom, target_room_id: String) -> String:
	for dir_name: String in ["north", "south", "east", "west"]:
		if room.get_exit_target(dir_name) == target_room_id:
			return dir_name
	return ""


func _is_room_unlocked(room_id: String) -> bool:
	for module_id: String in MODULE_DOORS:
		for door_entry: Array in MODULE_DOORS[module_id]:
			if door_entry[2] == room_id:
				return module_id in GameState.unlocked_modules
	return true


func _on_crew_interacted(crew_id: String) -> void:
	var contact: ContactData = Database.get_contact(crew_id)
	if contact == null:
		return

	var heart_event: HeartEventData = _check_heart_event(crew_id)
	if heart_event:
		_play_heart_event(heart_event)
		return

	var held_item: String = GameState.get_active_item_id()
	var is_tool: bool = held_item in ["watering_can", "trowel"]
	var is_giftable: bool = held_item != "" and not is_tool
	if is_giftable and CrewManager.can_give_gift(crew_id):
		var response: String = CrewManager.give_gift(crew_id, held_item)
		_show_dialogue(contact.contact_name, response)
	else:
		var chatter: String = CrewManager.talk_to(crew_id)
		_show_dialogue(contact.contact_name, chatter)


func _show_dialogue(speaker: String, text: String) -> void:
	if not _dialogue_panel.dialogue_finished.is_connected(_on_dialogue_finished):
		_dialogue_panel.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	_dialogue_panel.show_single(speaker, text)
	_open_overlay(_dialogue_panel)


func _play_heart_event(event: HeartEventData) -> void:
	GameState.unlocked_story_entries.append(event.event_id)
	if not _dialogue_panel.dialogue_finished.is_connected(_on_dialogue_finished):
		_dialogue_panel.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	_dialogue_panel.show_sequence(event.dialogue_sequence)
	_open_overlay(_dialogue_panel)


func _on_dialogue_finished() -> void:
	_close_active_overlay()


func _check_heart_event(crew_id: String) -> HeartEventData:
	if not _current_room:
		return null
	var hour: int = TimeManager.current_hour
	var day_name: String = TimeManager.get_day_name().to_lower()
	var heart_level: int = CrewManager.get_heart_level(crew_id)
	for event: HeartEventData in Database.get_all_heart_events():
		if event.crew_id != crew_id:
			continue
		if event.event_id in GameState.unlocked_story_entries:
			continue
		if heart_level < event.required_hearts:
			continue
		if event.required_room != "" and _current_room.room_id != event.required_room:
			continue
		if hour < event.required_hour_min or hour > event.required_hour_max:
			continue
		if event.required_day_of_week != "" and day_name != event.required_day_of_week:
			continue
		return event
	return null


# --- Utilities ---

func _sleep() -> void:
	if _transitioning:
		return
	_slept_in_bed = true
	TimeManager.end_day_early()


func _get_opposite_direction(direction: String) -> String:
	match direction:
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
	return direction


var _fade_rect: ColorRect = null

func _get_or_create_fade() -> ColorRect:
	if _fade_rect and is_instance_valid(_fade_rect):
		return _fade_rect
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = FADE_CANVAS_LAYER
	add_child(canvas)
	_fade_rect = ColorRect.new()
	_fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_fade_rect)
	return _fade_rect
