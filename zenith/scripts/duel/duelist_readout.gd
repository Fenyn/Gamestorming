class_name DuelistReadout
extends Control
## Transparent resource ornaments surrounding the actual duelist card in the scene.

signal redraw_requested

const PLAYER_STATUS: Script = preload("res://scripts/duel/player_status.gd")
const INK: Color = Color(0.025, 0.038, 0.065, 0.97)
const TEXT: Color = Color(0.96, 0.94, 0.86)
const MUTED: Color = Color(0.68, 0.74, 0.79)
const GOLD: Color = Color(0.97, 0.76, 0.39)
const ENERGY: Color = ZenithTheme.ENERGY
const FERVOR: Color = Color(0.95, 0.59, 0.29)
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
var _might: int = 0
var _fervor: int = 0
var _threshold: int = 5
var _aspect: int = 1
var _title: String = ""
var _control: String = ""
var _piles: String = ""
var _flags: PackedStringArray = PackedStringArray()
var _seal_sets: Dictionary = {}
var _reserve: int = 0
var _accent: Color = GOLD
var _active: bool = false
var _initialized: bool = false
var _player_index: int = -1
var _viewer: int = -1
var _duelist_uid: int = -1
var _flash: float = 0.0
var _tween: Tween
var _font: Font = ThemeDB.fallback_font


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
	_fervor = int(fervors[player_index]) if fervors.size() > player_index else p.fervor
	_threshold = maxi(1, p.fervor_needed)
	_aspect = int(aspects.get(duelist.uid, aspects.get(str(duelist.uid), duelist.aspect)))
	_title = duelist.title
	_control = "YOU" if player_index == viewer else "OPPONENT"
	if controller.uid != duelist.uid:
		_control = "%s IN CONTROL" % controller.title
	_accent = Palette.school_ui(p.style)
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


## All combat resources share one fixture outside both the duelist and Life Deck.
func update_layout() -> Dictionary:
	stat_hit_rects.clear()
	var far_side: bool = _player_index != _viewer
	var middle_x: float = duelist_bounds.get_center().x
	var tracker_y: float = card_bounds.position.y - 184.0 if far_side else card_bounds.end.y + 24.0
	var tracker: Rect2 = Rect2(middle_x - 270.0, tracker_y, 540.0, 160.0)
	var title_y: float = tracker_y - 78.0 if far_side else minf(duelist_bounds.position.y, card_bounds.position.y) - 88.0
	var piles_y: float = title_y - 56.0 if far_side else tracker.end.y + 46.0
	var first_row: float = piles_y - 84.0 if far_side else piles_y + 40.0
	var text_width: float = 690.0
	stat_hit_rects.append(tracker)
	if far_side:
		stat_hit_rects.append(Rect2(tracker.position + Vector2(-225, 0), Vector2(205, 160)))
	stat_hit_rects.append(Rect2(middle_x - text_width * 0.5, title_y - 44, text_width, 84))
	stat_hit_rects.append(Rect2(middle_x - text_width * 0.5, piles_y - 29, text_width, 34))
	var flag_rows: int = 2 if _seal_sets.is_empty() else 1
	if not _seal_sets.is_empty():
		stat_hit_rects.append(Rect2(middle_x - text_width * 0.5, first_row - 28, text_width, 34))
	var lines: PackedStringArray = _wrap_flags(text_width, 27)
	for i in range(mini(lines.size(), flag_rows)):
		stat_hit_rects.append(Rect2(middle_x - text_width * 0.5, first_row + (i + 2 - flag_rows) * 36.0 - 28, text_width, 34))
	return {"tracker": tracker, "title": title_y, "control": title_y + 42.0,
		"piles": piles_y, "flags": first_row, "middle": middle_x}


func _draw() -> void:
	if not _initialized:
		return
	draw_set_transform(size * 0.5)
	var layout: Dictionary = update_layout()
	var tracker: Rect2 = layout["tracker"]
	var origin: Vector2 = tracker.position
	var middle_x: float = float(layout["middle"])
	var first_row: float = float(layout["flags"])
	var text_width: float = 690.0
	if _player_index != _viewer:
		_draw_opponent_hand(origin + Vector2(-225, 0))
	_text(_title, Vector2(middle_x - text_width * 0.5, float(layout["title"])), text_width, 42, TEXT, true)
	_text(_control, Vector2(middle_x - text_width * 0.5, float(layout["control"])), text_width, 32, _accent, true)
	var corners: PackedVector2Array = PackedVector2Array([
		origin + Vector2(18, 0), origin + Vector2(522, 0),
		origin + Vector2(540, 18), origin + Vector2(540, 142),
		origin + Vector2(522, 160), origin + Vector2(18, 160),
		origin + Vector2(0, 142), origin + Vector2(0, 18)])
	draw_colored_polygon(corners, INK)
	corners.append(corners[0])
	draw_polyline(corners, _accent.lightened(_flash * 0.25), 2.0 + _flash * 2.0, true)
	_text("ASPECT %d" % _aspect, origin + Vector2(180, 27), 180, 25, GOLD, true)
	if _active:
		_diamond(origin + Vector2(174, 18), Vector2(4, 4), GOLD, GOLD)
	for x in [180.0, 360.0]:
		draw_line(origin + Vector2(x, 44), origin + Vector2(x, 142), Color(MUTED, 0.22), 1, true)
	_text("ENERGY", origin + Vector2(10, 61), 160, 25, ENERGY, true)
	_text("MIGHT", origin + Vector2(190, 61), 160, 25, TEXT, true)
	_text("FERVOR", origin + Vector2(370, 61), 160, 25, FERVOR, true)
	_text("%d / 10" % _energy, origin + Vector2(10, 109), 160, 40, TEXT, true)
	_text(CardText.short_number(_might), origin + Vector2(190, 109), 160, 44, TEXT, true)
	_text("%d / %d" % [_fervor, _threshold], origin + Vector2(370, 109), 160, 40, TEXT, true)
	for i in range(10):
		var on: bool = i < _energy
		var ghost: bool = on and i >= _energy - preview_cost
		var segment: Rect2 = Rect2(origin + Vector2(16 + 15 * i, 128), Vector2(11, 10))
		if ghost:
			draw_rect(segment, ENERGY, false, 2)
		else:
			draw_rect(segment, ENERGY if on else Color(ENERGY, 0.18))
	var step: float = minf(24.0, 150.0 / float(_threshold))
	var rune_start: float = origin.x + 450.0 - step * (_threshold - 1) * 0.5
	for i in range(_threshold):
		_diamond(Vector2(rune_start + step * i, origin.y + 133), Vector2(minf(7, step * 0.3), 8), FERVOR if i < _fervor else INK, FERVOR if i < _fervor else Color(MUTED, 0.4))
	_text(_piles, Vector2(middle_x - text_width * 0.5, float(layout["piles"])), text_width, 27, MUTED, true)
	var lines: PackedStringArray = _wrap_flags(text_width, 27)
	var flag_rows: int = 2 if _seal_sets.is_empty() else 1
	if not _seal_sets.is_empty():
		_draw_seals(first_row, middle_x, text_width)
	for i in range(mini(lines.size(), flag_rows)):
		var value: String = lines[i]
		if i == flag_rows - 1 and lines.size() > flag_rows:
			value = "%s · +%d more" % [lines[i].left(26), lines.size() - flag_rows]
		_text(value, Vector2(middle_x - text_width * 0.5, first_row + (i + 2 - flag_rows) * 36.0), text_width, 27, FERVOR, true)


func status_text() -> String:
	var lines: PackedStringArray = PackedStringArray([_title, _control, _piles])
	if _player_index != _viewer:
		lines.append("Hand %d" % _hand)
	for set_id in _seal_sets:
		var held: Array = _seal_sets[set_id]
		lines.append("%s Seals: %d / %d" % [str(set_id).capitalize(), held.size(), DuelEngine.SEALS_PER_SET])
	lines.append_array(_flags)
	return "\n".join(lines)


## Only the public count is used; card faces and identities never enter this display.
func _draw_opponent_hand(origin: Vector2) -> void:
	var shown: int = mini(_hand, 7)
	for i in range(shown):
		var offset: float = i - (shown - 1) * 0.5
		var center: Vector2 = origin + Vector2(102 + offset * 18, 56 + absf(offset) * 3)
		draw_set_transform(size * 0.5 + center, offset * 0.09)
		var back: Rect2 = Rect2(-27, -38, 54, 76)
		draw_rect(back, INK)
		draw_rect(back, _accent, false, 2.5)
		draw_rect(back.grow(-6), Color(_accent, 0.35), false, 1.5)
		_diamond(Vector2.ZERO, Vector2(9, 13), Color(_accent, 0.2), _accent)
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
		_text("Seals: " + " · ".join(parts), Vector2(middle_x - width * 0.5, baseline), width, 27, GOLD, true)
		return
	var set_id: String = str(set_ids[0])
	var held: Array = _seal_sets[set_id]
	var ratio: float = width / 690.0
	_text("%s Seals %d/%d" % [set_id.capitalize(), held.size(), DuelEngine.SEALS_PER_SET], Vector2(middle_x - width * 0.5, baseline), 350 * ratio, 27, GOLD)
	for i in range(DuelEngine.SEALS_PER_SET):
		var center: Vector2 = Vector2(middle_x + (34 + i * 36) * ratio, baseline - 12)
		var filled: bool = held.has(i + 1)
		_diamond(center, Vector2(10, 11), GOLD if filled else INK, GOLD if filled else GOLD.darkened(0.55))


func _diamond(center: Vector2, extent: Vector2, fill: Color, edge: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([center + Vector2(0, -extent.y), center + Vector2(extent.x, 0), center + Vector2(0, extent.y), center + Vector2(-extent.x, 0)])
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, edge, 2.5, true)


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
