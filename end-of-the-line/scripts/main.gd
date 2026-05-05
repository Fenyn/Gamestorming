extends Node3D

const MAP_NODE_SCRIPT: GDScript = preload("res://scripts/map/map_node.gd")
const NODE_DATA_PATHS: Array[String] = [
	"res://resources/map_nodes/mine.tres",
	"res://resources/map_nodes/farm.tres",
	"res://resources/map_nodes/factory.tres",
	"res://resources/map_nodes/town.tres",
	"res://resources/map_nodes/port.tres",
]

var _nodes_container: Node3D
var _tracks_container: Node3D
var _trains_container: Node3D
var _builders_container: Node3D
var _hud: CanvasLayer
var _buy_panel: Control
var _ticket_shop: CanvasLayer


func _ready() -> void:
	_setup_environment()
	_setup_containers()
	_setup_map_nodes()
	_setup_ui()
	_connect_signals()
	_start_loop()


func _setup_environment() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.name = "GameCamera"
	camera.set_script(load("res://scripts/map/game_camera.gd"))
	add_child(camera)

	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.15, 0.18, 0.22)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.4, 0.5)
	environment.ambient_light_energy = 0.5
	env.environment = environment
	add_child(env)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	add_child(sun)

	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(60, 60)
	var ground_mat: StandardMaterial3D = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.2, 0.3, 0.15)
	plane.material = ground_mat
	ground.mesh = plane
	ground.position = Vector3(3, -0.01, 0)
	add_child(ground)


func _setup_containers() -> void:
	_nodes_container = Node3D.new()
	_nodes_container.name = "Nodes"
	add_child(_nodes_container)

	_tracks_container = Node3D.new()
	_tracks_container.name = "Tracks"
	add_child(_tracks_container)
	NetworkManager.track_container = _tracks_container

	_trains_container = Node3D.new()
	_trains_container.name = "Trains"
	add_child(_trains_container)
	TrainManager.train_container = _trains_container

	_builders_container = Node3D.new()
	_builders_container.name = "Builders"
	add_child(_builders_container)
	BuilderManager.builder_container = _builders_container


func _setup_map_nodes() -> void:
	for path: String in NODE_DATA_PATHS:
		var data: NodeData = load(path) as NodeData
		var node_3d: Node3D = Node3D.new()
		node_3d.name = data.display_name.replace(" ", "")
		node_3d.set_script(MAP_NODE_SCRIPT)
		node_3d.set("node_data", data)
		_nodes_container.add_child(node_3d)


func _setup_ui() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	_hud.set_script(load("res://scripts/ui/hud.gd"))
	add_child(_hud)

	_buy_panel = Control.new()
	_buy_panel.name = "BuyPanel"
	_buy_panel.set_script(load("res://scripts/ui/buy_panel.gd"))
	_hud.add_child(_buy_panel)

	_ticket_shop = CanvasLayer.new()
	_ticket_shop.name = "TicketShop"
	_ticket_shop.layer = 10
	_ticket_shop.set_script(load("res://scripts/ui/ticket_shop.gd"))
	add_child(_ticket_shop)
	_ticket_shop.shop_closed.connect(_start_loop)


func _connect_signals() -> void:
	EventBus.loop_ending.connect(_on_loop_ending)


func _start_loop() -> void:
	TrainManager.clear_all()
	BuilderManager.clear_all()
	NetworkManager.reset_to_starter()
	GameState.start_loop()

	_spawn_starter_handcar()


func _spawn_starter_handcar() -> void:
	var data: TrainTypeData = TrainManager.train_types["handcar"] as TrainTypeData
	TrainManager._spawn_train(data)
	GameState.owned_trains["handcar"] = 1


func _on_loop_ending() -> void:
	var tickets_earned: int = GameFormulas.calculate_tickets(GameState.total_gold_this_loop)
	GameState.add_tickets(tickets_earned)
	EventBus.loop_reset.emit(tickets_earned)
	_ticket_shop.show_shop(tickets_earned)
