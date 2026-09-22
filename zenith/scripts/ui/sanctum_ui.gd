class_name SanctumUI
extends RefCounted
## Shared panel styling and restrained movement. Fonts inherit the project theme.

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = ZenithTheme.get_theme().duplicate()
	_theme.set_color("font_color", "MutedLabel", Color(0.66, 0.66, 0.66))
	_theme.set_stylebox("panel", "PanelContainer", panel())
	_theme.set_stylebox("panel", "Panel", panel())
	_theme.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	_theme.set_color("font_color", "AccentLabel", ZenithTheme.TEXT)
	for kind: String in ["Button", "OptionButton", "TileButton", "AccentButton"]:
		var primary: bool = kind == "AccentButton"
		_theme.set_stylebox("normal", kind, ZenithTheme.box(Color(0.78, 0.78, 0.76) if primary else Color(0.13, 0.13, 0.13), Color(0.30, 0.30, 0.30), 2, 1, 18, 10))
		_theme.set_stylebox("hover", kind, ZenithTheme.box(Color(0.90, 0.90, 0.88) if primary else Color(0.20, 0.20, 0.20), Color(0.44, 0.44, 0.44), 2, 1, 18, 10))
		_theme.set_stylebox("pressed", kind, ZenithTheme.box(Color(0.62, 0.62, 0.60) if primary else Color(0.09, 0.09, 0.09), Color(0.44, 0.44, 0.44), 2, 1, 18, 10))
		_theme.set_stylebox("disabled", kind, ZenithTheme.box(Color(0.11, 0.11, 0.11), Color(0.20, 0.20, 0.20), 2, 1, 18, 10))
		_theme.set_stylebox("focus", kind, ZenithTheme.box(Color.TRANSPARENT, Color(0.8, 0.8, 0.8), 2, 2, 0, 0))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_theme.set_color(state, kind, Color(0.10, 0.10, 0.10) if primary else ZenithTheme.TEXT)
		_theme.set_color("font_disabled_color", kind, Color(0.42, 0.42, 0.42))
	_theme.set_stylebox("normal", "LineEdit", ZenithTheme.box(Color(0.06, 0.06, 0.06), Color(0.22, 0.22, 0.22), 2, 1, 10, 6))
	_theme.set_stylebox("focus", "LineEdit", ZenithTheme.box(Color.TRANSPARENT, Color(0.65, 0.65, 0.65), 2, 1, 10, 6))
	return _theme


static func panel() -> StyleBoxFlat:
	return ZenithTheme.box(Color(0.065, 0.065, 0.065, 0.96), Color(0.20, 0.20, 0.20), 2, 1, 24, 22)


static func enter(control: Control, delay: float = 0.0) -> void:
	var previous: Tween = control.get_meta("sanctum_enter_tween") if control.has_meta("sanctum_enter_tween") else null
	if previous != null and previous.is_valid():
		previous.kill()
	if ArcaneBackdrop.motion_reduced():
		control.modulate.a = 1.0
		return
	control.modulate.a = 0.0
	var tween: Tween = control.create_tween()
	control.set_meta("sanctum_enter_tween", tween)
	tween.tween_interval(delay)
	tween.tween_property(control, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE)


static func wire_buttons(root: Node) -> void:
	for node: Node in root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.has_meta("sanctum_hover") or button is RosterTile:
			continue
		button.set_meta("sanctum_hover", true)
		button.mouse_entered.connect(func() -> void: _hover(button, true))
		button.mouse_exited.connect(func() -> void: _hover(button, false))


static func _hover(button: Button, over: bool) -> void:
	if button.disabled or ArcaneBackdrop.motion_reduced():
		return
	var previous: Tween = button.get_meta("sanctum_tween") if button.has_meta("sanctum_tween") else null
	if previous != null and previous.is_valid():
		previous.kill()
	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	button.set_meta("sanctum_tween", tween)
	tween.tween_property(button, "scale", Vector2.ONE * (1.025 if over else 1.0), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
