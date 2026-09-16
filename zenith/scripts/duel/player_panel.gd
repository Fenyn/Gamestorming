class_name PlayerPanel
extends PanelContainer
## Public state for one player, read from the seat view. Three headline tiles carry the numbers
## a fight turns on: Vigor (what attacks cost and drain), Might (what a Strike hits for, through
## the Strike Table), and Life (cards left in the Life Deck). Favor tier and Acclaim share one
## quieter line because Acclaim feeds the tier. Pile counts and standing flags come last. The
## left edge carries the Focus guild colour; chips in the header say whose turn it is and who is
## attacking or defending.

const ACCLAIM_PIPS: int = 5
const MAX_TIERS: int = 5
const ACCLAIM_PIP_SIZE: Vector2 = Vector2(11, 11)
const FAVOR_PIP_SIZE: Vector2 = Vector2(14, 7)
const LOW_LIFE: int = 10
const LOW_VIGOR: int = 2

@onready var fighter_label: Label = $Column/Header/Fighter
@onready var turn_chip: Label = $Column/Header/Turn
@onready var combat_chip: Label = $Column/Header/Combat
@onready var sub_label: Label = $Column/Sub
@onready var vigor_tile: StatTile = $Column/Stats/Vigor
@onready var might_tile: StatTile = $Column/Stats/Might
@onready var life_tile: StatTile = $Column/Stats/Life
@onready var favor_pips: HBoxContainer = $Column/FavorRow/FavorPips
@onready var favor_value: Label = $Column/FavorRow/FavorValue
@onready var acclaim_pips: HBoxContainer = $Column/FavorRow/AcclaimPips
@onready var acclaim_value: Label = $Column/FavorRow/AcclaimValue
@onready var hand_label: Label = $Column/Counts/Hand
@onready var discard_label: Label = $Column/Counts/Discard
@onready var removed_label: Label = $Column/Counts/Removed
@onready var flags_label: Label = $Column/Flags

var _acclaim_panels: Array[Panel] = []
var _favor_panels: Array[Panel] = []


func _ready() -> void:
	for i in range(ACCLAIM_PIPS):
		_acclaim_panels.append(_make_pip(acclaim_pips, ACCLAIM_PIP_SIZE))
	for i in range(MAX_TIERS):
		_favor_panels.append(_make_pip(favor_pips, FAVOR_PIP_SIZE))
	ZenithTheme.chip(turn_chip, ZenithTheme.ACCENT, true)
	acclaim_value.add_theme_color_override("font_color", ZenithTheme.ACCENT)
	for l in [hand_label, discard_label, removed_label]:
		l.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.RAISED, Color(0, 0, 0, 0), 5, 0, 7, 2))
		l.add_theme_color_override("font_color", ZenithTheme.MUTED)
	flags_label.add_theme_color_override("font_color", ZenithTheme.WARN)


func _make_pip(parent: HBoxContainer, pip_size: Vector2) -> Panel:
	var p: Panel = Panel.new()
	p.custom_minimum_size = pip_size
	parent.add_child(p)
	return p


func refresh(p: SeatPlayer, view: SeatView, is_viewer: bool) -> void:
	var over: bool = view.is_over()
	var rival: SeatPlayer = view.player(1 - p.index)
	var fighter: SeatCard = view.card(p.fighter)
	add_theme_stylebox_override("panel", ZenithTheme.edged(Palette.guild_ui(p.focus)))
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
	who.append("%s %s" % [CardText.guild_name(p.focus), p.alignment.capitalize()])
	if p.focus != "":
		who.append("Focus")
	# Headline tiles follow the personality in control, which is what the engine fights with.
	var ic: SeatCard = view.card(p.controlling)
	if ic == null:
		ic = fighter
	if ic.uid != fighter.uid:
		who.append("%s in control" % ic.title)
	sub_label.text = "  ·  ".join(who)

	var vigor_color: Color = ZenithTheme.WARN if ic.vigor <= LOW_VIGOR else ZenithTheme.VIGOR
	vigor_tile.set_stat("Vigor", str(ic.vigor), "of 10" if ic.uid == fighter.uid else "Ally's", vigor_color)
	vigor_tile.set_pips(ic.vigor, 10, vigor_color)
	var rival_ic: SeatCard = view.card(rival.controlling)
	var rival_might: int = rival_ic.might if rival_ic != null else 0
	var hits: int = Session.strike_table.base_damage(ic.might, rival_might)
	might_tile.set_stat("Might", CardText.short_number(ic.might), "Strikes hit for %d" % hits, ZenithTheme.MIGHT)
	var life: int = p.life_deck.size()
	life_tile.set_stat("Life", str(life), "cards in deck", ZenithTheme.WARN if life <= LOW_LIFE else ZenithTheme.TEXT)

	for i in range(MAX_TIERS):
		_favor_panels[i].visible = i < p.highest_tier
		_favor_panels[i].add_theme_stylebox_override("panel", ZenithTheme.pip(i < fighter.tier, ZenithTheme.TEXT))
	favor_value.text = "%s · %d of %d" % [CardText.tier_name(fighter.tier), fighter.tier, p.highest_tier]
	for i in range(ACCLAIM_PIPS):
		_acclaim_panels[i].add_theme_stylebox_override("panel", ZenithTheme.pip(i < p.acclaim, ZenithTheme.ACCENT, true))
	acclaim_value.text = "%d/5" % p.acclaim

	hand_label.text = "Hand %d" % p.hand.size()
	discard_label.text = "Discard %d" % p.discard.size()
	removed_label.text = "Out %d" % p.removed.size()
	removed_label.visible = p.removed.size() > 0
	var flags: PackedStringArray = PackedStringArray()
	if p.must_pass:
		flags.append("Must pass")
	if p.skip_next_attack_phase:
		flags.append("Skips next attack")
	if p.token_victory_pending:
		flags.append("Seven Tokens held")
	if p.no_favor_win:
		flags.append("Cannot win by Favor")
	flags_label.text = "  ·  ".join(flags)
	flags_label.visible = not flags.is_empty()
