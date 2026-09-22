class_name TournamentRoute
extends Control
## The actual linear tournament ladder, drawn as a connected path. No invented bracket.

signal stage_selected(index: int)
var _rows: Array[Dictionary] = []
var _current: int = 0
var _won: bool = false
var _lost: bool = false
var _selected: int = 0
var _buttons: Array[Button] = []
var _clock: float = 0.0


func setup(run: AdventureRun, ladder: AdventureLadder) -> void:
	_current = run.stage
	_won = run.status == "won"
	_lost = run.status == "lost"
	_selected = _current
	custom_minimum_size = Vector2(400, 660)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	for i in range(ladder.size()):
		var row: Dictionary = ladder.stage(i)
		var opponent: String = str(row.get("opponent", ""))
		var deck: DeckList = DeckList.resolve(opponent)
		var duelist: CardDef = Session.library.defs.get(deck.duelist_face_id()) if deck != null else null
		var data: Dictionary = {"name": AdventureLadder.opponent_name(opponent, Session.library), "tier": AdventureLadder.tier_of(opponent), "grant": str(row.get("grant", ""))}
		_rows.append(data)
		var button: Button = Button.new()
		button.text = "%02d" % (i + 1)
		button.tooltip_text = "%s\n%s" % [data.name, data.tier]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var color: Color = ZenithTheme.ACCENT if i == _current else (ZenithTheme.ENERGY if i < _current else Color(0.40, 0.51, 0.57))
		button.add_theme_stylebox_override("normal", ZenithTheme.box(Color(0.025, 0.055, 0.072, 0.96), Color(color, 0.9), 28, 2, 0, 0))
		button.add_theme_stylebox_override("hover", ZenithTheme.box(Color(0.12, 0.17, 0.17), ZenithTheme.ACCENT, 28, 2, 0, 0))
		button.add_theme_color_override("font_color", color)
		button.pressed.connect(func() -> void:
			_selected = i
			queue_redraw()
			stage_selected.emit(i)
		)
		add_child(button)
		if duelist != null:
			var portrait: TextureRect = TextureRect.new()
			portrait.texture = CardFace.art_texture(duelist, duelist.aspect)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.position = Vector2(8, 8)
			portrait.size = Vector2(38, 38)
			portrait.modulate.a = 0.85 if i <= _current else 0.5
			button.add_child(portrait)
			if portrait.texture != null:
				button.text = ""
		_buttons.append(button)
	resized.connect(_layout)
	_layout()


func _point(index: int) -> Vector2:
	return Vector2(size.x * (0.32 if index % 2 == 0 else 0.68), 48 + index * (size.y - 100) / maxf(1.0, _rows.size() - 1))


func _layout() -> void:
	for i in range(_buttons.size()):
		_buttons[i].position = _point(i) - Vector2.ONE * 27
		_buttons[i].size = Vector2.ONE * 54
	queue_redraw()


func _process(delta: float) -> void:
	if not ArcaneBackdrop.motion_reduced():
		_clock += delta
		queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_font("font", "Label")
	var title_size: int = get_theme_font_size("font_size", "Label")
	var state_size: int = get_theme_font_size("font_size", "MutedLabel")
	for i in range(_rows.size()):
		var point: Vector2 = _point(i)
		if i == _selected and i != _current:
			draw_arc(point, 35, 0, TAU, 48, Color(0.65, 0.78, 0.83, 0.8), 1.5, true)
		if i == _rows.size() - 1:
			var corners: PackedVector2Array = PackedVector2Array([point + Vector2(0, -39), point + Vector2(39, 0), point + Vector2(0, 39), point + Vector2(-39, 0), point + Vector2(0, -39)])
			draw_polyline(corners, Color(0.75, 0.53, 0.22, 0.65), 1.5, true)
		if i > 0:
			var previous: Vector2 = _point(i - 1)
			var cleared: bool = i <= _current
			draw_line(previous, point, Color(0.17, 0.25, 0.28, 0.9), 6, true)
			draw_line(previous, point, Color(0.60, 0.48, 0.23, 0.75) if cleared else Color(0.37, 0.48, 0.49, 0.3), 2, true)
			if i == _current and not _won:
				var spark: Vector2 = previous.lerp(point, fposmod(_clock * 0.25, 1.0))
				draw_circle(spark, 4, Color(0.95, 0.78, 0.4, 0.8))
		if i == _current and not _won:
			draw_arc(point, 34 + sin(_clock * 2.0) * 1.5, 0, TAU, 48, Color(0.88, 0.70, 0.33, 0.65), 1.5, true)
			draw_arc(point, 40, -PI * 0.8, PI * 0.65, 40, Color(0.88, 0.70, 0.33, 0.22), 1, true)
		var left: bool = i % 2 == 0
		var width: float = size.x * 0.48
		var origin: Vector2 = point + Vector2(45 if left else -width - 45, -8)
		var title: String = str(_rows[i].name)
		while font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > width and title.length() > 5:
			title = title.left(title.length() - 2).strip_edges() + "…"
		draw_string(font, origin, title, HORIZONTAL_ALIGNMENT_LEFT, width, title_size, Color(0.95, 0.89, 0.74) if i == _current else Color(0.68, 0.75, 0.77))
		var state: String = "CLEARED" if i < _current else ("NEXT CHALLENGE" if i == _current and not _won else "ROUND %02d" % (i + 1))
		if i == _current and _lost:
			state = "DEFEATED"
		if i == _rows.size() - 1:
			state += "  /  FINAL"
		if _rows[i].grant == "aspect":
			state += "  /  ASPECT"
		draw_string(font, origin + Vector2(0, 22), state, HORIZONTAL_ALIGNMENT_LEFT, width, state_size, ZenithTheme.ACCENT if i == _current else Color(0.48, 0.59, 0.62))
