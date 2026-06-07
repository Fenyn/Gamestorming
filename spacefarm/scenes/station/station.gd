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

var _rooms: Dictionary = {}
var _current_room: BaseRoom = null
var _transitioning: bool = false
var _player: CharacterBody2D = null
var _canvas_modulate: CanvasModulate = null

@onready var _interact_hint: Label = %InteractHint
@onready var _day_label: Label = %DayLabel
@onready var _seed_info: Label = %SeedInfo
@onready var _room_name: Label = %RoomName
@onready var _directive_name: Label = %DirectiveName
@onready var _directive_progress: Label = %DirectiveProgress
@onready var _shipping_panel: ShippingPanel = $Overlays/ShippingPanel
@onready var _terminal_panel: StationTerminal = $Overlays/TerminalPanel
@onready var _hybridizer_panel: HybridizerPanel = $Overlays/HybridizerPanel
@onready var _comms_panel: CommsPanel = $Overlays/CommsPanel


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
	_update_day_label()
	_update_seed_info()
	_update_room_name()
	_update_directive_display()
	_update_lighting(TimeManager.current_hour)
	TimeManager.start_day()


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

	var fade: ColorRect = _get_or_create_fade()
	fade.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

	_day_label.text = "Day %d complete" % ended_day
	await get_tree().create_timer(DAY_TRANSITION_PAUSE).timeout

	_update_lighting(TimeManager.DAY_START_HOUR)
	TimeManager.start_day()
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
	await get_tree().create_timer(SEASON_TRANSITION_PAUSE).timeout

	TimeManager.advance_to_next_season()
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
	match module_id:
		"processing_lab":
			var hub: BaseRoom = _rooms.get("hub", null) as BaseRoom
			if hub:
				hub.unlock_airlock("west", "processing_lab")
				_reconnect_exit_zones_for_room(hub)
		"advanced_processing":
			var proc_lab: BaseRoom = _rooms.get("processing_lab", null) as BaseRoom
			if proc_lab:
				proc_lab.unlock_airlock("south", "advanced_processing")
				_reconnect_exit_zones_for_room(proc_lab)
		"hybridization_lab":
			var proc_lab2: BaseRoom = _rooms.get("processing_lab", null) as BaseRoom
			if proc_lab2:
				proc_lab2.unlock_airlock("east", "hybridization_lab")
				_reconnect_exit_zones_for_room(proc_lab2)


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


func _on_pod_opened(pod: CargoPod) -> void:
	_shipping_panel.show_panel(pod)


func _connect_hybridizers() -> void:
	for room: BaseRoom in _rooms.values():
		for child: Node in room.get_children():
			if child is Hybridizer:
				var hyb: Hybridizer = child as Hybridizer
				hyb.hybridizer_opened.connect(_on_hybridizer_opened.bind(hyb))


func _on_hybridizer_opened(hyb: Hybridizer) -> void:
	_hybridizer_panel.show_panel(hyb)


func _connect_station_interactables() -> void:
	for room: BaseRoom in _rooms.values():
		for child: Node in room.get_children():
			if child is StationInteractable:
				var obj: StationInteractable = child as StationInteractable
				obj.interacted.connect(_on_station_interactable.bind(obj.interactable_name))


func _on_station_interactable(interactable_name: String) -> void:
	match interactable_name:
		"TERMINAL":
			_terminal_panel.open()
		"COMMS":
			_comms_panel.open()
		"BED":
			_save_and_notify()


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
	_day_label.text = "Day %d | Season %d | %s" % [
		GameState.day, GameState.season, TimeManager.get_time_string()
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
		_room_name.text = _current_room.room_id.to_upper().replace("_", " ")


# --- Utilities ---

func _save_and_notify() -> void:
	var handler: SaveFileHandler = SaveFileHandler.new(GameState.SAVE_PATH, GameState.SAVE_VERSION)
	handler.save_dict(GameState.to_dict())
	EventBus.notification_requested.emit("Game saved.")


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
