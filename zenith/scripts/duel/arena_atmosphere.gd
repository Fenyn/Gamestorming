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
	# The table is a block of the courtyard's stone, lit by the sun like everything else. The
	# hourglass playmat on top of it (Table/Inlay) is the scene's own.
	var table: MeshInstance3D = duel.get_node_or_null("Table") as MeshInstance3D
	if table != null and table.mesh != null:
		table.set_surface_override_material(0, CourtyardSet.table_material())
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
