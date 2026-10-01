class_name DeckImport
extends RefCounted
## Reads a deck list written for the reference game and builds the closest deck of ours: every card
## with a parallel goes in, every other line comes back for the player to fill by hand.
##
## Two inputs. A CSV (or tab-separated paste) of the community decklist form: labelled rows for the
## Mastery, each Main Personality level and the Sensei, a Sensei Deck block, and name-and-quantity
## pairs anywhere else, which also covers a plain `qty,name` list. And an OCTGN deck file (.o8d), as
## the community deck site exports it: XML sections of <card qty="N">Name</card>.
##
## The form's own words ("Sensei", "MP Level") are matched here because they are the format's
## labels; they map onto our Relic, Reserve and Duelist Aspects.

const LABELS: Array[String] = ["card name", "name", "qty", "quantity", "count", "deck total",
	"maindeck", "main deck", "subtotal", "sensei total", "player name", "event", "date", "deck code",
	"total", "deck name"]
const NO_PARALLEL: String = "No Eidolarch card parallels this one."
const ADVENTURE_ONLY: String = "Banned outside adventure mode."

static var _frame_level: RegEx = RegEx.create_from_string("^(?:mp |main personality )?level (\\d)$")
static var _count_first: RegEx = RegEx.create_from_string("^(\\d{1,2})\\s*[xX]?\\s+(.+)$")
static var _count_last: RegEx = RegEx.create_from_string("^(.+?)\\s+[xX]\\s*(\\d{1,2})$")


static func read(text: String, library: CardLibrary, index: SourceIndex) -> ImportResult:
	var decoded: String = CustomDecks.code_text(text)
	if decoded != "":
		return read_own(decoded, library)
	if text.strip_edges().begins_with("{"):
		return read_own(text, library)
	var lines: Array[ImportLine] = parse(text)
	var result: ImportResult = resolve(lines, library, index)
	if lines.is_empty():
		result.error = "No card lines were found. Paste the CSV of a decklist form, a list of quantities and names, or an exported .o8d deck."
	return result


static func parse(text: String) -> Array[ImportLine]:
	var trimmed: String = text.strip_edges()
	if trimmed.begins_with("<"):
		return parse_o8d(trimmed)
	return parse_csv(trimmed)


## One of our own deck files, as the builder copies it out. Card ids this build does not know come
## back as missing lines and stay out of the deck.
static func read_own(text: String, library: CardLibrary) -> ImportResult:
	var result: ImportResult = ImportResult.new()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		result.deck = DeckList.new()
		result.error = "That text is not a deck file."
		return result
	var deck: DeckList = DeckList.from_dict(parsed)
	deck.mode = "tournament"
	deck.ai_profile = ""
	result.deck = deck
	var known: Callable = func(id: String) -> bool: return library.defs.has(id)
	var seen: Dictionary = {}
	var all_ids: Array[String] = deck.duelist_ids.duplicate()
	all_ids.append_array(deck.cards)
	all_ids.append_array(deck.reserve)
	for id: String in [deck.mastery_id, deck.relic_id]:
		if id != "":
			all_ids.append(id)
	for id in all_ids:
		if seen.has(id):
			(seen[id] as ImportLine).qty += 1
			continue
		var line: ImportLine = ImportLine.make(id, 1, ImportLine.LIFE, seen.size() + 1)
		line.status = ImportLine.MATCHED if known.call(id) else ImportLine.MISSING
		line.id = id if known.call(id) else ""
		line.reason = "" if known.call(id) else "This build has no card with that id."
		seen[id] = line
		result.lines.append(line)
	var stack: Array[String] = []
	stack.assign(deck.duelist_ids.filter(known))
	deck.set_duelist(stack)
	deck.cards.assign(deck.cards.filter(known))
	deck.reserve.assign(deck.reserve.filter(known))
	if not known.call(deck.mastery_id):
		deck.mastery_id = ""
	if not known.call(deck.relic_id):
		deck.relic_id = ""
	return result


# --- CSV and pasted text --------------------------------------------------------------------------

static func parse_csv(text: String) -> Array[ImportLine]:
	var out: Array[ImportLine] = []
	var delimiter: String = "\t" if text.count("\t") > text.count(",") else ","
	var rows: Array[PackedStringArray] = csv_rows(text, delimiter)
	# The column under the form's "Sensei Deck" label: pairs there, below it, are Reserve cards.
	var reserve_column: int = -1
	for r in range(rows.size()):
		var cells: PackedStringArray = rows[r]
		if _plain_row(cells):
			# A line of plain text: one name, maybe with a count, maybe with a comma inside it.
			var joined: String = delimiter.join(cells).strip_edges()
			var inline_line: ImportLine = _inline(joined, ImportLine.LIFE, r + 1)
			out.append(inline_line if inline_line != null else ImportLine.make(joined, 1, ImportLine.LIFE, r + 1))
			continue
		var c: int = 0
		while c < cells.size():
			var cell: String = cells[c].strip_edges()
			if cell == "":
				c += 1
				continue
			var key: String = SourceIndex.normalise(cell)
			var level: int = 0
			var found: RegExMatch = _frame_level.search(key)
			if found != null:
				level = int(found.get_string(1))
			if key == "mastery" or key == "sensei" or level > 0:
				var j: int = _next_filled(cells, c + 1)
				if j >= 0 and not _is_count(cells[j]) and not _is_label(cells[j]):
					var slot: String = ImportLine.MASTERY if key == "mastery" else (ImportLine.RELIC if key == "sensei" else ImportLine.DUELIST)
					out.append(ImportLine.make(cells[j], 1, slot, r + 1, level))
					c = j + 1
				else:
					c += 1
				continue
			if key == "sensei deck":
				reserve_column = c + 1
				c += 1
				continue
			if _is_label(cell):
				# A label's own value ("Subtotal: 7") is not a card count.
				var v: int = _next_filled(cells, c + 1)
				c = v + 1 if v >= 0 and _is_count(cells[v]) else c + 1
				continue
			var slot_here: String = ImportLine.RESERVE if c == reserve_column else ImportLine.LIFE
			var k: int = _next_filled(cells, c + 1)
			if _is_count(cell):
				if k >= 0 and not _is_count(cells[k]) and not _is_label(cells[k]):
					var slot_name: String = ImportLine.RESERVE if k == reserve_column else ImportLine.LIFE
					out.append(ImportLine.make(cells[k], int(cell), slot_name, r + 1))
					c = k + 1
				else:
					c += 1
				continue
			if k >= 0 and _is_count(cells[k]):
				out.append(ImportLine.make(cell, int(cells[k]), slot_here, r + 1))
				c = k + 1
				continue
			var inline: ImportLine = _inline(cell, slot_here, r + 1)
			if inline != null:
				out.append(inline)
			c += 1
	return out


## RFC 4180 rows: quoted cells may hold the delimiter, doubled quotes and line breaks.
static func csv_rows(text: String, delimiter: String = ",") -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var row: PackedStringArray = PackedStringArray()
	var cell: String = ""
	var quoted: bool = false
	var i: int = 0
	var n: int = text.length()
	while i < n:
		var ch: String = text[i]
		if quoted:
			if ch == "\"":
				if i + 1 < n and text[i + 1] == "\"":
					cell += "\""
					i += 1
				else:
					quoted = false
			else:
				cell += ch
		elif ch == "\"":
			quoted = true
		elif ch == delimiter:
			row.append(cell)
			cell = ""
		elif ch == "\n" or ch == "\r":
			if ch == "\r" and i + 1 < n and text[i + 1] == "\n":
				i += 1
			row.append(cell)
			rows.append(row)
			row = PackedStringArray()
			cell = ""
		else:
			cell += ch
		i += 1
	if cell != "" or not row.is_empty():
		row.append(cell)
		rows.append(row)
	return rows


static func _next_filled(cells: PackedStringArray, from: int) -> int:
	for i in range(from, cells.size()):
		if cells[i].strip_edges() != "":
			return i
	return -1


static func _is_count(cell: String) -> bool:
	var s: String = cell.strip_edges()
	return s.is_valid_int() and int(s) > 0 and int(s) < 100


static func _is_label(cell: String) -> bool:
	var s: String = cell.strip_edges()
	var key: String = SourceIndex.normalise(s)
	return s.begins_with("-") or s.ends_with(":") or LABELS.has(key) or key.contains("decklist") \
		or _frame_level.search(key) != null or key == "mastery" or key == "sensei" or key == "sensei deck"


## A row with no count, no label and no form slot in it is one card written as plain text.
static func _plain_row(cells: PackedStringArray) -> bool:
	var filled: int = 0
	for cell in cells:
		if cell.strip_edges() == "":
			continue
		filled += 1
		if _is_count(cell) or _is_label(cell):
			return false
	return filled > 0


## "3x Name", "3 Name" or "Name x3" in one cell or one line of plain text.
static func _inline(cell: String, slot: String, row: int) -> ImportLine:
	var found: RegExMatch = _count_first.search(cell)
	if found != null:
		return ImportLine.make(found.get_string(2), int(found.get_string(1)), slot, row)
	found = _count_last.search(cell)
	if found != null:
		return ImportLine.make(found.get_string(1), int(found.get_string(2)), slot, row)
	return null


# --- OCTGN deck files -----------------------------------------------------------------------------

static func parse_o8d(text: String) -> Array[ImportLine]:
	var out: Array[ImportLine] = []
	var parser: XMLParser = XMLParser.new()
	if parser.open_buffer(text.to_utf8_buffer()) != OK:
		return out
	var section: String = ""
	var pending: ImportLine = null
	var count: int = 0
	while parser.read() == OK:
		var node: XMLParser.NodeType = parser.get_node_type()
		if node == XMLParser.NODE_ELEMENT:
			var tag: String = parser.get_node_name().to_lower()
			if tag == "section":
				section = parser.get_named_attribute_value_safe("name")
			elif tag == "card":
				count += 1
				var qty: int = int(parser.get_named_attribute_value_safe("qty"))
				var named: String = parser.get_named_attribute_value_safe("name").xml_unescape()
				pending = ImportLine.make(named, qty if qty > 0 else 1, _section_slot(section), count)
				if parser.is_empty():
					if pending.text != "":
						out.append(pending)
					pending = null
		elif node == XMLParser.NODE_TEXT:
			if pending != null and pending.text == "":
				pending.text = parser.get_node_data().strip_edges().xml_unescape()
		elif node == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name().to_lower() == "card" and pending != null:
				if pending.text != "":
					out.append(pending)
				pending = null
	return out


static func _section_slot(section: String) -> String:
	var key: String = SourceIndex.normalise(section)
	if key == "sensei deck":
		return ImportLine.RESERVE
	if key == "starting" or key.contains("personality") or key == "mastery" or key == "sensei":
		return ImportLine.START
	return ImportLine.LIFE


# --- Matching -------------------------------------------------------------------------------------

## "Name (Set 12)" or "Name - Subtitle": the name and what followed it.
static func split_name(text: String) -> PackedStringArray:
	var s: String = text.strip_edges()
	if s.ends_with(")") and s.contains("("):
		var at: int = s.rfind("(")
		return PackedStringArray([s.substr(0, at).strip_edges(), s.substr(at + 1, s.length() - at - 2)])
	if s.contains(" - "):
		var cut: int = s.rfind(" - ")
		return PackedStringArray([s.substr(0, cut).strip_edges(), s.substr(cut + 3).strip_edges()])
	return PackedStringArray([s, ""])


## Our card ids for a line, in the library, best match first. A line whose name carries a level
## ("Lv 2") takes it as its level when the list gave none.
static func lookup(line: ImportLine, library: CardLibrary, index: SourceIndex) -> Array[String]:
	var ids: Array[String] = index.ids_for(line.text)
	var parts: PackedStringArray = split_name(line.text)
	if line.level == 0:
		line.level = SourceIndex.level_in(parts[1])
	if ids.is_empty() and parts[0] != line.text.strip_edges():
		ids = index.ids_for(parts[0], SourceIndex.set_hint(parts[1]))
	var out: Array[String] = []
	for id in ids:
		if library.defs.has(id):
			out.append(id)
	return out


static func resolve(lines: Array[ImportLine], library: CardLibrary, index: SourceIndex) -> ImportResult:
	var result: ImportResult = ImportResult.new()
	result.lines = lines
	var deck: DeckList = DeckList.new()
	deck.name = "Imported deck"
	result.deck = deck
	var candidates: Dictionary = {}   # ImportLine -> Array[String]
	for line in lines:
		var ids: Array[String] = lookup(line, library, index)
		if ids.is_empty():
			line.status = ImportLine.MISSING
			line.reason = NO_PARALLEL
		else:
			candidates[line] = ids
	var open: Array[ImportLine] = []
	for line in lines:
		if candidates.has(line):
			open.append(line)

	# The Mastery. Several printings share a name, and the list does not say which: the player picks.
	for line in _take(open, candidates, library, CardDef.Type.MASTERY):
		var ids: Array[String] = candidates[line]
		if deck.mastery_id != "" or _has_status(lines, ImportLine.CHOOSE):
			_refuse(line, ids[0], "A deck runs one Mastery.")
		elif ids.size() == 1:
			deck.mastery_id = ids[0]
			_match(line, ids[0])
		else:
			line.status = ImportLine.CHOOSE
			line.options = ids
	deck.style = _style(deck, lines, library, candidates)

	for line in _take(open, candidates, library, CardDef.Type.RELIC):
		var ids: Array[String] = candidates[line]
		if deck.relic_id != "":
			_refuse(line, ids[0], "A deck runs one Relic.")
		else:
			deck.relic_id = ids[0]
			_match(line, ids[0])

	_resolve_duelist(deck, open, candidates, library)
	deck.alignment = _alignment(deck, library)

	var seal_set: String = _seal_vote(open, candidates, library)
	for line in open:
		var ids: Array[String] = candidates[line]
		var id: String = _best(ids, library, deck.style, seal_set)
		var def: CardDef = library.defs[id]
		if bool(def.raw.get("banned", false)):
			_refuse(line, id, ADVENTURE_ONLY)
			continue
		if def.type == CardDef.Type.PERSONALITY and _fills_stack(deck, def, library):
			var stack: Array[String] = deck.duelist_ids.duplicate()
			stack.append(id)
			deck.set_duelist(_sorted_stack(stack, library))
			_match(line, id)
			continue
		var reserve: bool = line.slot == ImportLine.RESERVE or bool(def.raw.get("reserve_only", false))
		for i in range(line.qty):
			if reserve:
				deck.reserve.append(id)
			else:
				deck.cards.append(id)
		_match(line, id)
	return result


## Lines whose candidates are all of `type`, taken out of `open` in list order. Frame slots come
## first so a labelled Mastery or Relic wins over one listed among the deck's cards.
static func _take(open: Array[ImportLine], candidates: Dictionary, library: CardLibrary, type: CardDef.Type) -> Array[ImportLine]:
	var framed: Array[ImportLine] = []
	var loose: Array[ImportLine] = []
	for line in open:
		if _all_of(candidates[line], library, type):
			if line.slot == ImportLine.LIFE or line.slot == ImportLine.RESERVE:
				loose.append(line)
			else:
				framed.append(line)
	var taken: Array[ImportLine] = framed.duplicate()
	taken.append_array(loose)
	for line in taken:
		open.erase(line)
	return taken


static func _all_of(ids: Array[String], library: CardLibrary, type: CardDef.Type) -> bool:
	for id in ids:
		if (library.defs[id] as CardDef).type != type:
			return false
	return not ids.is_empty()


static func _resolve_duelist(deck: DeckList, open: Array[ImportLine], candidates: Dictionary, library: CardLibrary) -> void:
	var framed: Array[ImportLine] = []
	for line in open:
		if (line.slot == ImportLine.DUELIST or line.slot == ImportLine.START) \
				and _all_of(candidates[line], library, CardDef.Type.PERSONALITY):
			framed.append(line)
	if framed.is_empty():
		framed = _likely_duelist(open, candidates, library)
	var stack: Array[String] = []
	var character: String = ""
	var taken: Dictionary = {}
	for line in framed:
		open.erase(line)
		var id: String = _at_level(candidates[line], library, line.level)
		var def: CardDef = library.defs[id]
		if character == "":
			character = def.character
		if def.character != character:
			_refuse(line, id, "Not the same character as the Duelist.")
		elif taken.has(def.aspect):
			_refuse(line, id, "The Duelist already has an Aspect %d card." % def.aspect)
		else:
			taken[def.aspect] = true
			stack.append(id)
			_match(line, id)
	deck.set_duelist(_sorted_stack(stack, library))


## A plain list names no Duelist: the character with the most personality cards in it is taken to be
## the one. The player sees the stack and can change it before saving.
static func _likely_duelist(open: Array[ImportLine], candidates: Dictionary, library: CardLibrary) -> Array[ImportLine]:
	var by_character: Dictionary = {}
	var order: Array[String] = []
	for line in open:
		if not _all_of(candidates[line], library, CardDef.Type.PERSONALITY):
			continue
		var character: String = (library.defs[candidates[line][0]] as CardDef).character
		if not by_character.has(character):
			by_character[character] = [] as Array[ImportLine]
			order.append(character)
		(by_character[character] as Array[ImportLine]).append(line)
	var best: Array[ImportLine] = []
	for character in order:
		var group: Array[ImportLine] = by_character[character]
		if group.size() > best.size():
			best = group
	return best


static func _at_level(ids: Array[String], library: CardLibrary, level: int) -> String:
	if level > 0:
		for id in ids:
			if (library.defs[id] as CardDef).aspect == level:
				return id
	return ids[0]


static func _sorted_stack(ids: Array[String], library: CardLibrary) -> Array[String]:
	var out: Array[String] = ids.duplicate()
	out.sort_custom(func(a: String, b: String) -> bool:
		return (library.defs[a] as CardDef).aspect < (library.defs[b] as CardDef).aspect)
	return out


## A personality listed among the deck's cards that is the Duelist's character at an Aspect the
## stack lacks belongs in the stack.
static func _fills_stack(deck: DeckList, def: CardDef, library: CardLibrary) -> bool:
	if deck.duelist_ids.is_empty():
		return false
	var head: CardDef = library.defs.get(deck.duelist_ids[0])
	if head == null or head.character != def.character:
		return false
	for id in deck.duelist_ids:
		if (library.defs[id] as CardDef).aspect == def.aspect:
			return false
	return true


static func _alignment(deck: DeckList, library: CardLibrary) -> String:
	for id in deck.duelist_ids:
		var side: String = (library.defs[id] as CardDef).alignment_only
		if side != "":
			return side
	return "vigil"


## The Mastery's school, "freestyle" for a schoolless one. With the Mastery still to be picked, its
## printings share a school; with none at all, the school most matched cards carry.
static func _style(deck: DeckList, lines: Array[ImportLine], library: CardLibrary, candidates: Dictionary) -> String:
	var mastery: CardDef = library.defs.get(deck.mastery_id)
	if mastery == null:
		for line in lines:
			if line.status == ImportLine.CHOOSE:
				mastery = library.defs.get(line.options[0])
				break
	if mastery != null:
		return mastery.school if mastery.school != "" else "freestyle"
	var votes: Dictionary = {}
	for line in candidates.keys():
		var school: String = (library.defs[(candidates[line] as Array[String])[0]] as CardDef).school
		if school != "":
			votes[school] = int(votes.get(school, 0)) + (line as ImportLine).qty
	var best: String = "freestyle"
	for school: String in votes.keys():
		if best == "freestyle" or int(votes[school]) > int(votes[best]):
			best = school
	return best


## A deck runs one Seal set, so where a name parallels Seals in two sets, the set most of the list's
## Seals agree on wins.
static func _seal_vote(open: Array[ImportLine], candidates: Dictionary, library: CardLibrary) -> String:
	var votes: Dictionary = {}
	var order: Array[String] = []
	for line in open:
		for id: String in candidates[line]:
			var def: CardDef = library.defs[id]
			if def.type != CardDef.Type.SEAL:
				continue
			if not votes.has(def.seal_set):
				order.append(def.seal_set)
			votes[def.seal_set] = int(votes.get(def.seal_set, 0)) + 1
	var best: String = ""
	for set_name in order:
		if best == "" or int(votes[set_name]) > int(votes[best]):
			best = set_name
	return best


static func _best(ids: Array[String], library: CardLibrary, style: String, seal_set: String) -> String:
	if ids.size() == 1:
		return ids[0]
	var school: String = "" if style == "freestyle" else style
	for id in ids:
		var def: CardDef = library.defs[id]
		if def.type == CardDef.Type.SEAL and def.seal_set == seal_set:
			return id
	for id in ids:
		if (library.defs[id] as CardDef).school == school:
			return id
	for id in ids:
		if (library.defs[id] as CardDef).school == "":
			return id
	return ids[0]


static func _match(line: ImportLine, id: String) -> void:
	line.status = ImportLine.MATCHED
	line.id = id


static func _refuse(line: ImportLine, id: String, why: String) -> void:
	line.status = ImportLine.REFUSED
	line.id = id
	line.reason = why


static func _has_status(lines: Array[ImportLine], status: String) -> bool:
	for line in lines:
		if line.status == status:
			return true
	return false
