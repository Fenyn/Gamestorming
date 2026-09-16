class_name Prompt
extends RefCounted
## A pending decision. `options` are the only Commands the engine will accept, with one
## extension: a prompt may take a batch, one Command of `batch_type` whose value is an Array of
## card uids drawn from the options, between `batch_min` and `batch_max` of them, no repeats.
## That is how an Armory swap or a discard-two lands in one decision instead of a chain.

var player: int = 0
var kind: StringName = &""
var options: Array[Command] = []
var context: Dictionary = {}
var batch_type: StringName = &""
var batch_min: int = 0
var batch_max: int = 0


## Card uids this prompt lets the player pick, in option order.
func card_options() -> Array[int]:
	var out: Array[int] = []
	for o in options:
		if o.card >= 0 and not out.has(o.card):
			out.append(o.card)
	return out


func set_batch(type: StringName, lo: int, hi: int) -> void:
	batch_type = type
	batch_min = lo
	batch_max = hi


## The option `cmd` stands for, or a normalised batch Command, or null when it is not legal.
func accept(cmd: Command) -> Command:
	for o in options:
		if o.matches(cmd):
			return o
	if batch_type == &"" or cmd.type != batch_type or cmd.player != player or not (cmd.value is Array):
		return null
	var allowed: Array[int] = card_options()
	var uids: Array[int] = []
	for v in cmd.value:
		var uid: int = int(v)
		if not allowed.has(uid) or uids.has(uid):
			return null
		uids.append(uid)
	if uids.size() < batch_min or uids.size() > batch_max:
		return null
	return Command.new(player, batch_type, -1, uids)


## The uids a Command names: a batch's list, or the single card.
static func cards_of(cmd: Command) -> Array[int]:
	var out: Array[int] = []
	if cmd.value is Array:
		for v in cmd.value:
			out.append(int(v))
	elif cmd.card >= 0:
		out.append(cmd.card)
	return out


func has(type: StringName) -> bool:
	for o in options:
		if o.type == type:
			return true
	return false


## First option matching type (and card / value when given). Null if none.
func find(type: StringName, card: int = -1, value: Variant = null) -> Command:
	for o in options:
		if o.type != type:
			continue
		if card >= 0 and o.card != card:
			continue
		if value != null and o.value != value:
			continue
		return o
	return null


func describe() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for o in options:
		parts.append(o.describe())
	return "%s (P%d): %s" % [kind, player, ", ".join(parts)]
