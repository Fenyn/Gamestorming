class_name ArenaAtmosphere
extends Node3D
## The duel's surroundings: the ruined courtyard (CourtyardSet) around a flagstone table, lit as
## an overcast afternoon. Decorative, public school identity only. Never reads decks or private
## cards.

## The dais stone under the board: its colour, and a brightness multiplier over it. The board's
## own print (wash, rule, vignette) is set on Table/Inlay's shader.
@export var stone_tint: Color = CourtyardSet.TABLE_TINT:
	set(value):
		stone_tint = value
		_tint_table()
@export var stone_brightness: float = 1.0:
	set(value):
		stone_brightness = value
		_tint_table()

## The wash is the school colour held to this saturation and value, so every school sits as a
## tint in the stone rather than a painted floor.
const WASH_SATURATION: float = 0.6
const WASH_VALUE: float = 0.6

var reduced_motion: bool = false
var _courtyard: CourtyardSet
var _table_material: StandardMaterial3D = null
var _print: ShaderMaterial = null


func _ready() -> void:
	var duel: Node = get_parent()
	# The table is a block of the courtyard's stone, lit by the sun like everything else. The
	# board printed on top of it (Table/Inlay) is the scene's own.
	var table: MeshInstance3D = duel.get_node_or_null("Table") as MeshInstance3D
	if table != null and table.mesh != null:
		_table_material = CourtyardSet.table_material()
		_tint_table()
		table.set_surface_override_material(0, _table_material)
		var inlay: MeshInstance3D = table.get_node_or_null("Inlay") as MeshInstance3D
		if inlay != null:
			_print = inlay.material_override as ShaderMaterial
	if DisplayServer.get_name() == "headless":
		return
	_courtyard = CourtyardSet.new()
	add_child(_courtyard)
	var env: WorldEnvironment = duel.get_node_or_null("WorldEnvironment")
	var sun: DirectionalLight3D = duel.get_node_or_null("Sun")
	if env != null and env.environment != null:
		_courtyard.apply_environment(env.environment, sun)


## Each seat's half of the board takes its Mastery school's colour as a wash over the stone.
func set_schools(first: Color, second: Color) -> void:
	if _print == null:
		return
	_print.set_shader_parameter("wash_seat0", _muted(first))
	_print.set_shader_parameter("wash_seat1", _muted(second))


static func _muted(school: Color) -> Color:
	return Color.from_hsv(school.h, minf(school.s, WASH_SATURATION), minf(school.v, WASH_VALUE))


func _tint_table() -> void:
	if _table_material != null:
		_table_material.albedo_color = Color(stone_tint * stone_brightness, 1.0)


func _process(_delta: float) -> void:
	if _courtyard != null:
		_courtyard.reduced_motion = reduced_motion
