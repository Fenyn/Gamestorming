class_name KeywordLabel
extends RichTextLabel
## Rules text with keywords coloured and explained on hover. Give it plain text through set_plain;
## the BBCode and the tooltip panel are its own business.

const TIP_WIDTH: float = 320.0

## True on the dark HUD, false on a cream card face.
@export var on_dark: bool = false


func set_plain(plain: String) -> void:
	bbcode_enabled = true
	text = KeywordText.bbcode(plain, on_dark)


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text == "":
		return null
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG, ZenithTheme.BORDER, 8, 1, 12, 8))
	var label: Label = Label.new()
	label.text = for_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(TIP_WIDTH, 0)
	label.add_theme_color_override("font_color", ZenithTheme.TEXT)
	label.add_theme_font_size_override("font_size", 15)
	panel.add_child(label)
	return panel
