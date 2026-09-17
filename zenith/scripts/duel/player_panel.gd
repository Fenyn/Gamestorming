class_name PlayerPanel
extends PanelContainer
## Player-level state for one seat: Life Deck, hand, piles, Reserve, Seals, flags. Duelist
## numbers live on the duelist card.

const LOW_LIFE: int = 10

@onready var duelist_label: Label = $Column/Header/Duelist
@onready var turn_chip: Label = $Column/Header/Turn
@onready var combat_chip: Label = $Column/Header/Combat
@onready var sub_label: Label = $Column/Sub
@onready var life_tile: StatTile = $Column/Stats/Life
@onready var hand_tile: StatTile = $Column/Stats/Hand
@onready var discard_tile: StatTile = $Column/Stats/Discard
@onready var removed_label: Label = $Column/Counts/Removed
@onready var reserve_label: Label = $Column/Counts/Reserve
@onready var seals_label: Label = $Column/Counts/Seals
@onready var flags_label: Label = $Column/Flags


func _ready() -> void:
	ZenithTheme.chip(turn_chip, ZenithTheme.ACCENT, true)
	for l in [removed_label, reserve_label, seals_label]:
		l.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.RAISED, Color(0, 0, 0, 0), 5, 0, 7, 2))
		l.add_theme_color_override("font_color", ZenithTheme.MUTED)
	flags_label.add_theme_color_override("font_color", ZenithTheme.WARN)


func refresh(p: SeatPlayer, view: SeatView, is_viewer: bool) -> void:
	var over: bool = view.is_over()
	var duelist: SeatCard = view.card(p.duelist)
	add_theme_stylebox_override("panel", ZenithTheme.edged(Palette.school_ui(p.style)))
	duelist_label.text = duelist.title
	turn_chip.visible = view.active == p.index and not over
	var in_combat: bool = view.step == GameState.Step.COMBAT and not over and view.phase != GameState.Phase.NONE
	combat_chip.visible = in_combat
	if in_combat:
		var attacking: bool = view.attacker == p.index
		combat_chip.text = "ATTACKING" if attacking else "DEFENDING"
		ZenithTheme.chip(combat_chip, ZenithTheme.ATTACK if attacking else ZenithTheme.DEFEND, true)
	var who: PackedStringArray = PackedStringArray()
	who.append("You, %s" % p.name if is_viewer else p.name)
	who.append("%s %s" % [CardText.school_name(p.style), p.alignment.capitalize()])
	if Archetype.label(p.archetype) != "":
		who.append(Archetype.label(p.archetype))
	var ic: SeatCard = view.card(p.controlling)
	if ic != null and ic.uid != duelist.uid:
		who.append("%s in control" % ic.title)
	sub_label.text = "  ·  ".join(who)

	var life: int = p.life_deck.size()
	life_tile.set_stat("Life", str(life), "cards in deck", ZenithTheme.WARN if life <= LOW_LIFE else ZenithTheme.TEXT)
	hand_tile.set_stat("Hand", str(p.hand.size()), "cards", ZenithTheme.TEXT)
	discard_tile.set_stat("Discard", str(p.discard.size()), "cards", ZenithTheme.TEXT)
	removed_label.text = "Out %d" % p.removed.size()
	removed_label.visible = p.removed.size() > 0
	reserve_label.text = "Reserve %d" % p.reserve.size()
	reserve_label.visible = p.reserve.size() > 0
	seals_label.text = "Seals %d" % p.seals.size()
	seals_label.visible = p.seals.size() > 0
	var flags: PackedStringArray = PackedStringArray()
	if p.must_pass:
		flags.append("Must pass")
	if p.skip_next_attack_phase:
		flags.append("Skips next attack")
	if p.seal_victory_pending:
		flags.append("%d Seals held" % DuelEngine.SEALS_PER_SET)
	if p.no_ascension_win:
		flags.append("Cannot win by Ascension")
	# Effective values that differ from the printed rules, so a card's standing effect is visible
	# without reading every card on the table.
	if p.fervor_needed != DuelEngine.FERVOR_TO_ASPECT:
		flags.append("Needs %d Fervor" % p.fervor_needed)
	if p.fervor_gain > 1:
		flags.append("Fervor x%d" % p.fervor_gain)
	if p.fervor_shield:
		flags.append("Fervor shielded")
	if p.aspect_shield:
		flags.append("Aspect shielded")
	for what in p.restrictions:
		flags.append(CardText.restriction_name(what))
	flags_label.text = "  ·  ".join(flags)
	flags_label.visible = not flags.is_empty()
