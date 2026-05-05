extends Node3D

enum GameState { BUILDING, IMPLODING, SHOP }

@onready var game_manager: GameManager = $GameManager
@onready var maw: Maw = $Maw
@onready var hud: HUD = $HUD
@onready var piece_catalog: PieceCatalog = $PieceCatalog
@onready var track_builder: TrackBuilder = $TrackBuilder
@onready var build_controller: BuildController = $BuildController
@onready var piece_palette: PiecePalette = $HUD/PiecePalette
@onready var prestige_manager: PrestigeManager = $PrestigeManager
@onready var void_marble_shop: VoidMarbleShop = $HUD/VoidMarbleShop
@onready var blueprint_manager: BlueprintManager = $BlueprintManager
@onready var build_boundary: BuildBoundary = $BuildBoundary
@onready var portal_manager: PortalManager = $PortalManager

var state: GameState = GameState.BUILDING
var active_orbs: int = 0

func _ready() -> void:
	_connect_signals()
	_configure_systems()
	_start_building_phase()

func _connect_signals() -> void:
	maw.orb_consumed.connect(_on_maw_consumed)
	maw.implosion_started.connect(_on_implosion_started)
	maw.implosion_finished.connect(_on_implosion_finished)
	game_manager.spark_manager.sparks_changed.connect(hud.update_sparks)
	piece_palette.piece_selected.connect(_on_piece_selected)
	track_builder.piece_placed.connect(_on_piece_placed)
	prestige_manager.build_space_changed.connect(build_boundary.set_radius)
	void_marble_shop.shop_closed.connect(_on_shop_closed)
	portal_manager.orb_spawned.connect(_on_orb_spawned)

func _configure_systems() -> void:
	piece_palette.set_catalog(piece_catalog)
	piece_palette.bind_spark_manager(game_manager.spark_manager)
	piece_palette.bind_prestige(prestige_manager)
	track_builder.catalog = piece_catalog
	track_builder.spark_manager = game_manager.spark_manager
	build_controller.track_builder = track_builder
	build_controller.camera = $Camera
	void_marble_shop.bind_prestige(prestige_manager)
	portal_manager.bind_prestige(prestige_manager)

func _unhandled_input(event: InputEvent) -> void:
	if state != GameState.BUILDING:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_F5:
				_save_blueprint(0)
			KEY_F9:
				_load_blueprint(0)

# --- State transitions ---

func _start_building_phase() -> void:
	state = GameState.BUILDING
	game_manager.spark_manager.earn(prestige_manager.get_starting_sparks())
	maw.consumption_threshold = prestige_manager.get_maw_threshold()
	build_boundary.set_radius(prestige_manager.get_build_radius())
	portal_manager.spawn_portals_for_cycle()
	build_controller.set_process_unhandled_input(true)

func _on_implosion_started() -> void:
	state = GameState.IMPLODING
	build_controller.set_process_unhandled_input(false)

func _on_implosion_finished() -> void:
	var earned: int = prestige_manager.complete_cycle(maw.consumed_sparks)

	track_builder.clear_all()
	portal_manager.clear_portals()
	game_manager.spark_manager.reset()
	maw.reset()
	active_orbs = 0

	hud.update_maw(0.0)
	hud.update_orb_count(0)
	hud.update_void_marbles(prestige_manager.void_marbles)

	state = GameState.SHOP
	void_marble_shop.show_shop()

func _on_shop_closed() -> void:
	_start_building_phase()

# --- Piece placement ---

func _on_piece_selected(piece_id: String) -> void:
	track_builder.select_piece(piece_id)

func _on_piece_placed(_piece: TrackPiece) -> void:
	hud.hide_tutorial()
	_check_portal_connections()

func _check_portal_connections() -> void:
	for portal: DreamerPortal in portal_manager.get_unconnected_portals():
		var portal_pos: Vector3 = portal.get_connection_world_position()
		for piece: TrackPiece in track_builder.placed_pieces:
			if piece.piece_data == null:
				continue
			for i: int in piece.piece_data.connections.size():
				var wc: Dictionary = piece.get_world_connection(i)
				var piece_pos: Vector3 = wc["position"] as Vector3
				if portal_pos.distance_to(piece_pos) < 1.0:
					portal_manager.connect_portal(portal)
					break

# --- Orb lifecycle ---

func _on_orb_spawned(orb: Orb) -> void:
	active_orbs += 1
	orb.spark_multiplier *= prestige_manager.get_spark_multiplier()
	game_manager.on_orb_spawned(orb)
	orb.orb_consumed.connect(_on_orb_done.unbind(2))
	hud.update_orb_count(active_orbs)

func _on_orb_done() -> void:
	active_orbs -= 1
	hud.update_orb_count(active_orbs)

func _on_maw_consumed(_sparks: float) -> void:
	hud.update_maw(maw.get_fill_percentage())

# --- Blueprints ---

func _save_blueprint(slot: int) -> void:
	if slot >= prestige_manager.get_blueprint_slot_count():
		return
	blueprint_manager.save_blueprint(slot, track_builder.placed_pieces)

func _load_blueprint(slot: int) -> void:
	if not blueprint_manager.has_blueprint(slot):
		return
	blueprint_manager.load_blueprint(
		slot, piece_catalog, track_builder, game_manager.spark_manager
	)
	_check_portal_connections()
