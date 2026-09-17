class_name PlayerPanel
extends PanelContainer
## Player-level state for one seat: Life Deck, hand, piles, Armory, Tokens, flags. Fighter
## numbers live on the fighter card.

const LOW_LIFE: int = 10

@onready var fighter_label: Label = $Column/Header/Fighter
@onready var turn_chip: Label = $Column/Header/Turn
@onready var combat_chip: Label = $Column/Header/Combat
@onready var sub_label: Label = $Column/Sub
@onready var life_tile: StatTile = $Column/Stats/Life
@onready var hand_tile: StatTile = $Column/Stats/Hand
@onready var discard_tile: StatTile = $Column/Stats/Discard
@onready var removed_label: Label = $Column/Counts/Removed
@onready var armory_label: Label = $Column/Counts/Armory
@onready var tokens_label: Label = $Column/Counts/Tokens
@onready var flags_label: Label = $Column/Flags


func _ready() -> void:
	ZenithTheme.chip(turn_chip, ZenithTheme.ACCENT, true)
	for l in [removed_label, armory_label, tokens_label]:
		l.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.RAISED, Color(0, 0, 0, 0), 5, 0, 7, 2))
		l.add_theme_color_override("font_color", ZenithTheme.MUTED)
	flags_label.add_theme_color_override("font_color", ZenithTheme.WARN)


func refresh(p: SeatPlayer, view: SeatView, is_viewer: bool) -> void:
	var over: bool = view.is_over()
	var fighter: SeatCard = view.card(p.fighter)
	add_theme_stylebox_override("panel", ZenithTheme.edged(Palette.guild_ui(p.style)))
	fighter_label.text = fighter.title
	turn_chip.visible = view.active == p.index and not over
	var in_combat: bool = view.step == GameState.Step.COMBAT and not over and view.phase != GameState.Phase.NONE
	combat_chip.visible = in_combat
	if in_combat:
		var attacking: bool = view.attacker == p.index
		combat_chip.text = "ATTACKING" if attacking else "DEFENDING"
		ZenithTheme.chip(combat_chip, ZenithTheme.ATTACK if attacking else ZenithTheme.DEFEND, true)
	var who: PackedStringArray = PackedStringArray()
	who.append("You, %s" % p.name if is_viewer else p.name)
	who.append("%s %s" % [CardText.guild_name(p.style), p.alignment.capitalize()])
	var ic: SeatCard = view.card(p.controlling)
	if ic != null and ic.uid != fighter.uid:
		who.append("%s in control" % ic.title)
	sub_label.text = "  ·  ".join(who)

	var life: int = p.life_deck.size()
	life_tile.set_stat("Life", str(life), "cards in deck", ZenithTheme.WARN if life <= LOW_LIFE else ZenithTheme.TEXT)
	hand_tile.set_stat("Hand", str(p.hand.size()), "cards", ZenithTheme.TEXT)
	discard_tile.set_stat("Discard", str(p.discard.size()), "cards", ZenithTheme.TEXT)
	removed_label.text = "Out %d" % p.removed.size()
	removed_label.visible = p.removed.size() > 0
	armory_label.text = "Armory %d" % p.armory.size()
	armory_label.visible = p.armory.size() > 0
	tokens_label.text = "Tokens %d" % p.tokens.size()
	tokens_label.visible = p.tokens.size() > 0
	var flags: PackedStringArray = PackedStringArray()
	if p.must_pass:
		flags.append("Must pass")
	if p.skip_next_attack_phase:
		flags.append("Skips next attack")
	if p.token_victory_pending:
		flags.append("%d Tokens held" % DuelEngine.TOKENS_PER_SET)
	if p.no_favor_win:
		flags.append("Cannot win by Favor")
	# Effective values that differ from the printed rules, so a card's standing effect is visible
	# without reading every card on the table.
	if p.acclaim_needed != DuelEngine.ACCLAIM_TO_TIER:
		flags.append("Needs %d Acclaim" % p.acclaim_needed)
	if p.acclaim_gain > 1:
		flags.append("Acclaim x%d" % p.acclaim_gain)
	if p.acclaim_shield:
		flags.append("Acclaim shielded")
	if p.tier_shield:
		flags.append("Tier shielded")
	for what in p.restrictions:
		flags.append(CardText.restriction_name(what))
	flags_label.text = "  ·  ".join(flags)
	flags_label.visible = not flags.is_empty()
