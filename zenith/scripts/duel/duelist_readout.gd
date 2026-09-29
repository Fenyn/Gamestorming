class_name DuelistReadout
extends Control
## What prints on the board around the duelist card (`DuelistDisplay`): the Aspect past the
## card's outer edge (with the lives in a duel played to more than one point), the rival's hand
## fan, the Seal sets and the status chips, and online the rival's tab. The canvas lies on the
## table centred on the card. Energy, Might and Fervor are on the card itself (`StatusMarkers`).

signal redraw_requested

const PLAYER_STATUS: Script = preload("res://scripts/duel/player_status.gd")
const INK: Color = Color(0.085, 0.08, 0.075, 0.96)
const TEXT: Color = ZenithTheme.TEXT
const MUTED: Color = ZenithTheme.TEXT_SOFT
const IVORY: Color = ZenithTheme.ACCENT
const STATUS: Color = ZenithTheme.WARN
## Baseline of the Aspect caption past the duelist card's outer edge, in canvas pixels. Clear of
## the Fervor and control tabs that reach past the card's edges.
const ASPECT_GAP: float = 46.0
const CAPTION_WIDTH: float = 220.0
const CAPTION_FONT: int = 30
## The width the status spot's chips run across, from its left end.
const STATUS_WIDTH: float = 540.0
## Status lines print in three rows along the seat's Ally row, or in two at the status spot while
## an Ally holds the row.
const FLAG_ROWS_HOME: int = 3
const FLAG_ROWS_BESIDE: int = 2
## The rival's hand fan, at the status spot's left end, the status lines beside it.
const FAN_SIZE: Vector2 = Vector2(205, 190)
const FAN_GAP: float = 16.0
## Status flags are chips, one row step apart.
const CHIP_FONT: int = 32
const CHIP_PAD: float = 12.0
const CHIP_GAP: float = 10.0
const LIFE_RED: Color = Color(0.93, 0.36, 0.36)
const HEART_STEP: float = 32.0
## Online, the rival's tab past their Aspect caption. BANK reads "Time bank 0:48" while they spend
## their bank, AWAY "Disconnected 1:16" while their connection is down; NONE, while they decide on
## their timer or not at all, draws nothing, since the decision panel already says it waits on
## them. Fixed size and type, whatever the name.
enum Tab { NONE, BANK, AWAY }
const TAB_SIZE: Vector2 = Vector2(440, 54)
const TAB_FONT: int = 44
const TAB_GAP: float = 10.0

var reduced_motion: bool = false
## Projected front-face bounds, in texture pixels relative to the card's world anchor.
var card_bounds: Rect2 = Rect2(-80, -90, 160, 180):
	set(value):
		if card_bounds.is_equal_approx(value):
			return
		card_bounds = value
		update_layout()
		request_redraw()
var stat_hit_rects: Array[Rect2] = []
## The seat's status spot under its Seals, in canvas pixels, from the table's StatusHome marker.
var status_home: Vector2 = Vector2.ZERO:
	set(value):
		if status_home.is_equal_approx(value):
			return
		status_home = value
		update_layout()
		request_redraw()
## The seat's Ally row in canvas pixels (left edge, row centre line, width; height unused). While
## the seat has no Ally in play the status chips and Seal sets print there, out of the way; with
## an Ally in the row they fall back to the status spot. Zero width until the display sets it.
var flag_home: Rect2 = Rect2():
	set(value):
		if flag_home.is_equal_approx(value):
			return
		flag_home = value
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
var _might: int = 0
var _aspect: int = 1
var _title: String = ""
var _control: String = ""
var _piles: String = ""
var _flags: PackedStringArray = PackedStringArray()
var _seal_sets: Dictionary = {}
var _has_allies: bool = false
var _reserve: int = 0
var _lives: int = 1          # how many points the rival needs against this seat
var _lives_lost: int = 0     # how many of them the rival has scored
var _show_lives: bool = false  # only when either side has more than one (adventure duels)
var _tab: Tab = Tab.NONE
var _tab_text: String = ""
var _tab_warn: bool = false
var _accent: Color = IVORY
var _initialized: bool = false
var _player_index: int = -1
var _viewer: int = -1
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
	_player_index = player_index
	_viewer = viewer
	var energies: Dictionary = live.get("energy", {})
	var mights: Dictionary = live.get("might", {})
	var aspects: Dictionary = live.get("aspect", {})
	var zones: Array = live.get("zones", [])
	var counts: Array = zones[player_index] if zones.size() > player_index else []
	_life = int(counts[0]) if counts.size() > 0 else p.life_deck.size()
	_energy = int(energies.get(controller.uid, energies.get(str(controller.uid), controller.energy)))
	_might = int(mights.get(controller.uid, mights.get(str(controller.uid), controller.might)))
	_aspect = int(aspects.get(duelist.uid, aspects.get(str(duelist.uid), duelist.aspect)))
	_title = duelist.title
	_control = "YOU" if player_index == viewer else "OPPONENT"
	if controller.uid != duelist.uid:
		_control = "%s IN CONTROL" % controller.title
	_accent = SeatColors.accent(view, player_index, Session.color_seed)
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
	_has_allies = not p.allies.is_empty()
	# Lives: a seat falls when the rival scores `points_to_win[rival]` points against it.
	var rival: int = 1 - player_index
	_lives = maxi(1, int(view.points_to_win[rival])) if view.points_to_win.size() == 2 else 1
	_lives_lost = clampi(int(view.points[rival]), 0, _lives) if view.points.size() == 2 else 0
	_show_lives = view.points_to_win.size() == 2 and (int(view.points_to_win[0]) > 1 or int(view.points_to_win[1]) > 1)
	_initialized = true
	update_layout()
	request_redraw()


## Everything printed around the card, and the click regions it covers.
func update_layout() -> Dictionary:
	stat_hit_rects.clear()
	var far_side: bool = _player_index != _viewer
	var text_width: float = STATUS_WIDTH
	var flag_left: float = status_home.x - STATUS_WIDTH * 0.5
	# The block of lines at the status spot is centred on it.
	var first_row: float = status_home.y - _chip_step() * float(FLAG_ROWS_BESIDE - 1) * 0.5 + _chip_font() * 0.35
	if far_side:
		text_width -= FAN_SIZE.x + FAN_GAP
		flag_left += FAN_SIZE.x + FAN_GAP
	var at_home: bool = _flags_at_home()
	if at_home:
		text_width = flag_home.size.x
		flag_left = flag_home.position.x
		first_row = flag_home.position.y - _chip_step() * 0.5
	stat_hit_rects.append(caption_rect())
	if far_side:
		stat_hit_rects.append(_fan_rect())
	if _tab != Tab.NONE:
		stat_hit_rects.append(tab_rect())
	var flag_rows: int = _flag_row_count(at_home)
	if not _seal_sets.is_empty():
		stat_hit_rects.append(Rect2(flag_left, first_row - 34, text_width, 42))
	var lines: Array[PackedStringArray] = _flag_rows(text_width)
	var font: int = _chip_font()
	for i in range(mini(lines.size(), flag_rows)):
		var baseline: float = _chip_baseline(i, first_row)
		stat_hit_rects.append(Rect2(flag_left, baseline - font - 6.0, text_width, font + 20.0))
	return {"flags": first_row, "flag_left": flag_left, "flag_width": text_width, "home": at_home}


## The rival's hand fan: at the status spot's left end.
func _fan_rect() -> Rect2:
	return Rect2(Vector2(status_home.x - STATUS_WIDTH * 0.5, status_home.y - FAN_SIZE.y * 0.5), FAN_SIZE)


## The Aspect caption past the duelist card's outer edge: under the near card, over the far one,
## since the two cards meet at the centre line. The lives ride on its right when shown.
func caption_rect() -> Rect2:
	var width: float = CAPTION_WIDTH + (HEART_STEP * float(_lives) if _show_lives else 0.0)
	var baseline: float = duelist_bounds.position.y - ASPECT_GAP + 22.0 if _player_index != _viewer else duelist_bounds.end.y + ASPECT_GAP
	return Rect2(duelist_bounds.get_center().x - width * 0.5, baseline - CAPTION_FONT, width, CAPTION_FONT + 8.0)


## Everything the Ally row home can hold: the Seal line and three rows of chips.
func flag_home_area() -> Rect2:
	var step: float = _chip_step()
	return Rect2(flag_home.position.x, flag_home.position.y - step * 1.5 - 34.0, flag_home.size.x, step * (FLAG_ROWS_HOME + 1) + 40.0)


func _flags_at_home() -> bool:
	return flag_home.size.x > 0.0 and not _has_allies


## Rows of chips shown: three in the Ally row, two at the status spot, one fewer under Seal sets.
func _flag_row_count(at_home: bool) -> int:
	return (FLAG_ROWS_HOME if at_home else FLAG_ROWS_BESIDE) - (0 if _seal_sets.is_empty() else 1)


## Seal sets take the first line when there are any; the chips run on below them.
func _chip_baseline(row: int, first_row: float) -> float:
	return first_row + (row + (0 if _seal_sets.is_empty() else 1)) * _chip_step()


func _draw() -> void:
	if not _initialized:
		return
	draw_set_transform(size * 0.5)
	var layout: Dictionary = update_layout()
	var first_row: float = float(layout["flags"])
	var text_width: float = float(layout["flag_width"])
	var flag_left: float = float(layout["flag_left"])
	var centred: bool = bool(layout["home"])
	if _player_index != _viewer:
		_draw_opponent_hand(_fan_rect().position)
	_draw_caption()
	if _tab != Tab.NONE:
		_draw_tab()
	var rows: Array[PackedStringArray] = _flag_rows(text_width)
	var flag_rows: int = _flag_row_count(bool(layout["home"]))
	if not _seal_sets.is_empty():
		_draw_seals(first_row, flag_left + text_width * 0.5, text_width)
	var hidden: int = 0
	for i in range(flag_rows, rows.size()):
		hidden += rows[i].size()
	for i in range(mini(rows.size(), flag_rows)):
		var row: PackedStringArray = rows[i].duplicate()
		if i == flag_rows - 1 and hidden > 0:
			# The last row shown gives up chips from its end until the count of the rest fits.
			var rest: int = hidden
			while row.size() > 1 and _row_width(row) + CHIP_GAP + _chip_width("+%d more" % (rest + 1)) > text_width:
				row.remove_at(row.size() - 1)
				rest += 1
			row.append("+%d more" % rest)
		_draw_chip_row(row, flag_left, _chip_baseline(i, first_row), text_width, centred)


func _draw_caption() -> void:
	var box: Rect2 = caption_rect()
	var baseline: float = box.position.y + CAPTION_FONT
	_text("ASPECT %d" % _aspect, Vector2(box.position.x, baseline), CAPTION_WIDTH, CAPTION_FONT, IVORY, true)
	if not _show_lives:
		return
	for i in range(_lives):
		var left: bool = i < _lives - _lives_lost
		_heart(Vector2(box.position.x + CAPTION_WIDTH + HEART_STEP * (float(i) + 0.5), baseline - 11.0), 9.5, LIFE_RED if left else INK, LIFE_RED if left else Color(MUTED, 0.5))


func energy_value() -> int:
	return _energy


func might_value() -> int:
	return _might


func status_text() -> String:
	var lines: PackedStringArray = PackedStringArray([_title, _control, "Life %d" % _life, _piles])
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
	var origin: Vector2 = _fan_rect().position
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
		_text("EMPTY", origin + Vector2(0, 69), 205, 36, MUTED, true)
	_text(str(_hand), origin + Vector2(0, 146), 205, 60, TEXT, true)
	_text("IN HAND", origin + Vector2(0, 184), 205, 36, MUTED, true)


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


## The rival's tab (`Tab`): what it is, its whole line ("Time bank 0:48"), and whether it warns.
## Redraws only when one of them changes.
func set_tab(kind: Tab, text: String, warn: bool) -> void:
	var shown: String = text if kind != Tab.NONE else ""
	var warns: bool = warn and kind != Tab.NONE
	if kind == _tab and shown == _tab_text and warns == _tab_warn:
		return
	_tab = kind
	_tab_text = shown
	_tab_warn = warns
	update_layout()
	request_redraw()


func tab_kind() -> Tab:
	return _tab


func tab_text() -> String:
	return _tab_text


func tab_warns() -> bool:
	return _tab_warn


## Where the tab sits: centred on the card, past the Aspect caption on the card's outer side.
func tab_rect() -> Rect2:
	var caption: Rect2 = caption_rect()
	var y: float = caption.position.y - TAB_GAP - TAB_SIZE.y if _player_index != _viewer else caption.end.y + TAB_GAP
	return Rect2(duelist_bounds.get_center().x - TAB_SIZE.x * 0.5, y, TAB_SIZE.x, TAB_SIZE.y)


func _draw_tab() -> void:
	var box: Rect2 = tab_rect()
	var color: Color = ZenithTheme.WARN if _tab_warn else TEXT
	draw_rect(box, INK)
	draw_rect(box, ZenithTheme.WARN if _tab_warn else MapArt.muted(_accent).lerp(Color.WHITE, 0.3), false, 2.0)
	var baseline: float = box.position.y + (box.size.y + _font.get_ascent(TAB_FONT) - _font.get_descent(TAB_FONT)) * 0.5
	_text(_tab_text, Vector2(box.position.x + 12.0, baseline), box.size.x - 24.0, TAB_FONT, color, true)


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


## The status flags as rows of chips, each row no wider than `width`.
func _flag_rows(width: float) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var row: PackedStringArray = PackedStringArray()
	for flag in _flags:
		var candidate: PackedStringArray = row.duplicate()
		candidate.append(flag)
		if not row.is_empty() and _row_width(candidate) > width:
			rows.append(row)
			row = PackedStringArray([flag])
		else:
			row = candidate
	if not row.is_empty():
		rows.append(row)
	return rows


func _chip_font() -> int:
	return CHIP_FONT


func _chip_height() -> float:
	return _chip_font() + 6.0


func _chip_step() -> float:
	return _chip_height() + 2.0


func _chip_width(flag: String) -> float:
	return _font.get_string_size(flag, HORIZONTAL_ALIGNMENT_LEFT, -1, _chip_font()).x + CHIP_PAD * 2.0


func _row_width(row: PackedStringArray) -> float:
	var total: float = CHIP_GAP * maxf(0.0, row.size() - 1)
	for flag in row:
		total += _chip_width(flag)
	return total


## One row of status chips on `baseline`: dark fill, a warning-coloured rule, the flag inside.
func _draw_chip_row(row: PackedStringArray, left: float, baseline: float, width: float, centred: bool) -> void:
	var x: float = left + (width - _row_width(row)) * 0.5 if centred else left
	for flag in row:
		var chip: float = minf(_chip_width(flag), width)
		var box: Rect2 = Rect2(x, baseline - _chip_font() + 1.0, chip, _chip_height())
		draw_rect(box, INK)
		draw_rect(box, Color(STATUS, 0.75), false, 2.0)
		_text(flag, Vector2(x + CHIP_PAD, baseline), chip - CHIP_PAD * 2.0, _chip_font(), STATUS)
		x += chip + CHIP_GAP


func request_redraw() -> void:
	queue_redraw()
	redraw_requested.emit()
