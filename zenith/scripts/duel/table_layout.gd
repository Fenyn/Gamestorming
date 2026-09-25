class_name TableLayout
extends Node3D
## Mirrored hourglass: each seat holds a wide lobe of the mat, and the fighters face each other
## across the narrow waist between them, where attacks and defenses are played. In each lobe the
## Life Deck and Discard stand on the fighter's left with the Drill and Ally rows beyond them, the
## Mastery on its right with the Non-Combat and Seal rows beyond it, and Out, the Relic and Remain
## along the owner's edge either side of the stat plaque, far enough out to clear the opponent's
## hand fan, which the far seat's plaque draws beside it. Zone bounds use the same scales as card
## slots so placement checks include the hero cards.

const CARD_SIZE: Vector2 = Vector2(0.63, 0.88)
const SEAL_SCALE: float = 0.75
const STANDING_STEP: float = 0.42
const STANDING_SCALE: float = 0.55
## Standing ghosts line up in the waist, left of the arena, on their owner's half.
const STANDING_START: Vector3 = Vector3(-1.5, 0.001, 0.3)
const HAND_STEP: float = 0.32
const HAND_SCALE: float = 0.70
const STACK_STEP: float = 0.0015
const CARD_LIFT: float = 0.01         # keeps card quads off the table plane so they never z-fight with it
const RESOLVING_LIFT: float = 0.25
const ZONE_PAD: float = 0.06          # felt outline sits this far outside the cards
const LABEL_STRIP: float = 0.14       # room under the cards for the zone name
const LINE_HEIGHT: float = 0.004
const LABEL_HEIGHT: float = 0.003
const FAR_LABEL_SCALE: float = 1.5
## Ivory ink printed on the charcoal playmat, like a real mat's zone marks.
const LABEL_COLOR: Color = Color(ZenithTheme.TEXT, 0.85)
const LINE_COLOR: Color = Color(0.86, 0.82, 0.74, 0.32)

## Row zones: marker, slots before cards start overlapping, and per-card scale.
const ROWS: Dictionary = {
	&"ally": {"marker": "AllyStart", "slots": 3, "step": 0.6, "direction": -1, "scale": 0.9, "label": "Allies"},
	&"drill": {"marker": "DrillStart", "slots": 3, "step": 0.6, "direction": -1, "scale": 0.9, "label": "Drills"},
	&"non_combat": {"marker": "NonCombatStart", "slots": 3, "step": 0.6, "scale": 0.9, "label": "Non-Combat"},
	&"seal": {"marker": "SealStart", "slots": 6, "step": 0.36, "scale": SEAL_SCALE, "label": "Seals"},
	# Cards kept out by Remain, on the owner's edge beside Out.
	&"remain": {"marker": "RemainStart", "slots": 2, "step": 0.45, "direction": -1, "scale": 0.7, "label": "Remain"},
}
## Single-card zones: marker and label. Discard and Removed are stacks like the Life Deck; the
## Relic is one card with its Reserve face down under it.
const SINGLES: Dictionary = {
	&"duelist": {"marker": "Duelist", "label": "Duelist"},
	&"life_deck": {"marker": "LifeDeck", "label": "Life Deck"},
	&"resolving": {"marker": "Resolving", "label": "Play"},
	&"discard": {"marker": "Discard", "label": "Discard"},
	&"removed": {"marker": "Removed", "label": "Out"},
	&"mastery": {"marker": "Mastery", "label": "Mastery"},
	&"relic": {"marker": "Relic", "label": "Relic"},
}
## Piles: their felt is outlined and clickable even when empty, and a click opens the browser.
## The Relic with its Reserve under it is one pile.
const PILES: Array[StringName] = [&"discard", &"removed", &"relic"]
## Zones whose caption sits on the inner (table-centre) edge.
const TOP_CAPTIONS: Array[StringName] = [&"discard"]
const DUELIST_SCALE: float = 2.6
const MASTERY_SCALE: float = 1.3
const RESOLVING_SCALE: float = 1.3
const LIFE_SCALE: float = 1.0
const PILE_SCALE: float = 0.7         # Out, and the Relic with its Reserve
const DISCARD_SCALE: float = 0.8
const DISCARD_PAD: float = 0.02
const DISCARD_STRIP: float = 0.12
const RESERVE_PEEK: float = 0.02      # each Reserve card shows this much edge past the Relic
const RESERVE_FAN: float = ZONE_PAD   # the whole Reserve fans no further than the outline's padding

## A click on a pile's felt (its outline or its caption), for either seat.
signal pile_clicked(player: int, zone: StringName)

@onready var p0: Node3D = $P0

var _labels: Array[Label3D] = []

func _card_scale(zone: StringName) -> float:
	if ROWS.has(zone):
		return float(ROWS[zone]["scale"])
	if zone == &"duelist":
		return DUELIST_SCALE
	if zone == &"grounds":
		return 0.65
	if zone == &"resolving":
		return RESOLVING_SCALE
	if zone == &"mastery":
		return MASTERY_SCALE
	if zone == &"discard":
		return DISCARD_SCALE
	if zone == &"removed" or zone == &"relic":
		return PILE_SCALE
	return LIFE_SCALE


func _ready() -> void:
	_draw_marks()


func marker(name: String) -> Vector3:
	# The Relic has no marker of its own: it is Out mirrored across the duelist's centre line, so
	# the two piles flanking the stat plaque can never drift apart.
	if name == "Relic":
		var out: Vector3 = marker("Removed")
		return Vector3(2.0 * marker("Duelist").x - out.x, out.y, out.z)
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
			&"life_deck", &"discard", &"removed":
				pos = marker(str(SINGLES[zone]["marker"])) + Vector3(0, STACK_STEP * index, 0)
			&"relic":
				# Index 0 is the Relic, on top; the Reserve fans out under it toward the owner's
				# edge, inside the outline's padding, so the stack shows cards wait there.
				var step: float = minf(RESERVE_PEEK, RESERVE_FAN / float(maxi(1, count - 1)))
				pos = marker("Relic") + Vector3(0, STACK_STEP * float(count - 1 - index), step * index)
			&"hand":
				var spread: float = HAND_STEP * (count - 1)
				pos = marker("HandStart") + Vector3(HAND_STEP * index - spread * 0.5, 0.002 * index, 0)
				scale_factor = HAND_SCALE
			&"resolving":
				pos = marker("Resolving") + Vector3(0, RESOLVING_LIFT, 0)
			&"grounds":
				# The shared field lies across the middle of the arena, under the cards in play.
				pos = Vector3(0, 0.001, 0)
				yaw = PI * 0.5
			&"standing":
				# An effect that outlasts the Combat has no card left on the table, so its source
				# stands as a small ghost in the waist on its owner's half, clear of every zone.
				pos = STANDING_START + Vector3(-STANDING_STEP * index, 0, 0)
				scale_factor = STANDING_SCALE
			_:
				assert(SINGLES.has(zone), "TableLayout has no zone %s" % zone)
				pos = marker(str(SINGLES[zone]["marker"]))
				# A boss power shares the Mastery's spot: it peeks out below the Mastery toward the
				# owner's edge, the way the Reserve fans under the Relic.
				if zone == &"mastery" and index > 0:
					pos += Vector3(0, -STACK_STEP * index, CARD_SIZE.y * MASTERY_SCALE * 0.35 * index)
	if player == 1 and zone != &"grounds":
		pos = Vector3(-pos.x, pos.y, -pos.z)
	if viewer == 1:
		yaw += PI
	var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor * 0.92)
	return Transform3D(basis, pos + Vector3(0, CARD_LIFT, 0))


## Turns the zone labels to read upright for whoever holds the table. The far half's captions are
## drawn half again as large, because distance shrinks them below reading size at 720p.
func set_viewer(viewer: int) -> void:
	for l in _labels:
		l.rotation.y = PI if viewer == 1 else 0.0
		var far: bool = int(l.get_meta("player")) != viewer and l.get_meta("zone") != &"grounds"
		l.pixel_size = float(l.get_meta("pixel_size")) * (FAR_LABEL_SCALE if far else 1.0)


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
			&"discard": count = p.discard.size()
			&"removed": count = p.removed.size()
			&"mastery": count = int(p.mastery >= 0) + int(p.boss_power >= 0)
			&"relic": count = int(p.relic >= 0) + p.reserve.size()
		label.visible = count > 0 and zone not in [&"duelist", &"resolving", &"life_deck"]
		label.text = str(label.get_meta("title"))
		# A pile keeps its caption while empty, so the felt still says what lands there, and
		# carries its count once it holds cards. The Relic's count is its Reserve.
		if zone in PILES:
			label.visible = true
			label.modulate = LABEL_COLOR if count > 0 else Color(LABEL_COLOR, LABEL_COLOR.a * 0.6)
			if zone == &"relic":
				if not p.reserve.is_empty():
					label.text = "%s · %d" % [label.text, p.reserve.size()]
			elif count > 0:
				label.text = "%s %d" % [label.text, count]


## X offset of card `index` in a row. Past the zone's slot count the row squeezes so the last
## card still sits inside the outline, fanned over its neighbours. Rows grow away from
## the fighter: left-side rows have their first card at the right edge.
func _row_offset(row: Dictionary, index: int, count: int) -> float:
	var slots: int = int(row["slots"])
	var step: float = float(row["step"]) * float(row.get("direction", 1))
	if count <= slots:
		return step * index
	return step * (slots - 1) * float(index) / float(count - 1)


## Felt rectangle for a zone on seat 0: the cards it holds, padding, and a label strip on the
## owner's (high z) edge, or the inner edge for TOP_CAPTIONS. Every zone in a row is the same
## height, so rows read as bands. The Life Deck has no strip: its count rides on the pile.
func _zone_rect(zone: StringName) -> Rect2:
	# Rectangles account for the same card scale as slot().
	var size: Vector2 = CARD_SIZE * _card_scale(zone) * 0.92
	var center: Vector3 = Vector3.ZERO
	if ROWS.has(zone):
		var row: Dictionary = ROWS[zone]
		var span: float = float(row["step"]) * (int(row["slots"]) - 1)
		size.x += span
		center = marker(str(row["marker"])) + Vector3(span * 0.5 * float(row.get("direction", 1)), 0, 0)
	elif zone == &"grounds":
		size = Vector2(CARD_SIZE.y, CARD_SIZE.x) * _card_scale(zone) * 0.92
	else:
		center = marker(str(SINGLES[zone]["marker"]))
	# Resolving cards have no felt mark or label. Validate their visible footprint rather than
	# reserving decorative padding that would falsely overlap the enlarged fighter cards.
	if zone != &"resolving":
		size += Vector2.ONE * _pad(zone) * 2.0
	var r: Rect2 = Rect2(Vector2(center.x, center.z) - size * 0.5, size)
	var strip: float = _strip(zone)
	if zone in TOP_CAPTIONS:
		r.position.y -= strip
		r.size.y += strip
	else:
		r.size.y += strip
	return r


## The card-sized part of a zone's rectangle, without its label strip.
func _card_rect(zone: StringName) -> Rect2:
	var r: Rect2 = _zone_rect(zone)
	var strip: float = _strip(zone)
	if zone in TOP_CAPTIONS:
		return Rect2(r.position + Vector2(0, strip), r.size - Vector2(0, strip))
	return Rect2(r.position, r.size - Vector2(0, strip))


## Felt padding around a zone's cards. The Discard squeezes between the Life Deck and Out, so its
## outline hugs the card.
func _pad(zone: StringName) -> float:
	return DISCARD_PAD if zone == &"discard" else ZONE_PAD


## Height of a zone's caption strip; none where there is no caption on the felt.
func _strip(zone: StringName) -> float:
	if zone in [&"grounds", &"resolving", &"life_deck"]:
		return 0.0
	return DISCARD_STRIP if zone == &"discard" else LABEL_STRIP


func _draw_marks() -> void:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var zones: Array[StringName] = []
	zones.append_array(ROWS.keys())
	zones.append_array(SINGLES.keys())
	var placed: Array[Rect2] = []
	for zone in zones:
		for player in range(2):
			var r: Rect2 = _zone_rect(zone)
			# Small inlaid ticks replace the full rectangular zone grid.
			if zone in PILES:
				# An empty pile is still a place: its card-sized outline stays on the felt, and
				# the whole mark, caption included, opens the pile when clicked.
				_add_rect(mesh, _card_rect(zone), player == 1)
				_add_pick(zone, r, player)
			elif SINGLES.has(zone) and zone != &"resolving":
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
	mesh.surface_add_vertex(Vector3((center.x - 0.08) * s, 0, r.end.y * s))
	mesh.surface_add_vertex(Vector3((center.x + 0.08) * s, 0, r.end.y * s))


## The playmat's outline, matching playmat.gdshader's `shape()` and its default uniforms: negative
## inside, in table units.
const MAT_LOBE_HALF: Vector2 = Vector2(4.4, 1.62)
const MAT_LOBE_CENTRE: float = 2.08
const MAT_WAIST_HALF: Vector2 = Vector2(2.4, 0.75)
const MAT_RING: float = 1.2
const MAT_CORNER: float = 0.3
const MAT_FILLET: float = 0.35
const MAT_RIM: float = 0.12
const MAT_CLEARANCE: float = 0.02


static func mat_distance(p: Vector2) -> float:
	var lobes: float = minf(_round_box(p - Vector2(0, MAT_LOBE_CENTRE), MAT_LOBE_HALF, MAT_CORNER),
		_round_box(p + Vector2(0, MAT_LOBE_CENTRE), MAT_LOBE_HALF, MAT_CORNER))
	var waist: float = _round_box(p, MAT_WAIST_HALF, MAT_CORNER)
	var h: float = clampf(0.5 + 0.5 * (waist - lobes) / MAT_FILLET, 0.0, 1.0)
	var joined: float = lerpf(waist, lobes, h) - MAT_FILLET * h * (1.0 - h)
	return minf(joined, p.length() - MAT_RING)


static func _round_box(p: Vector2, half_size: Vector2, r: float) -> float:
	var q: Vector2 = Vector2(absf(p.x), absf(p.y)) - half_size + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


## True when the whole rect lies on the fabric, clear of the rim by a caption's breathing room.
static func on_mat(r: Rect2) -> bool:
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		if mat_distance(corner) > -(MAT_RIM + MAT_CLEARANCE):
			return false
	return true


func _mirrored(r: Rect2) -> Rect2:
	return Rect2(-r.end, r.size)


## Every outline must stay clear of every other one and on the fabric of the mat.
func _assert_no_overlap(rects: Array[Rect2]) -> void:
	for i in range(rects.size()):
		assert(on_mat(rects[i]), "TableLayout: zone %d leaves the mat (%s)" % [i, rects[i]])
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


## A flat pick box over a pile's whole mark. It sits under the pile's cards, so a card in the
## pile still takes its own click first; this answers the empty felt and the caption.
func _add_pick(zone: StringName, r: Rect2, player: int) -> void:
	var s: float = -1.0 if player == 1 else 1.0
	var area: Area3D = Area3D.new()
	area.name = "Pick_%s_%d" % [zone, player]
	area.monitoring = false
	area.monitorable = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(r.size.x, 0.004, r.size.y)
	shape.shape = box
	area.add_child(shape)
	var center: Vector2 = r.get_center()
	area.position = Vector3(center.x * s, 0.0, center.y * s)
	area.input_event.connect(_on_pick_input.bind(player, zone))
	add_child(area)


## Pile felt takes the pointer only while the board does, the same as the cards on it.
func set_pickable(on: bool) -> void:
	for child in get_children():
		var area: Area3D = child as Area3D
		if area != null and area.input_ray_pickable != on:
			area.input_ray_pickable = on


func _on_pick_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int, player: int, zone: StringName) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pile_clicked.emit(player, zone)


func _add_label(zone: StringName, r: Rect2, mirror: bool) -> void:
	var text: String = "Grounds" if zone == &"grounds" else str((ROWS[zone] if ROWS.has(zone) else SINGLES[zone])["label"])
	var l: Label3D = Label3D.new()
	l.text = text.to_upper()
	l.set_meta("zone", zone)
	l.set_meta("player", 1 if mirror else 0)
	l.set_meta("title", l.text)
	l.font_size = 32
	l.pixel_size = 0.0032 if zone == &"life_deck" or zone == &"discard" else 0.004
	l.set_meta("pixel_size", l.pixel_size)
	l.modulate = LABEL_COLOR
	l.outline_size = 0   # printed ink has no halo
	l.shaded = false
	l.double_sided = false
	# The Discard's caption sits just past the Life Deck, and for the far seat that stack stands
	# between it and the camera; it is drawn over the stack rather than hidden behind it.
	l.no_depth_test = zone == &"discard"
	# Centred in the label strip on the owner's edge; Grounds has no strip, so it sits inside.
	var s: float = -1.0 if mirror else 1.0
	var z: float = r.end.y - (LABEL_STRIP * 0.5 if zone != &"grounds" else 0.1)
	if zone in TOP_CAPTIONS:
		z = r.position.y + _strip(zone) * 0.5
	elif ROWS.has(zone):
		# Keep row captions toward the arena center, clear of the duelist's stat crests.
		z = r.position.y + 0.02
	l.position = Vector3(r.get_center().x * s, LABEL_HEIGHT, z * s)
	# Lying flat with no yaw, a Label3D reads upright for the unrotated camera; set_viewer turns
	# every label with the camera, so both sides always read the same way up.
	l.rotation = Vector3(-PI * 0.5, 0, 0)
	add_child(l)
	_labels.append(l)
