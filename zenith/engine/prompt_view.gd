class_name PromptView
extends RefCounted
## A pending decision as its player sees it: kind, title, the public context, and the options.
## Answering means sending one option back as a Command; the referee accepts nothing else.

var player: int = 0
var kind: StringName = &""
var title: String = ""
var context: Dictionary = {}
var options: Array[OptionView] = []
var batch_type: StringName = &""   # when set, several card options may be answered at once
var batch_min: int = 0
var batch_max: int = 0


func has_batch() -> bool:
	return batch_type != &""


## The one Command that answers this prompt with several of its card options at once. Built
## here, not by clients, so the shape stays the referee's to define.
func batch_option(uids: Array[int]) -> OptionView:
	var o: OptionView = OptionView.new()
	o.type = batch_type
	o.card = -1
	o.value = uids.duplicate()
	o.label = "%s %d" % [batch_verb(), uids.size()]
	return o


func batch_verb() -> String:
	match batch_type:
		&"pages_in":
			return "Bring in"
		&"discard_choice":
			return "Discard"
		&"pick_in_play":
			return "Choose"
		_:
			return "Take"


func options_for_card(uid: int) -> Array[OptionView]:
	var out: Array[OptionView] = []
	for o in options:
		if o.card == uid:
			out.append(o)
	return out


func find(type: StringName, card: int = -1, value: Variant = null) -> OptionView:
	for o in options:
		if o.type != type:
			continue
		if card >= 0 and o.card != card:
			continue
		if value != null and o.value != value:
			continue
		return o
	return null


func card_uids() -> Dictionary:
	var out: Dictionary = {}
	for o in options:
		if o.card >= 0:
			out[o.card] = true
	return out


func to_dict() -> Dictionary:
	var os: Array = []
	for o in options:
		os.append(o.to_dict())
	return {
		"player": player, "kind": String(kind), "title": title, "context": context, "options": os,
		"batch": String(batch_type), "batch_min": batch_min, "batch_max": batch_max,
	}


static func from_dict(d: Dictionary) -> PromptView:
	var p: PromptView = PromptView.new()
	p.player = int(d.get("player", 0))
	p.kind = StringName(str(d.get("kind", "")))
	p.title = str(d.get("title", ""))
	p.context = d.get("context", {})
	for od in d.get("options", []):
		p.options.append(OptionView.from_dict(od))
	p.batch_type = StringName(str(d.get("batch", "")))
	p.batch_min = int(d.get("batch_min", 0))
	p.batch_max = int(d.get("batch_max", 0))
	return p


static func of(prompt: Prompt, engine: DuelEngine) -> PromptView:
	var p: PromptView = PromptView.new()
	p.player = prompt.player
	p.kind = prompt.kind
	p.title = CardText.prompt_title(prompt)
	p.context = prompt.context.duplicate()
	for o in prompt.options:
		p.options.append(OptionView.of(o, engine))
	p.batch_type = prompt.batch_type
	p.batch_min = prompt.batch_min
	p.batch_max = prompt.batch_max
	return p
