class_name ReplayCursor
extends RefCounted
## Plays a MatchRecord back on a referee of its own, one history entry at a time, for the replay
## viewer. A step hands back the SeatUpdates the live duel handed out, so the table plays them with
## the same beats. A jump rebuilds from the deal without display capture and hands back a catch-up
## from `Referee.catch_up`, which the table shows without animating.
##
## Updates come as [seat 1, seat 2, ALL]: each seat's exactly as that player saw it, and at ALL the
## full-information one from seat 1's side of the table, every card shown and named.

const ALL: int = 2
const OTHER_VERSION: String = "This replay was recorded on another version of the game."

var record: MatchRecord = null
## Entries applied so far: the table stands after the first `position` of them.
var position: int = 0
## The entries that replay. Short of the record only when one stopped applying (`stopped`).
var total: int = 0
var at_end: bool:
	get:
		return position >= total
## Where the record stops replaying and why, as `Referee.replay` words it; "" when all of it does.
var stopped: String = ""
## {"turn", "player", "index"} per turn start, in order; `index` is the position the turn opens at.
var turns: Array[Dictionary] = []
## The updates of the deal, before the first entry.
var opening: Array[SeatUpdate] = []

var _library: CardLibrary = null
var _table: StrikeTable = null
var _referee: Referee = null
var _indexing: bool = false
var _applied: int = 0
var _scanned: int = 0
## The rebuild's events from its last turn start on, which a catch-up's lines are worded from.
var _tail: Array[GameEvent] = []


## One silent pass over the whole record indexes its turns and finds how much of it replays, then
## the referee is dealt again with display capture on and the cursor stands at the deal.
func _init(p_record: MatchRecord, library: CardLibrary, table: StrikeTable) -> void:
	record = p_record
	_library = library
	_table = table
	_indexing = true
	stopped = _rebuild(record.commands)
	_indexing = false
	total = _applied
	if _referee == null:
		return
	_referee = record.setup_referee(_library, _table)
	_referee.start()
	var events: Array[GameEvent] = _referee.engine.events.duplicate()
	opening = _referee.take_updates()
	opening.append(_full(opening[0], events))


## "" when this build can play the record, else the sentence the viewer shows.
static func version_problem(r: MatchRecord, protocol: int, catalog: String, build: String) -> String:
	return "" if r.protocol == protocol and r.catalog == catalog and r.build == build else OTHER_VERSION


## The two decks as the record holds them, by catalog id or inline; null for one this build lacks.
static func decks_of(r: MatchRecord) -> Array[DeckList]:
	var out: Array[DeckList] = []
	for seat in r.seats:
		out.append(DeckList.from_dict(seat["list"]) if seat.has("list") else DeckList.resolve(str(seat["deck"])))
	return out


## Applies the next entry and returns what it produced, [] at the end.
func step() -> Array[SeatUpdate]:
	if at_end or _referee == null:
		return []
	var problem: String = _apply(record.commands[position])
	if problem != "":
		stopped = "entry %d: %s" % [position, problem]
		total = position
		return []
	position += 1
	var events: Array[GameEvent] = _referee.engine.events.duplicate()
	var out: Array[SeatUpdate] = _referee.take_updates()
	out.append(_full(out[0], events))
	return out


## One entry back, shown as a catch-up.
func back() -> Array[SeatUpdate]:
	return seek(position - 1)


## Rebuilds silently to `index` entries and returns each view's catch-up there.
func seek(index: int) -> Array[SeatUpdate]:
	if _referee == null:
		return []
	index = clampi(index, 0, total)
	_rebuild(record.commands.slice(0, index))
	position = index
	_referee.take_updates()
	_referee.engine.record_display_state = true
	var out: Array[SeatUpdate] = [_referee.catch_up(0), _referee.catch_up(1)]
	out.append(_full(out[0], _tail))
	return out


## The position turn `turn` opens at, -1 when the record never reaches it.
func turn_index(turn: int) -> int:
	for t in turns:
		if int(t["turn"]) == turn:
			return int(t["index"])
	return -1


## The turn the table stands in, 0 before the first.
func current_turn() -> int:
	var turn: int = 0
	for t in turns:
		if int(t["index"]) <= position:
			turn = int(t["turn"])
	return turn


func view(seat: int, reveal_all: bool = false) -> SeatView:
	return SeatView.of(_referee.engine, seat, true, reveal_all)


## The entry the next step applies, {} at the end.
func next_entry() -> Dictionary:
	return record.commands[position] if not at_end else {}


## How long the player took over the next entry, from the record's `at` stamps.
func next_gap_ms() -> int:
	if at_end:
		return 0
	var before: int = int(record.commands[position - 1]["at"]) if position > 0 else 0
	return maxi(0, int(record.commands[position]["at"]) - before)


## A referee dealt afresh, with `entries` run through it silently. Returns what `Referee.replay`
## says, "" when all of them applied.
func _rebuild(entries: Array[Dictionary]) -> String:
	_referee = record.setup_referee(_library, _table, false)
	if _referee == null:
		return "a deck in the record is not in this build"
	_applied = 0
	_scanned = 0
	_tail.clear()
	_referee.start()
	_scan()
	_referee.command_applied.connect(_on_applied)
	var problem: String = _referee.replay(entries)
	_referee.command_applied.disconnect(_on_applied)
	return problem


func _on_applied(_seat: int, _entry: Dictionary) -> void:
	_applied += 1
	_scan()


## Reads the events the rebuild added since the last look. Nothing takes them until the replay
## returns, so the engine's list only grows while this runs.
func _scan() -> void:
	var events: Array[GameEvent] = _referee.engine.events
	for i in range(_scanned, events.size()):
		var ev: GameEvent = events[i]
		if ev.type == &"turn_start":
			_tail.clear()
			if _indexing:
				turns.append({"turn": int(ev.data.get("turn", 0)), "player": int(ev.data.get("player", -1)), "index": _applied})
		_tail.append(ev)
	_scanned = events.size()


func _apply(entry: Dictionary) -> String:
	var seat: int = int(entry.get("player", -1))
	if entry.has("dev"):
		return _referee.dev({"player": seat, "effect": entry["dev"]})
	return _referee.submit(seat, entry)


## The full-information update beside seat 1's: the same lines, animation data and stamps, worded
## with every card named, over the full view, with the prompt of whoever answers next.
func _full(seat_update: SeatUpdate, events: Array[GameEvent]) -> SeatUpdate:
	var u: SeatUpdate = SeatUpdate.new()
	for i in range(seat_update.lines.size()):
		var line: Dictionary = seat_update.lines[i].duplicate()
		if i < events.size():
			line["line"] = CardText.event_line(events[i], _referee.engine, 0, true)
		u.lines.append(line)
	u.view = view(0, true)
	var next: Dictionary = next_entry()
	u.prompt = _referee.prompt_for(int(next["player"])) if not next.is_empty() else null
	return u
