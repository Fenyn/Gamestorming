class_name OptionView
extends RefCounted
## One legal choice as shown to its player: the Command fields plus a ready-made label, so a
## client needs no engine to describe it.

var type: StringName = &""
var card: int = -1
var value: Variant = null
var label: String = ""
## What this option would leave of the attack in the air, for the client's hover preview:
## `life` is the life cards the player would still lose. {} when there is nothing to promise.
var outcome: Dictionary = {}


func to_command(player: int) -> Command:
	return Command.new(player, type, card, value)


func to_dict() -> Dictionary:
	return {"type": String(type), "card": card, "value": value, "label": label, "outcome": outcome}


static func from_dict(d: Dictionary) -> OptionView:
	var o: OptionView = OptionView.new()
	o.type = StringName(str(d.get("type", "")))
	o.card = int(d.get("card", -1))
	o.value = d.get("value", null)
	o.label = str(d.get("label", ""))
	o.outcome = d.get("outcome", {})
	return o


static func of(cmd: Command, engine: DuelEngine) -> OptionView:
	var o: OptionView = OptionView.new()
	o.type = cmd.type
	o.card = cmd.card
	o.value = cmd.value
	o.label = CardText.command_label(cmd, engine)
	return o
