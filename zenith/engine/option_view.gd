class_name OptionView
extends RefCounted
## One legal choice as shown to its player: the Command fields plus a ready-made label, so a
## client needs no engine to describe it.

var type: StringName = &""
var card: int = -1
var value: Variant = null
var label: String = ""


func to_command(player: int) -> Command:
	return Command.new(player, type, card, value)


func to_dict() -> Dictionary:
	return {"type": String(type), "card": card, "value": value, "label": label}


static func from_dict(d: Dictionary) -> OptionView:
	var o: OptionView = OptionView.new()
	o.type = StringName(str(d.get("type", "")))
	o.card = int(d.get("card", -1))
	o.value = d.get("value", null)
	o.label = str(d.get("label", ""))
	return o


static func of(cmd: Command, engine: DuelEngine) -> OptionView:
	var o: OptionView = OptionView.new()
	o.type = cmd.type
	o.card = cmd.card
	o.value = cmd.value
	o.label = CardText.command_label(cmd, engine)
	return o
