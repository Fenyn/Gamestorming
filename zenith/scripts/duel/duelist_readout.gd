class_name DuelistReadout
extends Control
## Transparent resource ornaments surrounding the actual duelist card in the scene.

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
		card_bounds = value
		update_layout()
		queue_redraw()
var stat_hit_rects: Array[Rect2] = []
var _life: int = 0
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
	var hand: int = int(counts[1]) if counts.size() > 1 else p.hand.size()
	var discard: int = int(counts[2]) if counts.size() > 2 else p.discard.size()
	var removed: int = int(counts[3]) if counts.size() > 3 else p.removed.size()
	_piles = "Hand %d   Discard %d" % [hand, discard]
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
	_flags.clear()
	if p.must_pass:
		_flags.append("Must pass")
	if p.skip_next_attack_phase:
		_flags.append("Skips next attack")
	if p.energy_blocked:
		_flags.append("Cannot gain Energy")
	if p.fervor_shield:
		_flags.append("Fervor shielded")
	if p.aspect_shield:
		_flags.append("Aspect shielded")
	if p.no_ascension_win:
		_flags.append("Cannot win by Ascension")
	if p.fervor_gain > 1:
		_flags.append("Fervor gain x%d" % p.fervor_gain)
	if p.seal_victory_pending:
		_flags.append("Seal victory pending")
	for restriction in p.restrictions:
		_flags.append(CardText.restriction_name(restriction))
	if _initialized and same_identity and old_values != [_life, _energy, _fervor, _aspect] and not reduced_motion:
		if _tween != null:
			_tween.kill()
		_flash = 1.0
		_tween = create_tween()
		_tween.tween_method(_set_flash, 1.0, 0.0, 0.55)
	_initialized = true
	update_layout()
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


## Pure layout calculation also updates picking bounds without requiring a render frame.
func update_layout() -> Dictionary:
	stat_hit_rects.clear()
	# Every ornament follows the actual projected edges, including during camera zoom.
	var top: float = card_bounds.position.y
	var left_x: float = card_bounds.position.x - 160.0
	var right_x: float = card_bounds.end.x + 160.0
	var title_y: float = top - 88.0
	var control_y: float = top - 45.0
	var middle_y: float = card_bounds.get_center().y
	var center: Vector2 = Vector2(left_x, middle_y - 10.0)
	var might_center: Vector2 = Vector2(right_x, middle_y - 20.0)
	var aspect_y: float = center.y + 119.0
	var fervor_y: float = might_center.y + 92.0
	var rune_y: float = fervor_y + 26.0
	var stats_bottom: float = maxf(card_bounds.end.y, maxf(aspect_y, rune_y + 10.0))
	var far_side: bool = _player_index != _viewer
	var piles_y: float = title_y - 68.0 if far_side else stats_bottom + 68.0
	var first_row: float = piles_y - 92.0 if far_side else piles_y + 44.0
	stat_hit_rects.append(Rect2(-350, title_y - 44, 700, 87))
	stat_hit_rects.append(Rect2(left_x - 115, center.y - 143, 230, aspect_y - center.y + 151))
	stat_hit_rects.append(Rect2(right_x - 115, might_center.y - 60, 230, rune_y - might_center.y + 80))
	stat_hit_rects.append(Rect2(-345, piles_y - 32, 690, 38))
	var flag_rows: int = 2 if _seal_sets.is_empty() else 1
	if not _seal_sets.is_empty():
		stat_hit_rects.append(Rect2(-345, first_row - 28, 690, 34))
	var lines: PackedStringArray = _wrap_flags(690, 30)
	for i in range(mini(lines.size(), flag_rows)):
		stat_hit_rects.append(Rect2(-345, first_row + (i + 2 - flag_rows) * 36.0 - 28, 690, 34))
	return {"top": top, "left": left_x, "right": right_x, "title": title_y,
		"control": control_y, "energy": center, "might": might_center,
		"aspect": aspect_y, "fervor": fervor_y, "runes": rune_y, "piles": piles_y, "flags": first_row}


func _draw() -> void:
	if not _initialized:
		return
	draw_set_transform(Vector2(800, 800))
	var layout: Dictionary = update_layout()
	var top: float = float(layout["top"])
	var left_x: float = float(layout["left"])
	var right_x: float = float(layout["right"])
	var center: Vector2 = layout["energy"]
	var might_center: Vector2 = layout["might"]
	var aspect_y: float = float(layout["aspect"])
	var fervor_y: float = float(layout["fervor"])
	var rune_y: float = float(layout["runes"])
	var piles_y: float = float(layout["piles"])
	var first_row: float = float(layout["flags"])
	_text(_title, Vector2(-350, float(layout["title"])), 700, 42, TEXT, true)
	_text(_control, Vector2(-350, float(layout["control"])), 700, 32, _accent, true)
	if _flash > 0:
		draw_arc(center, 85 + 9 * (1.0 - _flash), deg_to_rad(135), deg_to_rad(405), 48, Color(ENERGY, _flash * 0.7), 4, true)
	for i in range(10):
		var start: float = deg_to_rad(135 + i * 27)
		var on: bool = i < _energy
		var ghost: bool = on and i >= _energy - preview_cost
		var color: Color = ENERGY if on else Color(0.12, 0.23, 0.29)
		draw_arc(center, 79, start, start + deg_to_rad(21), 10, color, 9 if not ghost else 2, true)
	_text("ENERGY", Vector2(left_x - 95, center.y - 110), 190, 36, ENERGY, true)
	_text(str(_energy), center + Vector2(-65, 9), 130, 64, TEXT, true)
	_text("/ 10", center + Vector2(-60, 43), 120, 32, MUTED, true)
	_diamond(might_center, Vector2(101, 50), INK, _accent)
	_text("MIGHT", might_center + Vector2(-91, -13), 182, 32, _accent, true)
	_text(CardText.short_number(_might), might_center + Vector2(-99, 31), 198, 48, TEXT, true)
	_text("ASPECT %d" % _aspect, Vector2(left_x - 110, aspect_y), 220, 32, GOLD, true)
	_text("FERVOR %d / %d" % [_fervor, _threshold], Vector2(right_x - 115, fervor_y), 230, 30, MUTED, true)
	var rune_count: int = _threshold
	var step: float = minf(28.0, 200.0 / float(rune_count))
	var rune_start: float = right_x - step * (rune_count - 1) * 0.5
	for i in range(rune_count):
		_diamond(Vector2(rune_start + step * i, rune_y), Vector2(minf(8, step * 0.3), 9), FERVOR if i < _fervor else INK, FERVOR.darkened(0.2) if i < _fervor else MUTED.darkened(0.55))
	_text(_piles, Vector2(-343, piles_y), 686, 27, MUTED, true)
	# Preserve the full standing text through status_text() for an anchored hover readout.
	var lines: PackedStringArray = _wrap_flags(690, 30)
	var flag_rows: int = 2 if _seal_sets.is_empty() else 1
	if not _seal_sets.is_empty():
		_draw_seals(first_row)
	for i in range(mini(lines.size(), flag_rows)):
		var value: String = lines[i]
		if i == flag_rows - 1 and lines.size() > flag_rows:
			value = "%s · +%d more" % [lines[i].left(26), lines.size() - flag_rows]
		var row_y: float = first_row + (i + 2 - flag_rows) * 36.0
		_text(value, Vector2(-345, row_y), 690, 27, FERVOR, true)
	if _active:
		_diamond(Vector2(0, top - 20), Vector2(6, 6), GOLD, GOLD)


func status_text() -> String:
	var lines: PackedStringArray = PackedStringArray([_title, _control, _piles])
	for set_id in _seal_sets:
		var held: Array = _seal_sets[set_id]
		lines.append("%s Seals: %d / %d" % [str(set_id).capitalize(), held.size(), DuelEngine.SEALS_PER_SET])
	lines.append_array(_flags)
	return "\n".join(lines)


func _draw_seals(baseline: float) -> void:
	var set_ids: Array = _seal_sets.keys()
	set_ids.sort()
	# Each set gets its own count. Never add unrelated sets into one victory track.
	if set_ids.size() > 1:
		var parts: PackedStringArray = PackedStringArray()
		for set_id in set_ids:
			var held: Array = _seal_sets[set_id]
			parts.append("%s %d/%d" % [str(set_id).capitalize(), held.size(), DuelEngine.SEALS_PER_SET])
		_text("Seals: " + " · ".join(parts), Vector2(-345, baseline), 690, 27, GOLD, true)
		return
	var set_id: String = str(set_ids[0])
	var held: Array = _seal_sets[set_id]
	_text("%s Seals %d/%d" % [set_id.capitalize(), held.size(), DuelEngine.SEALS_PER_SET], Vector2(-345, baseline), 350, 27, GOLD)
	for i in range(DuelEngine.SEALS_PER_SET):
		var center: Vector2 = Vector2(34 + i * 36, baseline - 12)
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
