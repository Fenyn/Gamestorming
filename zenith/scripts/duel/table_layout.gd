class_name TableLayout
extends Node3D
## Mirrored arena slots: enlarged duelists face each other in the center, with Life Decks
## beside them. Smaller support rows occupy the flanks; outer piles sit toward the rear.
## Zone bounds use the same scales as card slots so placement checks include the hero cards.

const CARD_SIZE: Vector2 = Vector2(0.63, 0.88)
const SEAL_SCALE: float = 0.55
const STANDING_STEP: float = 0.42
const STANDING_SCALE: float = 0.55
const HAND_STEP: float = 0.32
const HAND_SCALE: float = 0.70
const STACK_STEP: float = 0.0015
const CARD_LIFT: float = 0.01         # keeps card quads off the table plane so they never z-fight with it
const RESOLVING_LIFT: float = 0.25
const ZONE_PAD: float = 0.06          # felt outline sits this far outside the cards
const LABEL_STRIP: float = 0.14       # room under the cards for the zone name
const LINE_HEIGHT: float = 0.004
const LABEL_HEIGHT: float = 0.003
const LABEL_COLOR: Color = Color(0.66, 0.75, 0.81, 0.65)
const LINE_COLOR: Color = Color(0.68, 0.54, 0.29, 0.14)

## Row zones: marker, slots before cards start overlapping, and per-card scale.
const ROWS: Dictionary = {
	&"ally": {"marker": "AllyStart", "slots": 4, "step": 0.53, "direction": -1, "scale": 0.68, "label": "Allies"},
	&"drill": {"marker": "DrillStart", "slots": 5, "step": 0.45, "direction": -1, "scale": 0.60, "label": "Drills"},
	&"non_combat": {"marker": "NonCombatStart", "slots": 5, "step": 0.45, "scale": 0.60, "label": "Non-Combat"},
	&"seal": {"marker": "SealStart", "slots": 7, "step": 0.34, "scale": SEAL_SCALE, "label": "Seals"},
	# Cards kept out by Remain. Set outboard of the duelist, clear of the stat crest the
	# duelist fixture draws over that side of the table for both seats.
	&"remain": {"marker": "RemainStart", "slots": 2, "step": 0.35, "direction": -1, "scale": 0.60, "label": "Remain"},
}
## Single-card zones: marker and label.
const SINGLES: Dictionary = {
	&"duelist": {"marker": "Duelist", "label": "Duelist"},
	&"life_deck": {"marker": "LifeDeck", "label": "Life Deck"},
	&"resolving": {"marker": "Resolving", "label": "Play"},
}

@onready var p0: Node3D = $P0

var _labels: Array[Label3D] = []


func _card_scale(zone: StringName) -> float:
	if ROWS.has(zone):
		return float(ROWS[zone]["scale"])
	return 1.7 if zone == &"duelist" else (0.65 if zone == &"grounds" else 0.85)


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
	var scale_factor: float = _card_scale(zone)
	var yaw: float = 0.0
	if ROWS.has(zone):
		var row: Dictionary = ROWS[zone]
		pos = marker(str(row["marker"])) + Vector3(_row_offset(row, index, count), 0.002 * index, 0)
		scale_factor = float(row["scale"])
	else:
		match zone:
			&"life_deck":
				pos = marker(str(SINGLES[zone]["marker"])) + Vector3(0, STACK_STEP * index, 0)
			&"hand":
				var spread: float = HAND_STEP * (count - 1)
				pos = marker("HandStart") + Vector3(HAND_STEP * index - spread * 0.5, 0.002 * index, 0)
				scale_factor = HAND_SCALE
			&"resolving":
				pos = marker("Resolving") + Vector3(0, RESOLVING_LIFT, 0)
			&"grounds":
				pos = Vector3(1.5, 0.001, 0)
				yaw = PI * 0.5
			&"standing":
				# An effect that outlasts the Combat has no card left on the table, so its source
				# stands as a small ghost on its owner's inner edge, clear of every other zone.
				pos = Vector3(-4.58 + STANDING_STEP * index, 0.001, 0.36)
				scale_factor = STANDING_SCALE
			_:
				assert(SINGLES.has(zone), "TableLayout has no zone %s" % zone)
				pos = marker(str(SINGLES[zone]["marker"]))
	if player == 1 and zone != &"grounds":
		pos = Vector3(-pos.x, pos.y, -pos.z)
	if viewer == 1:
		yaw += PI
	# A narrower playing field leaves the portrait fixtures and decision rail clear.
	pos.x *= 0.72
	var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor * 0.92)
	return Transform3D(basis, pos + Vector3(0, CARD_LIFT, 0))


## Turns the zone labels to read upright for whoever holds the table.
func set_viewer(viewer: int) -> void:
	for l in _labels:
		l.rotation.y = PI if viewer == 1 else 0.0


## Empty zones do not compete with playable objects. Counts stay with their physical piles.
func refresh_occupancy(view: SeatView) -> void:
	for label in _labels:
		var zone: StringName = label.get_meta("zone")
		var index: int = int(label.get_meta("player"))
		var p: SeatPlayer = view.player(index)
		var count: int = 0
		match zone:
			&"ally": count = p.allies.size()
			&"drill": count = p.drills.size()
			&"non_combat": count = p.non_combats.size()
			&"seal": count = p.seals.size()
			&"remain": count = p.remain.size()
			&"life_deck": count = p.life_deck.size()
			&"duelist": count = 1
			&"resolving": count = view.resolving.size()
			&"grounds": count = int(view.grounds >= 0)
		label.visible = count > 0 and zone not in [&"duelist", &"resolving", &"life_deck"]
		label.text = str(label.get_meta("title"))


## X offset of card `index` in a row. Past the zone's slot count the row squeezes so the last
## card still sits inside the outline, fanned over its neighbours. Rows grow away from
## the fighter: left-side rows have their first card at the right edge.
func _row_offset(row: Dictionary, index: int, count: int) -> float:
	var slots: int = int(row["slots"])
	var step: float = float(row["step"]) * float(row.get("direction", 1))
	if count <= slots:
		return step * index
	return step * (slots - 1) * float(index) / float(count - 1)


## Felt rectangle for a zone on the near side: the cards it holds, padding, and a label strip on
## the owner's (high z) edge. Every zone in a row is the same height, so rows read as bands.
func _zone_rect(zone: StringName) -> Rect2:
	# Rectangles account for the same card scale and horizontal compression as slot().
	var size: Vector2 = CARD_SIZE * _card_scale(zone) * 0.92
	size.x /= 0.72
	var center: Vector3 = Vector3.ZERO
	if ROWS.has(zone):
		var row: Dictionary = ROWS[zone]
		var span: float = float(row["step"]) * (int(row["slots"]) - 1)
		size.x += span
		center = marker(str(row["marker"])) + Vector3(span * 0.5 * float(row.get("direction", 1)), 0, 0)
	elif zone == &"grounds":
		size = Vector2(CARD_SIZE.y / 0.72, CARD_SIZE.x) * _card_scale(zone) * 0.92
		center = Vector3(1.5, 0, 0)
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
			# Small inlaid ticks replace the full rectangular zone grid.
			if SINGLES.has(zone) and zone != &"resolving":
				_add_tick(mesh, r, player == 1)
			_add_label(zone, r, player == 1)
			placed.append(_mirrored(r) if player == 1 else r)
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


func _add_tick(mesh: ImmediateMesh, r: Rect2, mirror: bool) -> void:
	var s: float = -1.0 if mirror else 1.0
	var center: Vector2 = r.get_center()
	mesh.surface_add_vertex(Vector3((center.x - 0.08) * s * 0.72, 0, r.end.y * s))
	mesh.surface_add_vertex(Vector3((center.x + 0.08) * s * 0.72, 0, r.end.y * s))


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
	l.set_meta("zone", zone)
	l.set_meta("player", 1 if mirror else 0)
	l.set_meta("title", l.text)
	l.font_size = 24 if ROWS.has(zone) else 32
	l.pixel_size = 0.0032 if zone == &"life_deck" else 0.004
	l.modulate = LABEL_COLOR
	l.shaded = false
	l.double_sided = false
	l.no_depth_test = false
	# Centred in the label strip on the owner's edge; Grounds has no strip, so it sits inside.
	var s: float = -1.0 if mirror else 1.0
	var z: float = r.end.y - (LABEL_STRIP * 0.5 if zone != &"grounds" else 0.1)
	if ROWS.has(zone):
		# Keep row captions toward the arena center, clear of the duelist's stat crests.
		z = r.position.y + 0.02
	l.position = Vector3(r.get_center().x * s * 0.72, LABEL_HEIGHT, z * s)
	# Lying flat with no yaw, a Label3D reads upright for the unrotated camera; set_viewer turns
	# every label with the camera, so both sides always read the same way up.
	l.rotation = Vector3(-PI * 0.5, 0, 0)
	add_child(l)
	_labels.append(l)
