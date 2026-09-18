class_name SeatUpdate
extends RefCounted
## What one seat receives after the referee applied a command: the log lines for what happened,
## the seat's new view, and the seat's prompt if the next decision is theirs.

## {type, player, line}, plus `data` and `state` on the events a client animates.
var lines: Array[Dictionary] = []
var view: SeatView = null
var prompt: PromptView = null


func to_dict() -> Dictionary:
	return {
		"lines": lines,
		"view": view.to_dict() if view != null else {},
		"prompt": prompt.to_dict() if prompt != null else {},
	}


static func from_dict(d: Dictionary) -> SeatUpdate:
	var u: SeatUpdate = SeatUpdate.new()
	for l in d.get("lines", []):
		if l is Dictionary:
			u.lines.append(l)
	var vd: Dictionary = d.get("view", {})
	u.view = SeatView.from_dict(vd) if not vd.is_empty() else null
	var pd: Dictionary = d.get("prompt", {})
	u.prompt = PromptView.from_dict(pd) if not pd.is_empty() else null
	return u
