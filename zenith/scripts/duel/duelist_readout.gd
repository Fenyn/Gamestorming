class_name DuelistReadout
extends Control
## Transparent illustrated readout rendered onto a world-space medallion.

const INK: Color = Color(0.025, 0.038, 0.065, 0.97)
const TEXT: Color = Color(0.96, 0.94, 0.86)
const MUTED: Color = Color(0.68, 0.74, 0.79)
const GOLD: Color = Color(0.97, 0.76, 0.39)
const ENERGY: Color = Color(0.35, 0.88, 1.0)
const FERVOR: Color = Color(0.95, 0.59, 0.29)
var reduced_motion: bool = false
var preview_cost: int = 0
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
var _accent: Color = GOLD
var _portrait: Texture2D
var _active: bool = false
var _initialized: bool = false
var _flash: float = 0.0
var _tween: Tween
var _font: Font = ThemeDB.fallback_font


func refresh(view: SeatView, player_index: int, viewer: int, live: Dictionary = {}) -> void:
	var p: SeatPlayer = view.player(player_index)
	var duelist: SeatCard = view.card(p.duelist)
	var controller: SeatCard = view.card(p.controlling)
	if duelist == null:
		return
	if controller == null:
		controller = duelist
	var old_values: Array[int] = [_life, _energy, _fervor, _aspect]
	var energies: Dictionary = live.get("energy", {})
	var fervors: Array = live.get("fervor", [])
	var zones: Array = live.get("zones", [])
	var counts: Array = zones[player_index] if zones.size() > player_index else []
	_life = int(counts[0]) if counts.size() > 0 else p.life_deck.size()
	_energy = int(energies.get(controller.uid, energies.get(str(controller.uid), controller.energy)))
	_might = controller.might
	# Replay snapshots omit Might: use the printed public ladder at the displayed Energy.
	var def: CardDef = Session.library.get_def(controller.def_id)
	if def != null:
		var ladder: Array = def.tier(controller.aspect).get("might", [])
		if not ladder.is_empty():
			_might = int(ladder[clampi(_energy, 0, ladder.size() - 1)])
	_fervor = int(fervors[player_index]) if fervors.size() > player_index else p.fervor
	_threshold = maxi(1, p.fervor_needed)
	_aspect = duelist.aspect
	_title = duelist.title
	_control = "YOU" if player_index == viewer else "OPPONENT"
	if controller.uid != duelist.uid:
		_control = "%s IN CONTROL" % controller.title
	_accent = Palette.school_ui(p.style)
	var duelist_def: CardDef = Session.library.get_def(duelist.def_id)
	_portrait = CardFace.art_texture(duelist_def, duelist.aspect) if duelist_def != null else null
	_active = int(live.get("active", view.active)) == player_index and not view.is_over()
	var hand: int = int(counts[1]) if counts.size() > 1 else p.hand.size()
	var discard: int = int(counts[2]) if counts.size() > 2 else p.discard.size()
	var removed: int = int(counts[3]) if counts.size() > 3 else p.removed.size()
	_piles = "Hand %d   Discard %d   Out %d" % [hand, discard, removed]
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
	if _initialized and old_values != [_life, _energy, _fervor, _aspect] and not reduced_motion:
		if _tween != null:
			_tween.kill()
		_flash = 1.0
		_tween = create_tween()
		_tween.tween_method(_set_flash, 1.0, 0.0, 0.55)
	_initialized = true
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _draw() -> void:
	if not _initialized:
		return
	# An open silhouette: portrait halo, suspended Life gem, and blade-shaped Might crest.
	var center: Vector2 = Vector2(135, 164)
	draw_circle(center, 112, INK)
	_portrait_disc(center, 91)
	draw_arc(center, 98, 0, TAU, 72, _accent, 4, true)
	draw_arc(center, 102, 0, TAU, 72, _accent.darkened(0.55), 2, true)
	if _flash > 0:
		draw_arc(center, 109 + 14 * (1.0 - _flash), 0, TAU, 72, Color(_accent, _flash * 0.7), 5, true)
	for i in range(10):
		var start: float = deg_to_rad(135 + i * 27)
		var on: bool = i < _energy
		var ghost: bool = on and i >= _energy - preview_cost
		var color: Color = ENERGY if on else Color(0.12, 0.23, 0.29)
		draw_arc(center, 114, start, start + deg_to_rad(21), 10, color, 9 if not ghost else 2, true)
	var life_center: Vector2 = Vector2(135, 267)
	_diamond(life_center, Vector2(66, 54), INK, GOLD)
	_text(str(_life), Vector2(69, 275), 132, 57, TEXT if _life > 10 else Color(1, 0.49, 0.38), true)
	_text("LIFE", Vector2(74, 300), 122, 24, MUTED, true)
	_text(_title, Vector2(270, 56), 470, 36, TEXT)
	_text(_control, Vector2(270, 89), 470, 25, _accent)
	draw_line(Vector2(270, 103), Vector2(723, 103), _accent.darkened(0.45), 2, true)
	_text("ENERGY", Vector2(273, 140), 178, 27, ENERGY)
	_text("%d / 10" % _energy, Vector2(273, 199), 190, 54, TEXT)
	_diamond(Vector2(575, 159), Vector2(107, 64), INK, _accent)
	_text("MIGHT", Vector2(484, 143), 182, 25, _accent, true)
	_text(CardText.short_number(_might), Vector2(476, 192), 198, 44, TEXT, true)
	_text("ASPECT %d" % _aspect, Vector2(273, 250), 430, 30, GOLD)
	var rune_count: int = mini(_threshold, 14)
	var step: float = minf(32.0, 420.0 / float(rune_count))
	for i in range(rune_count):
		_diamond(Vector2(287 + step * i, 276), Vector2(10, 12), FERVOR if i < _fervor else INK, FERVOR.darkened(0.2) if i < _fervor else MUTED.darkened(0.55))
	_text("FERVOR %d / %d" % [_fervor, _threshold], Vector2(273, 321), 430, 27, MUTED)
	_text(_piles, Vector2(42, 359), 686, 27, MUTED, true)
	# Long standing restrictions wrap into two rows; exact text is also in inspection.
	var lines: PackedStringArray = _wrap_flags(690, 23)
	for i in range(mini(lines.size(), 2)):
		_text(lines[i], Vector2(35, 392 + i * 28), 690, 23, FERVOR, true)
	if _active:
		draw_circle(Vector2(247, 45), 6, GOLD)


func _portrait_disc(center: Vector2, radius: float) -> void:
	if _portrait == null:
		draw_circle(center, radius, _accent.darkened(0.7))
		return
	var points: PackedVector2Array = PackedVector2Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var tex_size: Vector2 = _portrait.get_size()
	var crop: float = minf(tex_size.x, tex_size.y)
	for i in range(64):
		var direction: Vector2 = Vector2.from_angle(TAU * i / 64.0)
		points.append(center + direction * radius)
		uv.append(Vector2(0.5, 0.42) + direction * Vector2(crop / tex_size.x, crop / tex_size.y) * 0.5)
	draw_polygon(points, PackedColorArray([Color.WHITE]), uv, _portrait)


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
