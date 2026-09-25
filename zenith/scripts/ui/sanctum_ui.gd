class_name SanctumUI
extends RefCounted
## Screen dressing and restrained movement over the one theme in ZenithTheme.

const SCHOOL_EDGE: float = 4.0


static func theme() -> Theme:
	return ZenithTheme.get_theme()


## Dresses a flat screen in the shared look: its title on the iron scroll banner, and inside a run
## a school-coloured edge under it (MapArt.school, set by `MapArt.tint_for_school`).
static func dress(_screen: Control, title: Label) -> void:
	if title == null:
		return
	banner_heading(title)
	var edge: ColorRect = title.get_node_or_null("SchoolEdge") as ColorRect
	if MapArt.school.a <= 0.0:
		if edge != null:
			edge.queue_free()
		return
	if edge == null:
		edge = ColorRect.new()
		edge.name = "SchoolEdge"
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_child(edge)
	edge.color = MapArt.school
	edge.anchor_left = 0.0
	edge.anchor_right = 1.0
	edge.anchor_top = 1.0
	edge.anchor_bottom = 1.0
	edge.offset_left = 22.0
	edge.offset_right = -22.0
	edge.offset_top = SCHOOL_EDGE
	edge.offset_bottom = SCHOOL_EDGE * 2.0


## A Label set on the iron scroll banner, in dark ink, sized to its text.
static func banner_heading(label: Label) -> void:
	label.add_theme_stylebox_override("normal", MapArt.banner_box("banner", 36, 12, 16))
	label.add_theme_color_override("font_color", ZenithTheme.TEXT_DARK)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func panel() -> StyleBox:
	return ZenithTheme.panel()


static func flat_panel() -> StyleBoxFlat:
	return ZenithTheme.flat_panel()


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
