class_name KeyHint
extends HBoxContainer

## A key cap followed by what it does, e.g. [E] Grind. Build rows from hint
## text with row(): "[Hold click] Pour   [E] Leave" becomes two of these;
## text outside brackets becomes a plain label.

static func make(key: String, action: String, label_type: StringName = UiStyle.HUD_FLOAT) -> KeyHint:
	var h := KeyHint.new()
	h.add_theme_constant_override("separation", UiStyle.SPACE_S)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not key.is_empty():
		var cap := PanelContainer.new()
		cap.theme_type_variation = UiStyle.KEY_CAP
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var k := Label.new()
		k.text = key
		k.theme_type_variation = UiStyle.KEY_CAP_LABEL
		cap.add_child(k)
		h.add_child(cap)
	if not action.is_empty():
		var a := Label.new()
		a.text = action
		a.theme_type_variation = label_type
		h.add_child(a)
	return h

## Splits "[K] action [K2] action2 plain" into (key, action) pairs.
static func parse(text: String) -> Array:
	var pairs: Array = []
	var re := RegEx.create_from_string("\\[([^\\]]+)\\]\\s*([^\\[]*)|([^\\[]+)")
	for m in re.search_all(text):
		if m.get_string(1) != "":
			pairs.append([m.get_string(1), m.get_string(2).strip_edges()])
		elif m.get_string(3).strip_edges() != "":
			pairs.append(["", m.get_string(3).strip_edges()])
	return pairs

## Clears box and fills it with hints parsed from text.
static func fill(box: Container, text: String, label_type: StringName = UiStyle.HUD_FLOAT) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for p in parse(text):
		box.add_child(make(str(p[0]), str(p[1]), label_type))
