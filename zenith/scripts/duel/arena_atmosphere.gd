class_name ArenaAtmosphere
extends Node3D
## The duel's surroundings: the ruined courtyard (CourtyardSet) around a flagstone table, lit as
## an overcast afternoon. Decorative, public school identity only. Never reads decks or private
## cards.

var reduced_motion: bool = false
var _colors: Array[Color] = [Color(0.34, 0.74, 0.82), Color(0.62, 0.56, 0.96)]
var _courtyard: CourtyardSet


func _ready() -> void:
	var duel: Node = get_parent()
	# The table top and its sides are the courtyard's own stone, lit by the sun like everything else.
	var inlay: MeshInstance3D = duel.get_node_or_null("Table/Inlay") as MeshInstance3D
	if inlay != null:
		inlay.material_override = CourtyardSet.dais_material()
	var table: MeshInstance3D = duel.get_node_or_null("Table") as MeshInstance3D
	if table != null and table.mesh != null:
		var sides: StandardMaterial3D = CourtyardSet.stone_material("brick", Vector3.ONE * 0.8, true)
		sides.albedo_color = Color(0.62, 0.6, 0.56)
		table.set_surface_override_material(0, sides)
	if DisplayServer.get_name() == "headless":
		return
	_courtyard = CourtyardSet.new()
	add_child(_courtyard)
	var env: WorldEnvironment = duel.get_node_or_null("WorldEnvironment")
	var sun: DirectionalLight3D = duel.get_node_or_null("Sun")
	if env != null and env.environment != null:
		_courtyard.apply_environment(env.environment, sun)


## The two seats' school colours. Kept for the callers; the courtyard is the same for every
## matchup, and school colour lives on the cards and the HUD.
func set_schools(first: Color, second: Color) -> void:
	_colors = [first, second]


func _process(_delta: float) -> void:
	if _courtyard != null:
		_courtyard.reduced_motion = reduced_motion
