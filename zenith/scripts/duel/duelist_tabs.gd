class_name DuelistTabs
extends Control
## Dark tabs straddling a duelist card's edges, sized to the face: its Fervor pips on the top edge
## (filled for Fervor held, one per point the next Aspect needs) and, while an Ally fights in its
## place, which personality is in control on the bottom edge. Each reaches RISE face pixels past
## the edge.

signal changed

const RISE: float = 18.0
const HEIGHT: float = 42.0
const PAD: float = 12.0
const LABEL_FONT: int = 20
const LABEL_GAP: float = 10.0
const PIP: float = 26.0
const PIP_STEP: float = 32.0
const CONTROL_FONT: int = 20
const TAB_INK: Color = Color(0.12, 0.095, 0.085, 0.96)
const PIP_EMPTY: Color = Color(0.29, 0.2, 0.2)
const PIP_EDGE: Color = Color(0.06, 0.04, 0.04)

var _fervor: int = -1
var _need: int = 0
var _control: String = ""


## `fervor` -1 hides the Fervor tab; an empty `control` hides the other.
func show_tabs(fervor: int, need: int, control: String) -> void:
	var shown_need: int = maxi(1, need) if fervor >= 0 else 0
	if fervor == _fervor and shown_need == _need and control == _control:
		return
	_fervor = fervor
	_need = shown_need
	_control = control
	queue_redraw()
	changed.emit()


func fervor() -> int:
	return _fervor


func fervor_needed() -> int:
	return _need


func control_text() -> String:
	return _control


## The Fervor tab, centred on the top edge; empty when hidden.
func fervor_rect() -> Rect2:
	if _fervor < 0:
		return Rect2()
	var width: float = PAD * 2.0 + _label_width() + LABEL_GAP + PIP_STEP * float(_need - 1) + PIP
	return Rect2(size.x * 0.5 - width * 0.5, -RISE, width, HEIGHT)


func control_rect() -> Rect2:
	if _control == "":
		return Rect2()
	var width: float = minf(size.x - 40.0, get_theme_default_font().get_string_size(_control, HORIZONTAL_ALIGNMENT_LEFT, -1, CONTROL_FONT).x + PAD * 2.0)
	return Rect2(size.x * 0.5 - width * 0.5, size.y + RISE - HEIGHT, width, HEIGHT)


func _label_width() -> float:
	return get_theme_default_font().get_string_size("FERVOR", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT).x


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var tab: Rect2 = fervor_rect()
	if tab.has_area():
		draw_style_box(_tab_style(), tab)
		_text(font, "FERVOR", Rect2(tab.position.x + PAD, tab.position.y, _label_width(), tab.size.y), LABEL_FONT, ZenithTheme.FERVOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		var x: float = tab.position.x + PAD + _label_width() + LABEL_GAP
		for i in range(_need):
			var pip: Rect2 = Rect2(x + PIP_STEP * float(i), tab.get_center().y - PIP * 0.5, PIP, PIP)
			draw_rect(pip, ZenithTheme.FERVOR if i < _fervor else PIP_EMPTY)
			draw_rect(pip, PIP_EDGE, false, 2.0)
	var control: Rect2 = control_rect()
	if control.has_area():
		draw_style_box(_tab_style(), control)
		_text(font, _control, control.grow_individual(-PAD, 0.0, -PAD, 0.0), CONTROL_FONT, ZenithTheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)


func _tab_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = TAB_INK
	box.set_corner_radius_all(7)
	box.anti_aliasing = true
	return box


func _text(font: Font, text: String, box: Rect2, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var baseline: float = box.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(box.position.x, baseline), text, align, box.size.x, font_size, color)
