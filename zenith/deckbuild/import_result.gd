class_name ImportResult
extends RefCounted
## What an import produced: a deck holding every matched card, and every line, matched or not, so
## the builder can list what is left for the player to fill.

var deck: DeckList = null
var lines: Array[ImportLine] = []
## Set when the text read as no deck list at all.
var error: String = ""


func matched() -> Array[ImportLine]:
	return _with(ImportLine.MATCHED)


func missing() -> Array[ImportLine]:
	return _with(ImportLine.MISSING)


func choices() -> Array[ImportLine]:
	return _with(ImportLine.CHOOSE)


func refused() -> Array[ImportLine]:
	return _with(ImportLine.REFUSED)


## Copies the list asked for, matched or not.
func copies_asked() -> int:
	var n: int = 0
	for line in lines:
		n += line.qty
	return n


func copies_matched() -> int:
	var n: int = 0
	for line in matched():
		n += line.qty
	return n


func _with(status: String) -> Array[ImportLine]:
	var out: Array[ImportLine] = []
	for line in lines:
		if line.status == status:
			out.append(line)
	return out
