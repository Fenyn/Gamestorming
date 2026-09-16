class_name Command
extends RefCounted
## A player decision. Prompts list the legal Commands; submit one of them back.

var player: int = 0
var type: StringName = &""
var card: int = -1          # CardInstance uid when the decision names a card
var value: Variant = null   # extra payload when needed


func _init(p_player: int = 0, p_type: StringName = &"", p_card: int = -1, p_value: Variant = null) -> void:
	player = p_player
	type = p_type
	card = p_card
	value = p_value


func matches(other: Command) -> bool:
	return player == other.player and type == other.type and card == other.card and value == other.value


## Wire form for sending a decision to another client. Values stay plain (int, String, bool).
func to_dict() -> Dictionary:
	return {"player": player, "type": String(type), "card": card, "value": value}


static func from_dict(d: Dictionary) -> Command:
	return Command.new(int(d.get("player", 0)), StringName(str(d.get("type", ""))), int(d.get("card", -1)), d.get("value", null))


func describe() -> String:
	var s: String = "P%d %s" % [player, type]
	if card >= 0:
		s += " #%d" % card
	if value != null:
		s += " %s" % str(value)
	return s


func _to_string() -> String:
	return describe()
