extends Node3D
class_name Maw

signal orb_consumed(sparks: float)
signal implosion_started()
signal implosion_finished()

@export var consumption_threshold: float = 2000.0

var consumed_sparks: float = 0.0

@onready var _consume_area: Area3D = $ConsumeArea

var _pool_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
var _pulse_timer: float = 0.0
var _imploding: bool = false

func _ready() -> void:
	_consume_area.body_entered.connect(_on_body_entered)
	_build_visual()

func _process(delta: float) -> void:
	_pulse_timer += delta
	if _rim_mat and not _imploding:
		var fill: float = get_fill_percentage()
		var pulse_speed: float = 1.0 + fill * 3.0
		var pulse: float = 0.5 + 0.5 * sin(_pulse_timer * pulse_speed)
		var base_energy: float = 1.0 + fill * 5.0
		_rim_mat.emission_energy_multiplier = base_energy * (0.8 + 0.4 * pulse)

func _on_body_entered(body: Node3D) -> void:
	if body is Orb:
		_consume_orb(body as Orb)

func _consume_orb(orb: Orb) -> void:
	var sparks: float = orb.get_sparks()
	consumed_sparks += sparks
	orb_consumed.emit(sparks)
	orb.consume()
	_update_fill_visual()

	if consumed_sparks >= consumption_threshold:
		_trigger_implosion()

func _trigger_implosion() -> void:
	_imploding = true
	implosion_started.emit()
	if _rim_mat:
		_rim_mat.emission_energy_multiplier = 10.0
	if _pool_mat:
		_pool_mat.emission_energy_multiplier = 6.0
	await get_tree().create_timer(2.0).timeout
	_imploding = false
	implosion_finished.emit()

func get_fill_percentage() -> float:
	return clampf(consumed_sparks / consumption_threshold, 0.0, 1.0)

func reset() -> void:
	consumed_sparks = 0.0
	_imploding = false
	_update_fill_visual()

func _build_visual() -> void:
	var pool: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 1.5
	disc.bottom_radius = 1.5
	disc.height = 0.05
	disc.radial_segments = 48
	pool.mesh = disc
	pool.position.y = 0.01

	_pool_mat = StandardMaterial3D.new()
	_pool_mat.albedo_color = Color(0.05, 0.01, 0.08, 0.95)
	_pool_mat.emission_enabled = true
	_pool_mat.emission = Color(0.15, 0.03, 0.25)
	_pool_mat.emission_energy_multiplier = 0.5
	_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pool_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pool.material_override = _pool_mat
	add_child(pool)

	var rim: MeshInstance3D = MeshInstance3D.new()
	var rim_disc: CylinderMesh = CylinderMesh.new()
	rim_disc.top_radius = 1.65
	rim_disc.bottom_radius = 1.65
	rim_disc.height = 0.08
	rim_disc.radial_segments = 48
	rim.mesh = rim_disc
	rim.position.y = 0.02

	_rim_mat = StandardMaterial3D.new()
	_rim_mat.albedo_color = Color(0.4, 0.1, 0.6, 0.9)
	_rim_mat.emission_enabled = true
	_rim_mat.emission = Color(0.5, 0.15, 0.8)
	_rim_mat.emission_energy_multiplier = 2.0
	_rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rim.material_override = _rim_mat
	add_child(rim)

	var label: Label3D = Label3D.new()
	label.text = "THE MAW"
	label.position = Vector3(0, 0.5, 0)
	label.font_size = 24
	label.modulate = Color(0.6, 0.2, 0.8, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _update_fill_visual() -> void:
	var fill: float = get_fill_percentage()
	if _pool_mat:
		_pool_mat.emission_energy_multiplier = 0.5 + fill * 4.0
