class_name ImportLine
extends RefCounted
## One card line read from a pasted or opened deck list, and what the importer made of it.

## Where the list put the card. START is the opening section of an exported deck, which holds the
## Mastery, the Duelist and the Relic; the matched card's type decides which.
const LIFE: String = "life"
const RESERVE: String = "reserve"
const DUELIST: String = "duelist"
const MASTERY: String = "mastery"
const RELIC: String = "relic"
const START: String = "start"

const MATCHED: String = "matched"
## No card of ours parallels the name.
const MISSING: String = "missing"
## Several cards parallel it and the list does not say which; `options` holds them.
const CHOOSE: String = "choose"
## A card matched but cannot go where the list put it; `reason` says why.
const REFUSED: String = "refused"

var text: String = ""     # the name as the list wrote it
var qty: int = 1
var slot: String = LIFE
var level: int = 0        # a Duelist line's Aspect, 0 when the list gives none
var row: int = 0          # 1-based line or row in the source, for the failures panel

var status: String = MISSING
var id: String = ""
var options: Array[String] = []
var reason: String = ""


static func make(text_value: String, qty_value: int, slot_value: String, row_value: int, level_value: int = 0) -> ImportLine:
	var line: ImportLine = ImportLine.new()
	line.text = text_value.strip_edges()
	line.qty = maxi(qty_value, 1)
	line.slot = slot_value
	line.row = row_value
	line.level = level_value
	return line
