class_name DuelistReadout
extends Control
## Transparent resource ornaments surrounding the actual duelist card in the scene. The canvas
## lies on the table around the card (`DuelistDisplay`); the stat tracker itself stands on the
## table as a separate plate, drawn by a second readout with `part` set to PLATE.

signal redraw_requested

enum Part { ALL, PRINT, PLATE }

const PLAYER_STATUS: Script = preload("res://scripts/duel/player_status.gd")
## Warm charcoal and ivory, the table's own colours; seat colour only on the plate's rule.
const INK: Color = Color(0.085, 0.08, 0.075, 0.96)
const TEXT: Color = Color(0.95, 0.93, 0.87)
const MUTED: Color = Color(0.74, 0.71, 0.66)
const IVORY: Color = Color(0.9, 0.86, 0.76)
const ENERGY: Color = ZenithTheme.ENERGY
const FERVOR: Color = Color(0.95, 0.59, 0.29)
const TRACKER_SIZE: Vector2 = Vector2(540, 160)
## The plate's own canvas: the tracker inset by PLATE_PAD, with room under it for the lives tab.
const PLATE_PAD: Vector2 = Vector2(10, 10)
const PLATE_CANVAS: Vector2i = Vector2i(560, 196)
## The near seat's plate sits this many canvas pixels further toward the viewer, below the Out
## and Relic captions rather than between them.
const NEAR_DROP: float = 85.0
## Baseline of the Aspect caption below the duelist card's bottom edge, in canvas pixels.
const ASPECT_GAP: float = 34.0
## ALL draws everything on one canvas; PRINT leaves the tracker to the plate; PLATE draws only
## the tracker and its lives tab.
@export var part: Part = Part.ALL
var reduced_motion: bool = false
var preview_cost: int = 0
## Projected front-face bounds, in texture pixels relative to the card's world anchor.
var card_bounds: Rect2 = Rect2(-80, -90, 160, 180):
	set(value):
		if card_bounds.is_equal_approx(value):
			return
		card_bounds = value
		update_layout()
		request_redraw()
var stat_hit_rects: Array[Rect2] = []
## Canvas pixels of table the far seat's standing plate hides behind it; its status lines start
## past them. Set by DuelistDisplay from the plate's tilt.
var flag_clearance: float = 0.0:
	set(value):
		if is_equal_approx(flag_clearance, value):
			return
		flag_clearance = value
		update_layout()
		request_redraw()
var duelist_bounds: Rect2 = Rect2(-80, -90, 160, 180):
	set(value):
		if duelist_bounds.is_equal_approx(value):
			return
		duelist_bounds = value
		update_layout()
		request_redraw()
var _life: int = 0
var _hand: int = 0
var _energy: int = 0
var _energy_printed: int = 10
var _might: int = 0
var _might_printed: int = 0
var _fervor: int = 0
var _threshold: int = 5
var _aspect: int = 1
var _title: String = ""
var _control: String = ""
var _piles: String = ""
var _flags: PackedStringArray = PackedStringArray()
var _seal_sets: Dictionary = {}
var _reserve: int = 0
var _lives: int = 1          # how many points the rival needs against this seat
var _lives_lost: int = 0     # how many of them the rival has scored
var _show_lives: bool = false  # only when either side has more than one (adventure duels)
const LIFE_RED: Color = Color(0.93, 0.36, 0.36)
var _accent: Color = IVORY
var _active: bool = false
var _initialized: bool = false
var _player_index: int = -1
var _viewer: int = -1
var _duelist_uid: int = -1
var _flash: float = 0.0
var _tween: Tween
var _font: Font = ThemeDB.fallback_font
const PEEK_RISE: float = 18.0   # canvas pixels the back the rival is reading rises
const PEEK_TIP: float = 0.12    # and how far it tips outward, in radians
var _peek_slot: int = -1       # the slot drawn raised, kept while it settles back down
var _peek_target: int = -1     # the slot asked for, -1 for none
var _peek: float = 0.0
var _peek_tween: Tween = null


func refresh(view: SeatView, player_index: int, viewer: int, live: Dictionary = {}) -> void:
	var p: SeatPlayer = view.player(player_index)
	var duelist: SeatCard = view.card(p.duelist)
	var controllers: Array = live.get("controlling", [])
	var controlling_uid: int = int(controllers[player_index]) if player_index < controllers.size() else p.controlling
	var controller: SeatCard = view.card(controlling_uid)
	if duelist == null:
		return
	if controller == null:
		controller = duelist
	var same_identity: bool = _player_index == player_index and _viewer == viewer and _duelist_uid == duelist.uid
	if not same_identity or reduced_motion:
		if _tween != null:
			_tween.kill()
		_flash = 0.0
	if not same_identity:
		preview_cost = 0
	_player_index = player_index
	_viewer = viewer
	_duelist_uid = duelist.uid
	var old_values: Array[int] = [_life, _energy, _fervor, _aspect]
	var energies: Dictionary = live.get("energy", {})
	var mights: Dictionary = live.get("might", {})
	var aspects: Dictionary = live.get("aspect", {})
	var fervors: Array = live.get("fervor", [])
	var zones: Array = live.get("zones", [])
	var counts: Array = zones[player_index] if zones.size() > player_index else []
	_life = int(counts[0]) if counts.size() > 0 else p.life_deck.size()
	_energy = int(energies.get(controller.uid, energies.get(str(controller.uid), controller.energy)))
	_might = int(mights.get(controller.uid, mights.get(str(controller.uid), controller.might)))
	# The baselines are the engine's: printed Energy and the ladder rung that Energy prints at.
	# The client only subtracts, which is the same difference `SeatPlayer` publishes.
	_energy_printed = p.energy_printed
	_might_printed = p.might_printed
	_fervor = int(fervors[player_index]) if fervors.size() > player_index else p.fervor
	_threshold = maxi(1, p.fervor_needed)
	_aspect = int(aspects.get(duelist.uid, aspects.get(str(duelist.uid), duelist.aspect)))
	_title = duelist.title
	_control = "YOU" if player_index == viewer else "OPPONENT"
	if controller.uid != duelist.uid:
		_control = "%s IN CONTROL" % controller.title
	_accent = SeatColors.accent(view, player_index, Session.color_seed)
	_active = int(live.get("active", view.active)) == player_index and not view.is_over()
	_hand = maxi(0, int(counts[1]) if counts.size() > 1 else p.hand.size())
	var discard: int = int(counts[2]) if counts.size() > 2 else p.discard.size()
	var removed: int = int(counts[3]) if counts.size() > 3 else p.removed.size()
	_piles = "Discard %d" % discard if player_index != viewer else "Hand %d   Discard %d" % [_hand, discard]
	if removed > 0:
		_piles += "   Out %d" % removed
	_reserve = p.reserve.size()
	if _reserve > 0:
		_piles += "   Reserve %d" % _reserve
	_seal_sets.clear()
	for seal_uid in p.seals:
		var seal_card: SeatCard = view.card(seal_uid)
		if seal_card == null or seal_card.hidden():
			continue
		var seal_def: CardDef = Session.library.get_def(seal_card.def_id)
		if seal_def == null or seal_def.seal_set.is_empty():
			continue
		var held: Array = _seal_sets.get(seal_def.seal_set, [])
		if not held.has(seal_def.seal_number):
			held.append(seal_def.seal_number)
		_seal_sets[seal_def.seal_set] = held
	_flags = PLAYER_STATUS.flags(p)
	# Lives: a seat falls when the rival scores `points_to_win[rival]` points against it.
	var rival: int = 1 - player_index
	_lives = maxi(1, int(view.points_to_win[rival])) if view.points_to_win.size() == 2 else 1
	_lives_lost = clampi(int(view.points[rival]), 0, _lives) if view.points.size() == 2 else 0
	_show_lives = view.points_to_win.size() == 2 and (int(view.points_to_win[0]) > 1 or int(view.points_to_win[1]) > 1)
	if _initialized and same_identity and old_values != [_life, _energy, _fervor, _aspect] and not reduced_motion:
		if _tween != null:
			_tween.kill()
		_flash = 1.0
		_tween = create_tween()
		_tween.tween_method(_set_flash, 1.0, 0.0, 0.55)
	_initialized = true
	update_layout()
	request_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	request_redraw()


## All core fighter data shares one fixture outside the duelist card.
func update_layout() -> Dictionary:
	stat_hit_rects.clear()
	var far_side: bool = _player_index != _viewer
	var middle_x: float = duelist_bounds.get_center().x
	var tracker_y: float = card_bounds.position.y - 184.0 if far_side else card_bounds.end.y + 24.0 + NEAR_DROP
	var tracker: Rect2 = Rect2(Vector2(middle_x - TRACKER_SIZE.x * 0.5, tracker_y), TRACKER_SIZE)
	# The far seat's status lines sit past its standing plate, clear of the table it hides.
	var first_row: float = tracker_y - 48.0 - flag_clearance if far_side else tracker.end.y + 48.0
	var text_width: float = 690.0
	stat_hit_rects.append(tracker)
	if far_side:
		stat_hit_rects.append(Rect2(tracker.position + Vector2(-205, 0), Vector2(185, 160)))
	if _show_lives:
		stat_hit_rects.append(_lives_tab(tracker))
	var flag_rows: int = 2 if _seal_sets.is_empty() else 1
	if not _seal_sets.is_empty():
		stat_hit_rects.append(Rect2(middle_x - text_width * 0.5, first_row - 34, text_width, 42))
	var lines: PackedStringArray = _wrap_flags(text_width, 34)
	for i in range(mini(lines.size(), flag_rows)):
		stat_hit_rects.append(Rect2(middle_x - text_width * 0.5, first_row + (i + 2 - flag_rows) * 36.0 - 34, text_width, 42))
	return {"tracker": tracker, "flags": first_row, "middle": middle_x}


func _draw() -> void:
	if not _initialized:
		return
	if part == Part.PLATE:
		var plate: Rect2 = Rect2(PLATE_PAD, TRACKER_SIZE)
		_draw_tracker(plate)
		if _show_lives:
			_draw_lives(plate)
		return
	draw_set_transform(size * 0.5)
	var layout: Dictionary = update_layout()
	var tracker: Rect2 = layout["tracker"]
	var middle_x: float = float(layout["middle"])
	var first_row: float = float(layout["flags"])
	var text_width: float = 690.0
	if _player_index != _viewer:
		_draw_opponent_hand(tracker.position + Vector2(-205, 0))
	if part == Part.ALL:
		_draw_tracker(tracker)
		if _show_lives:
			_draw_lives(tracker)
	# The Aspect, printed on the felt just under the duelist card on the viewer's side.
	_text("ASPECT %d" % _aspect, Vector2(duelist_bounds.get_center().x - 110.0, duelist_bounds.end.y + ASPECT_GAP), 220, 30, IVORY, true)
	var lines: PackedStringArray = _wrap_flags(text_width, 34)
	var flag_rows: int = 2 if _seal_sets.is_empty() else 1
	if not _seal_sets.is_empty():
		_draw_seals(first_row, middle_x, text_width)
	for i in range(mini(lines.size(), flag_rows)):
		var value: String = lines[i]
		if i == flag_rows - 1 and lines.size() > flag_rows:
			value = "%s · +%d more" % [lines[i].left(26), lines.size() - flag_rows]
		_text(value, Vector2(middle_x - text_width * 0.5, first_row + (i + 2 - flag_rows) * 36.0), text_width, 34, FERVOR, true)


## The stat tracker: name, Aspect and seat along the top, then Energy, Might and Fervor. A
## Kenney inner-rule plate in the seat's colour, muted like the rest of the trim; a change
## brightens the rule for a moment.
func _draw_tracker(tracker: Rect2) -> void:
	var origin: Vector2 = tracker.position
	var rule: Color = MapArt.muted(_accent).lerp(Color.WHITE, 0.3 + _flash * 0.4)
	draw_rect(tracker.grow(-4), INK)
	draw_style_box(MapArt.panel_box(0, rule), tracker)
	# The fighter's name centred along the top; the Aspect is printed under the card instead.
	_text(_title, origin + Vector2(110, 31), 320, 25, TEXT, true)
	_text(_control, origin + Vector2(424, 31), 106, 20, MapArt.muted(_accent).lerp(Color.WHITE, 0.45), true)
	if _active:
		# The seat taking the turn: a short bar under its name, not a glowing jewel.
		draw_rect(Rect2(origin + Vector2(234, 38), Vector2(72, 3)), IVORY)
	for x in [180.0, 360.0]:
		draw_line(origin + Vector2(x, 48), origin + Vector2(x, 140), Color(MUTED, 0.25), 1, true)
	_text("ENERGY", origin + Vector2(10, 65), 160, 34, ENERGY, true)
	_text("MIGHT", origin + Vector2(190, 65), 160, 34, TEXT, true)
	_text("FERVOR", origin + Vector2(370, 65), 160, 34, FERVOR, true)
	_text("%d / 10" % _energy, origin + Vector2(10, 111), 160, 42, _stat_color(energy_delta()), true)
	_text(CardText.short_number(_might), origin + Vector2(190, 111), 160, 44, _stat_color(might_delta()), true)
	# Might has no printed maximum on the strip, so a moved ladder says what it moved from.
	if might_delta() != 0:
		_text("base %s" % CardText.short_number(_might_printed), origin + Vector2(190, 139), 160, 20, MUTED, true)
	_text("%d / %d" % [_fervor, _threshold], origin + Vector2(370, 111), 160, 40, TEXT, true)
	for i in range(10):
		var on: bool = i < _energy
		var ghost: bool = on and i >= _energy - preview_cost
		var segment: Rect2 = Rect2(origin + Vector2(18 + 15 * i, 126), Vector2(11, 10))
		if ghost:
			draw_rect(segment, ENERGY, false, 2)
		else:
			draw_rect(segment, ENERGY if on else Color(ENERGY, 0.18))
	# Fervor pips match the Energy segments: square, filled when earned.
	var step: float = minf(24.0, 150.0 / float(_threshold))
	var pip: float = minf(12.0, step - 4.0)
	var pip_start: float = origin.x + 450.0 - step * (_threshold - 1) * 0.5
	for i in range(_threshold):
		var box: Rect2 = Rect2(Vector2(pip_start + step * i - pip * 0.5, origin.y + 131 - pip * 0.5), Vector2(pip, pip))
		if i < _fervor:
			draw_rect(box, FERVOR)
		else:
			draw_rect(box, Color(MUTED, 0.45), false, 1.5)


## Above the printed baseline the number is green, below it warns, at it stays plain. The colour
## is the state display, the way a power/toughness box is in Arena.
func _stat_color(delta: int) -> Color:
	if delta > 0:
		return ENERGY
	if delta < 0:
		return ZenithTheme.WARN
	return TEXT


func energy_value() -> int:
	return _energy


func might_value() -> int:
	return _might


func energy_delta() -> int:
	return _energy - _energy_printed


func might_delta() -> int:
	return _might - _might_printed


func status_text() -> String:
	var lines: PackedStringArray = PackedStringArray([_title, _control, _piles])
	if _show_lives:
		var left: int = _lives - _lives_lost
		lines.append("Lives: %d of %d left" % [left, _lives])
	if _player_index != _viewer:
		lines.append("Hand %d" % _hand)
	for set_id in _seal_sets:
		var held: Array = _seal_sets[set_id]
		lines.append("%s Seals: %d / %d" % [str(set_id).capitalize(), held.size(), DuelEngine.SEALS_PER_SET])
	lines.append_array(_flags)
	return "\n".join(lines)


## The other online player is reading one of their hand cards: its slot in their hand (their
## left to right), or -1. The matching back in the fan rises and tips. Only the slot is known.
func set_peek(slot: int) -> void:
	if slot == _peek_target:
		return
	_peek_target = slot
	if slot >= 0:
		_peek_slot = slot
	if _peek_tween != null:
		_peek_tween.kill()
	var target: float = 1.0 if slot >= 0 else 0.0
	if reduced_motion:
		_set_peek_amount(target)
		_peek_slot = slot
		return
	_peek_tween = create_tween()
	_peek_tween.tween_method(_set_peek_amount, _peek, target, 0.14)
	if slot < 0:
		_peek_tween.tween_callback(func() -> void: _peek_slot = -1)


func _set_peek_amount(value: float) -> void:
	_peek = value
	request_redraw()


## Where the back for hand `slot` sits in the fan, relative to the canvas centre, or null when
## the fan is not drawn.
func peek_point(slot: int) -> Variant:
	if _player_index == _viewer or _hand <= 0:
		return null
	var layout: Dictionary = update_layout()
	var origin: Vector2 = (layout["tracker"] as Rect2).position + Vector2(-205, 0)
	var shown: int = mini(_hand, 7)
	var offset: float = _fan_index(slot, shown) - (shown - 1) * 0.5
	return origin + Vector2(102 + offset * 18, 56 + absf(offset) * 3 - PEEK_RISE)


## The fan faces the viewer, so the owner's leftmost card is drawn on the viewer's right. Slots
## past the seven drawn backs land on the last one.
func _fan_index(slot: int, shown: int) -> int:
	return shown - 1 - clampi(slot, 0, shown - 1)


## Only the public count is used; card faces and identities never enter this display.
func _draw_opponent_hand(origin: Vector2) -> void:
	var shown: int = mini(_hand, 7)
	var peeked: int = _fan_index(_peek_slot, shown) if _peek_slot >= 0 and shown > 0 else -1
	var order: Array[int] = []
	for i in range(shown):
		if i != peeked:
			order.append(i)
	if peeked >= 0:
		order.append(peeked)   # the raised back is drawn over its neighbours
	for i in order:
		var offset: float = i - (shown - 1) * 0.5
		var lift: float = _peek if i == peeked else 0.0
		var center: Vector2 = origin + Vector2(102 + offset * 18, 56 + absf(offset) * 3 - PEEK_RISE * lift)
		draw_set_transform(size * 0.5 + center, offset * 0.09 + PEEK_TIP * lift * (1.0 if offset >= 0.0 else -1.0))
		var back: Rect2 = Rect2(-27, -38, 54, 76)
		var rule: Color = MapArt.muted(_accent).lerp(Color.WHITE, 0.3 + 0.4 * lift)
		draw_rect(back, INK)
		draw_rect(back, rule, false, 2.5 + 2.0 * lift)
		draw_rect(back.grow(-6), Color(rule, 0.45 + 0.4 * lift), false, 1.5)
		draw_rect(Rect2(-5, -5, 10, 10), Color(rule, 0.5 + 0.4 * lift))
	draw_set_transform(size * 0.5)
	if shown == 0:
		_text("EMPTY", origin + Vector2(0, 69), 205, 27, MUTED, true)
	_text(str(_hand), origin + Vector2(0, 132), 205, 42, TEXT, true)
	_text("IN HAND", origin + Vector2(0, 160), 205, 23, MUTED, true)


func _draw_seals(baseline: float, middle_x: float = 0.0, width: float = 690.0) -> void:
	var set_ids: Array = _seal_sets.keys()
	set_ids.sort()
	# Each set gets its own count. Never add unrelated sets into one victory track.
	if set_ids.size() > 1:
		var parts: PackedStringArray = PackedStringArray()
		for set_id in set_ids:
			var held: Array = _seal_sets[set_id]
			parts.append("%s %d/%d" % [str(set_id).capitalize(), held.size(), DuelEngine.SEALS_PER_SET])
		_text("Seals: " + " · ".join(parts), Vector2(middle_x - width * 0.5, baseline), width, 27, IVORY, true)
		return
	var set_id: String = str(set_ids[0])
	var held: Array = _seal_sets[set_id]
	var ratio: float = width / 690.0
	_text("%s Seals %d/%d" % [set_id.capitalize(), held.size(), DuelEngine.SEALS_PER_SET], Vector2(middle_x - width * 0.5, baseline), 350 * ratio, 27, IVORY)
	for i in range(DuelEngine.SEALS_PER_SET):
		var center: Vector2 = Vector2(middle_x + (34 + i * 36) * ratio, baseline - 12)
		var box: Rect2 = Rect2(center - Vector2(9, 9), Vector2(18, 18))
		if held.has(i + 1):
			draw_rect(box, IVORY)
		else:
			draw_rect(box, INK)
			draw_rect(box, Color(IVORY, 0.45), false, 2.0)


## The lives tab straddles the crest's bottom border, centred: under the Might column for the
## near seat, and in the gap above the duelist card for the far one.
func _lives_tab(tracker: Rect2) -> Rect2:
	var width: float = 104.0 + 32.0 * float(_lives)
	return Rect2(tracker.get_center().x - width * 0.5, tracker.end.y - 12.0, width, 26.0)


func _draw_lives(tracker: Rect2) -> void:
	var tab: Rect2 = _lives_tab(tracker)
	draw_rect(tab, INK)
	draw_rect(tab, MapArt.muted(_accent).lerp(Color.WHITE, 0.3 + _flash * 0.4), false, 2.0)
	_text("LIVES", tab.position + Vector2(10, 21), 80, 22, MUTED, false)
	for i in range(_lives):
		var left: bool = i < _lives - _lives_lost
		_heart(Vector2(tab.position.x + 96.0 + 32.0 * i, tab.get_center().y), 9.5, LIFE_RED if left else INK, LIFE_RED if left else Color(MUTED, 0.5))


## A small heart: two lobes and a point, filled or hollow.
func _heart(center: Vector2, r: float, fill: Color, edge: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for k in range(25):
		var t: float = TAU * float(k) / 24.0
		# The classic heart curve, scaled to `r` and flipped so the point is at the bottom.
		var x: float = 16.0 * pow(sin(t), 3)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		points.append(center + Vector2(x, -y) * (r / 16.0))
	draw_colored_polygon(points, fill)
	draw_polyline(points, edge, 2.0, true)


func _text(value: String, origin: Vector2, width: float, font_size: int, color: Color, centered: bool = false) -> void:
	var fitted: String = value
	while fitted.length() > 1 and _font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		fitted = fitted.left(fitted.length() - 2) + "…"
	var x: float = origin.x
	if centered:
		x += (width - _font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) * 0.5
	draw_string_outline(_font, Vector2(x, origin.y), fitted, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, 5, INK)
	draw_string(_font, Vector2(x, origin.y), fitted, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)


func _wrap_flags(width: float, font_size: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var line: String = ""
	for flag in _flags:
		var candidate: String = flag if line.is_empty() else line + " · " + flag
		if not line.is_empty() and _font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			lines.append(line)
			line = flag
		else:
			line = candidate
	if not line.is_empty():
		lines.append(line)
	return lines


func request_redraw() -> void:
	queue_redraw()
	redraw_requested.emit()
