class_name TableLayout
extends Node3D
## Zone slots on the table. Markers under P0 anchor the near side; the far side is the same
## layout mirrored through the table centre. Every zone owns a rectangle that no other zone
## touches, and the outlines and labels drawn on the felt come from the same numbers the slots
## use, so they can never disagree.
##
## Near side, two rows plus the hand, on a grid with a 0.12 gutter between every outline:
##   z 2.26   Mastery | Allies x5 | Fighter | Tokens x7 | Life Deck | Discard
##   z 1.00   Master (Armory under it) | Drills x5 | Play (card in flight) | Non-Combats x5 | Removed
##   Grounds lies across the centre line. Outer columns line up (Mastery over Master, Discard over
##   Removed, Allies over Drills) so the eye reads the table as a grid.
## Each outline holds its cards plus a label strip on the owner's edge, so a label is never
## covered by a card.

const CARD_SIZE: Vector2 = Vector2(0.63, 0.88)
const ROW_STEP: float = 0.71          # card width plus a gap, for a row of full-size cards
const TOKEN_STEP: float = 0.37
const TOKEN_SCALE: float = 0.55
const HAND_STEP: float = 0.32
const HAND_SCALE: float = 0.70
const STACK_STEP: float = 0.0015
const CARD_LIFT: float = 0.01         # keeps card quads off the table plane so they never z-fight with it
const RESOLVING_LIFT: float = 0.25
const ZONE_PAD: float = 0.06          # felt outline sits this far outside the cards
const LABEL_STRIP: float = 0.14       # room under the cards for the zone name
const LINE_HEIGHT: float = 0.004
const LABEL_HEIGHT: float = 0.003
const LABEL_COLOR: Color = Color(1.0, 1.0, 1.0, 0.34)
const LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.18)

## Row zones: marker, slots before cards start overlapping, and per-card scale.
const ROWS: Dictionary = {
	&"ally": {"marker": "AllyStart", "slots": 5, "step": ROW_STEP, "scale": 1.0, "label": "Allies"},
	&"drill": {"marker": "DrillStart", "slots": 5, "step": ROW_STEP, "scale": 1.0, "label": "Drills"},
	&"non_combat": {"marker": "NonCombatStart", "slots": 5, "step": ROW_STEP, "scale": 1.0, "label": "Non-Combat"},
	&"token": {"marker": "TokenStart", "slots": 7, "step": TOKEN_STEP, "scale": TOKEN_SCALE, "label": "Royal Tokens"},
}
## Single-card zones: marker and label.
const SINGLES: Dictionary = {
	&"fighter": {"marker": "Fighter", "label": "Fighter"},
	&"mastery": {"marker": "Mastery", "label": "Mastery"},
	&"master": {"marker": "Master", "label": "Master · Armory"},
	&"life_deck": {"marker": "LifeDeck", "label": "Life Deck"},
	&"discard": {"marker": "Discard", "label": "Discard"},
	&"removed": {"marker": "Removed", "label": "Removed"},
	&"resolving": {"marker": "Resolving", "label": "Play"},
}

@onready var p0: Node3D = $P0

var _labels: Array[Label3D] = []


func _ready() -> void:
	_draw_marks()


func marker(name: String) -> Vector3:
	var m: Node3D = p0.get_node_or_null(NodePath(name))
	assert(m != null, "TableLayout is missing marker %s" % name)
	return m.position


## World transform for a card in a zone. `index` and `count` place it within a row or stack.
## Positions mirror for player 1; every card turns to read upright for `viewer`, as a digital
## client does, rather than facing its owner as on a physical table.
func slot(player: int, zone: StringName, index: int = 0, count: int = 1, viewer: int = 0) -> Transform3D:
	var pos: Vector3 = Vector3.ZERO
	var scale_factor: float = 1.0
	var yaw: float = 0.0
	if ROWS.has(zone):
		var row: Dictionary = ROWS[zone]
		pos = marker(str(row["marker"])) + Vector3(_row_offset(row, index, count), 0.002 * index, 0)
		scale_factor = float(row["scale"])
	else:
		match zone:
			&"life_deck", &"discard", &"removed":
				pos = marker(str(SINGLES[zone]["marker"])) + Vector3(0, STACK_STEP * index, 0)
			&"master":
				# Armory cards stack face down under the Master; index 0 is the Master itself.
				pos = marker("Master") + Vector3(0, STACK_STEP * (count + 1 - index), 0)
			&"hand":
				var spread: float = HAND_STEP * (count - 1)
				pos = marker("HandStart") + Vector3(HAND_STEP * index - spread * 0.5, 0.002 * index, 0)
				scale_factor = HAND_SCALE
			&"resolving":
				pos = marker("Resolving") + Vector3(0, RESOLVING_LIFT, 0)
			&"grounds":
				pos = Vector3(0, 0.001, 0)
				yaw = PI * 0.5
			_:
				assert(SINGLES.has(zone), "TableLayout has no zone %s" % zone)
				pos = marker(str(SINGLES[zone]["marker"]))
	if player == 1 and zone != &"grounds":
		pos = Vector3(-pos.x, pos.y, -pos.z)
	if viewer == 1:
		yaw += PI
	var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor)
	return Transform3D(basis, pos + Vector3(0, CARD_LIFT, 0))


## Turns the zone labels to read upright for whoever holds the table.
func set_viewer(viewer: int) -> void:
	for l in _labels:
		l.rotation.y = PI if viewer == 1 else 0.0


## X offset of card `index` in a row. Past the zone's slot count the row squeezes so the last
## card still sits inside the outline, fanned over its neighbours.
func _row_offset(row: Dictionary, index: int, count: int) -> float:
	var slots: int = int(row["slots"])
	var step: float = float(row["step"])
	if count <= slots:
		return step * index
	return step * (slots - 1) * float(index) / float(count - 1)


## Felt rectangle for a zone on the near side: the cards it holds, padding, and a label strip on
## the owner's (high z) edge. Every zone in a row is the same height, so rows read as bands.
func _zone_rect(zone: StringName) -> Rect2:
	var size: Vector2 = CARD_SIZE
	var center: Vector3 = Vector3.ZERO
	if ROWS.has(zone):
		var row: Dictionary = ROWS[zone]
		var span: float = float(row["step"]) * (int(row["slots"]) - 1)
		size.x = CARD_SIZE.x * float(row["scale"]) + span
		center = marker(str(row["marker"])) + Vector3(span * 0.5, 0, 0)
	elif zone == &"grounds":
		size = Vector2(CARD_SIZE.y, CARD_SIZE.x)
	else:
		center = marker(str(SINGLES[zone]["marker"]))
	size += Vector2.ONE * ZONE_PAD * 2.0
	var r: Rect2 = Rect2(Vector2(center.x, center.z) - size * 0.5, size)
	if zone != &"grounds":
		r.size.y += LABEL_STRIP
	return r


func _draw_marks() -> void:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var zones: Array[StringName] = []
	zones.append_array(ROWS.keys())
	zones.append_array(SINGLES.keys())
	var placed: Array[Rect2] = []
	for zone in zones:
		var r: Rect2 = _zone_rect(zone)
		for player in range(2):
			_add_rect(mesh, r, player == 1)
			_add_label(zone, r, player == 1)
			placed.append(_mirrored(r) if player == 1 else r)
	_add_rect(mesh, _zone_rect(&"grounds"), false)
	_add_label(&"grounds", _zone_rect(&"grounds"), false)
	placed.append(_zone_rect(&"grounds"))
	mesh.surface_end()
	_assert_no_overlap(placed)
	var lines: MeshInstance3D = MeshInstance3D.new()
	lines.name = "Outlines"
	lines.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = LINE_COLOR
	lines.material_override = mat
	lines.position.y = LINE_HEIGHT
	add_child(lines)


func _mirrored(r: Rect2) -> Rect2:
	return Rect2(-r.end, r.size)


## Every outline must stay clear of every other one and inside the table top.
func _assert_no_overlap(rects: Array[Rect2]) -> void:
	var table: Rect2 = Rect2(-5.2, -3.7, 10.4, 7.4)
	for i in range(rects.size()):
		assert(table.encloses(rects[i]), "TableLayout: zone %d leaves the table (%s)" % [i, rects[i]])
		for j in range(i + 1, rects.size()):
			assert(not rects[i].intersects(rects[j]), "TableLayout: zones overlap (%s and %s)" % [rects[i], rects[j]])


func _add_rect(mesh: ImmediateMesh, r: Rect2, mirror: bool) -> void:
	var s: float = -1.0 if mirror else 1.0
	var corners: Array[Vector3] = [
		Vector3(r.position.x * s, 0, r.position.y * s),
		Vector3(r.end.x * s, 0, r.position.y * s),
		Vector3(r.end.x * s, 0, r.end.y * s),
		Vector3(r.position.x * s, 0, r.end.y * s),
	]
	for i in range(4):
		mesh.surface_add_vertex(corners[i])
		mesh.surface_add_vertex(corners[(i + 1) % 4])


func _add_label(zone: StringName, r: Rect2, mirror: bool) -> void:
	var text: String = "Grounds" if zone == &"grounds" else str((ROWS[zone] if ROWS.has(zone) else SINGLES[zone])["label"])
	var l: Label3D = Label3D.new()
	l.text = text.to_upper()
	l.font_size = 26
	l.pixel_size = 0.004
	l.modulate = LABEL_COLOR
	l.shaded = false
	l.double_sided = false
	l.no_depth_test = false
	# Centred in the label strip on the owner's edge; Grounds has no strip, so it sits inside.
	var s: float = -1.0 if mirror else 1.0
	var z: float = r.end.y - (LABEL_STRIP * 0.5 if zone != &"grounds" else 0.1)
	l.position = Vector3(r.get_center().x * s, LABEL_HEIGHT, z * s)
	# Lying flat with no yaw, a Label3D reads upright for the unrotated camera; set_viewer turns
	# every label with the camera, so both sides always read the same way up.
	l.rotation = Vector3(-PI * 0.5, 0, 0)
	add_child(l)
	_labels.append(l)
