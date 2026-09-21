class_name OptionView
extends RefCounted
## One legal choice as shown to its player: the Command fields plus a ready-made label, so a
## client needs no engine to describe it.

var type: StringName = &""
var card: int = -1
var value: Variant = null
var label: String = ""
## Whose card this option names, when the card is on the table: -1 otherwise. Two options can read
## the same now that both players may field a personality of one title, and a client has no engine
## to ask. Only cards both seats can already see carry it, so it tells nobody anything new about a
## card in a hand, a Life Deck or a Reserve.
var owner: int = -1
## What this option would leave of the attack in the air, for the client's hover preview:
## `life` is the life cards the player would still lose. {} when there is nothing to promise.
var outcome: Dictionary = {}


func to_command(player: int) -> Command:
	return Command.new(player, type, card, value)


func to_dict() -> Dictionary:
	return {"type": String(type), "card": card, "value": value, "label": label, "owner": owner, "outcome": outcome}


static func from_dict(d: Dictionary) -> OptionView:
	var o: OptionView = OptionView.new()
	o.type = StringName(str(d.get("type", "")))
	o.card = int(d.get("card", -1))
	o.value = d.get("value", null)
	o.label = str(d.get("label", ""))
	o.owner = int(d.get("owner", -1))
	o.outcome = d.get("outcome", {})
	return o


static func of(cmd: Command, engine: DuelEngine) -> OptionView:
	var o: OptionView = OptionView.new()
	o.type = cmd.type
	o.card = cmd.card
	o.value = cmd.value
	o.label = CardText.command_label(cmd, engine)
	o.owner = OptionView.public_owner(engine, cmd.card)
	return o


## The owner of a card on the table, or -1 for no card and for a card in a hand, a Life Deck or a
## Reserve. The zones both seats can see are the only ones that answer, so the field carries no
## hidden information even when the option is a search of the player's own deck.
static func public_owner(engine: DuelEngine, uid: int) -> int:
	if uid < 0 or engine == null:
		return -1
	var c: CardInstance = engine.card(uid)
	if c == null:
		return -1
	return c.owner if SeatCard.visible_to(c, 0) and SeatCard.visible_to(c, 1) else -1
