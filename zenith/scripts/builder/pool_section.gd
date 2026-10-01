class_name PoolSection
extends VBoxContainer
## One clump of the deck builder's library: a school group and a card type under a header with its
## count, the cards in a grid below. It hides itself when none of its cards are shown.

var group: String = ""
var type: CardDef.Type = CardDef.Type.STRIKE
var grid: GridContainer
var _header: Label
var _edge: ColorRect
var _card: Vector2 = Vector2.ZERO


static func make(group_value: String, type_value: CardDef.Type, card_size: Vector2) -> PoolSection:
	var section: PoolSection = PoolSection.new()
	section.group = group_value
	section.type = type_value
	section._card = card_size
	section.add_theme_constant_override("separation", 6)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	section.add_child(row)
	section._edge = ColorRect.new()
	section._edge.custom_minimum_size = Vector2(4, 0)
	var school: String = group_value if group_value != "freestyle" and group_value != "signature" else ""
	section._edge.color = Palette.school_ui(school) if school != "" else Palette.type_ui(type_value)
	row.add_child(section._edge)
	section._header = Label.new()
	section._header.theme_type_variation = &"HeaderLabel"
	row.add_child(section._header)
	section.grid = GridContainer.new()
	section.grid.add_theme_constant_override("h_separation", 12)
	section.grid.add_theme_constant_override("v_separation", 14)
	section.add_child(section.grid)
	return section


func fit_columns(width: float) -> void:
	var gap: int = grid.get_theme_constant("h_separation")
	grid.columns = maxi(1, int((width + gap) / (_card.x + gap)))


## Shows the section only when one of its cards shows, and counts those.
func refresh_header(group_label: String) -> void:
	var shown: int = 0
	for child: Node in grid.get_children():
		if (child as Control).visible:
			shown += 1
	visible = shown > 0
	var plurals: Dictionary = {CardDef.Type.PERSONALITY: "Allies", CardDef.Type.STRIKE: "Strikes", CardDef.Type.ART: "Arts",
		CardDef.Type.COMBAT: "Combat cards", CardDef.Type.NON_COMBAT: "Non-Combat cards", CardDef.Type.DRILL: "Drills",
		CardDef.Type.SEAL: "Seals", CardDef.Type.GROUNDS: "Grounds", CardDef.Type.RELIC: "Relics"}
	var type_label: String = str(plurals.get(type, "Cards"))
	_header.text = "%s  ·  %s   %d" % [group_label, type_label, shown]
