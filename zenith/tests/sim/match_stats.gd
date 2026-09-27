class_name MatchStats
extends RefCounted
## Folds finished match records into the numbers to watch balance by: each deck's record, deck
## against deck, the first player's edge, how duels ended, and with the card pass, what each card
## did. Records group by `catalog`, since a change to the card or deck data starts a new balance
## period. `tools/match_stats.gd` reads the files and sets the filters; nothing here opens a file.
##
## Win rates carry the 95% Wilson interval from `SimReport`. Mirror duels stay out of the deck rows
## and the grid, as matchlab never plays them; the first-player line and the card pass keep them.
## Ranked records also count by match: each deck's match win rate, how many matches went 2-0 or 2-1,
## and how often the game 1 winner took the match.

const DEFAULT_MODES: Array[String] = ["ranked", "casual", "code"]
## The reasons a duel can have a winner by. `abandoned` has none.
const DECIDED: Array[String] = ["survival", "seal", "ascension", "concede", "timeout", "left"]
## A replay of a duel the rules ended must reach the recorded winner, or the data drifted under it.
const RULES_REASONS: Array[String] = ["survival", "seal", "ascension"]
## Command types that put a card to use from the hand or the table. A choice that only names a card
## (a search pick, a capture target, who takes control, a Reserve swap, a Power) is not a play.
const PLAY_TYPES: Array[String] = ["attack", "defend", "use", "counter", "place", "relic"]
const CONCEDE_BUCKETS: Array[String] = ["1-2", "3-5", "6+"]
const NOTES_MAX: int = 10
const TSV_HEADER: String = "id\tcatalog\tmode\torigin\tdate\tdeck_0\tdeck_1\tfirst\twinner\treason\tturns\tdecisions\tduration_ms\tdisconnects_0\tdisconnects_1\treconnects_0\treconnects_1"

## Filters. `origin` is "server", "client" or "all". `since` and `until` are UTC dates, YYYY-MM-DD,
## both inclusive, "" for open. `catalog_prefix` "" takes every catalog.
var modes: Array[String] = DEFAULT_MODES.duplicate()
var origin: String = "server"
var since: String = ""
var until: String = ""
var catalog_prefix: String = ""
## When set, a server record whose signature this key does not reproduce is skipped.
var verifier: MatchLog = null
## The catalog this build runs. Its group is marked, and the card pass replays only its records.
var current_catalog: String = ""
## Both set turns the card pass on.
var library: CardLibrary = null
var strike_table: StrikeTable = null

var skipped: Dictionary = {}     # reason -> records left out for it
var groups: Dictionary = {}      # catalog -> group, see `_blank_group`
var tsv_rows: Array[String] = []


## One line of a records file. A blank line is ignored; a line that is not JSON, or not a record
## this build accepts, is counted under why. True when the record was counted.
func add_line(text: String) -> bool:
	if text.strip_edges().is_empty():
		return false
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		_skip("not JSON")
		return false
	var record: MatchRecord = MatchRecord.from_dict(json.data)
	if record == null:
		_skip("refused: " + MatchRecord.problem_of(json.data))
		return false
	return add(record)


## Counts `record` when it passes the filters, otherwise files it under the reason. True when counted.
func add(record: MatchRecord) -> bool:
	var left_out: String = skip_reason(record)
	if left_out != "":
		_skip(left_out)
		return false
	var group: Dictionary = _group(record.catalog)
	group["records"] = int(group["records"]) + 1
	group["first_started"] = record.started if int(group["records"]) == 1 else mini(int(group["first_started"]), record.started)
	group["last_started"] = maxi(int(group["last_started"]), record.started)
	var winner: int = int(record.result["winner"])
	var ended: String = str(record.result["reason"])
	var turns: int = int(record.result["turns"])
	var decisions: int = decisions_of(record)
	var duration: int = int(record.result["duration_ms"])
	var opener: int = int(record.first["seat"])
	var labels: Array[String] = [deck_label(record.seats[0]), deck_label(record.seats[1])]

	_bump(group["endings"], ended)
	if ended == "concede":
		var buckets: Array = group["concede_turns"]
		var bucket: int = 0 if turns <= 2 else (1 if turns <= 5 else 2)
		buckets[bucket] = int(buckets[bucket]) + 1
	group["disconnects"] = int(group["disconnects"]) + record.disconnects[0] + record.disconnects[1]
	group["reconnects"] = int(group["reconnects"]) + record.reconnects[0] + record.reconnects[1]
	if winner >= 0:
		_tally(group["first"], winner == opener)

	if labels[0] == labels[1]:
		group["mirrors"] = int(group["mirrors"]) + 1
	else:
		for seat in range(2):
			var row: Dictionary = _deck_row(group, labels[seat])
			row["duels"] = int(row["duels"]) + 1
			row["turns"] = int(row["turns"]) + turns
			row["decisions"] = int(row["decisions"]) + decisions
			row["duration_ms"] = int(row["duration_ms"]) + duration
			if winner == seat:
				row["won"] = int(row["won"]) + 1
				_bump(row["win_by"], ended)
			elif winner < 0:
				row["no_winner"] = int(row["no_winner"]) + 1
			else:
				_bump(row["loss_to"], ended)
			if winner >= 0:
				_tally(row["first"] if seat == opener else row["second"], winner == seat)
			_tally(_cell(group, labels[seat], labels[1 - seat]), winner == seat)

	if record.mode == "ranked":
		_count_ranked(group["ranked"], record, labels)
	if library != null and strike_table != null:
		_count_cards(group, record)
	tsv_rows.append("\t".join(PackedStringArray([record.id, record.catalog, record.mode, record.origin,
		_date(record.started), labels[0], labels[1], str(opener), str(winner), ended, str(turns),
		str(decisions), str(duration), str(record.disconnects[0]), str(record.disconnects[1]),
		str(record.reconnects[0]), str(record.reconnects[1])])))
	return true


## Why `record` is left out under the current filters, or "" when it counts.
func skip_reason(record: MatchRecord) -> String:
	if record.dev:
		return "dev"
	if not record.has_result():
		return "no result"
	if origin != "all" and record.origin != origin:
		return "origin %s" % record.origin
	if not modes.has(record.mode):
		return "mode %s" % record.mode
	var day: String = _date(record.started)
	if since != "" and day < since:
		return "before --since"
	if until != "" and day > until:
		return "after --until"
	if catalog_prefix != "" and not record.catalog.begins_with(catalog_prefix):
		return "another catalog"
	if verifier != null and record.origin == "server" and not verifier.verify(record):
		return "signature does not match --secret"
	return ""


## The group for `catalog`, or an empty dictionary when no record of it was counted.
func group_of(catalog: String) -> Dictionary:
	return groups.get(catalog, {})


func counted() -> int:
	var total: int = 0
	for key in groups.keys():
		total += int((groups[key] as Dictionary)["records"])
	return total


## A catalog deck by its id; an inline deck, as in an adventure run, by its list's name.
static func deck_label(seat: Dictionary) -> String:
	var deck: String = str(seat.get("deck", ""))
	if deck != "":
		return deck
	return "list:" + str((seat.get("list", {}) as Dictionary).get("name", "?"))


## Decisions taken in the duel: every command, dev effects aside.
static func decisions_of(record: MatchRecord) -> int:
	var total: int = 0
	for entry in record.commands:
		if not (entry as Dictionary).has("dev"):
			total += 1
	return total


# --- Ranked -----------------------------------------------------------------

## One ranked game: game 1 notes who won it, and the game that decided the match counts the match
## for both decks, mirrors aside, and by how it was won.
func _count_ranked(ranked: Dictionary, record: MatchRecord, labels: Array[String]) -> void:
	ranked["games"] = int(ranked["games"]) + 1
	if record.game == 1:
		(ranked["game_one"] as Dictionary)[record.match_id] = int(record.result["winner"])
	if record.match_result.is_empty():
		return
	var winner: int = int(record.match_result["winner"])
	ranked["matches"] = int(ranked["matches"]) + 1
	(ranked["decided"] as Dictionary)[record.match_id] = winner
	if winner < 0:
		ranked["no_winner"] = int(ranked["no_winner"]) + 1
		return
	var wins: Array = record.match_result["wins"]
	var shape: String = "short"
	if int(wins[winner]) == 2:
		shape = "two_nil" if int(wins[1 - winner]) == 0 else ("two_one" if int(wins[1 - winner]) == 1 else "short")
	ranked[shape] = int(ranked[shape]) + 1
	if labels[0] == labels[1]:
		ranked["mirrors"] = int(ranked["mirrors"]) + 1
		return
	var decks: Dictionary = ranked["decks"]
	for seat in range(2):
		if not decks.has(labels[seat]):
			decks[labels[seat]] = [0, 0]
		_tally(decks[labels[seat]], winner == seat)


## [matches whose game 1 winner took the match, matches with a winner whose game 1 had one too].
static func _game_one_takes(ranked: Dictionary) -> Array[int]:
	var out: Array[int] = [0, 0]
	var game_one: Dictionary = ranked["game_one"]
	var decided: Dictionary = ranked["decided"]
	for id in decided.keys():
		var first: int = int(game_one.get(id, -1))
		if int(decided[id]) < 0 or first < 0:
			continue
		out[1] += 1
		if first == int(decided[id]):
			out[0] += 1
	return out


func _ranked_text(ranked: Dictionary, out: PackedStringArray) -> void:
	var matches: int = int(ranked["matches"])
	out.append("")
	out.append("RANKED  (%d match%s decided from %d games, %d with no winner; mirror matches left out of the rows: %d)" % [
		matches, "" if matches == 1 else "es", int(ranked["games"]), int(ranked["no_winner"]), int(ranked["mirrors"])])
	var decks: Dictionary = ranked["decks"]
	var labels: Array[String] = []
	for key in decks.keys():
		labels.append(str(key))
	labels.sort_custom(func(x: String, y: String) -> bool:
		var rx: float = float(int(decks[x][0])) / float(maxi(1, int(decks[x][1])))
		var ry: float = float(int(decks[y][0])) / float(maxi(1, int(decks[y][1])))
		return rx > ry if rx != ry else x < y)
	out.append("%-20s %7s %s" % ["deck", "matches", "match win% (95% range)"])
	for label in labels:
		out.append("%-20s %7d %s" % [label, int(decks[label][1]), SimReport.rate_text(int(decks[label][0]), int(decks[label][1]))])
	var won: int = int(ranked["two_nil"]) + int(ranked["two_one"]) + int(ranked["short"])
	var per: float = 100.0 / float(maxi(1, won))
	out.append("won 2-0: %d (%.1f%%), won 2-1: %d (%.1f%%), ended early: %d (%.1f%%)" % [int(ranked["two_nil"]),
		float(int(ranked["two_nil"])) * per, int(ranked["two_one"]), float(int(ranked["two_one"])) * per,
		int(ranked["short"]), float(int(ranked["short"])) * per])
	var takes: Array[int] = _game_one_takes(ranked)
	out.append("the game 1 winner took the match %d of %d: %s" % [takes[0], takes[1], SimReport.rate_text(takes[0], takes[1]).strip_edges()])


func _ranked_json(ranked: Dictionary) -> Dictionary:
	var decks: Dictionary = {}
	for label in (ranked["decks"] as Dictionary).keys():
		decks[label] = _rate_json((ranked["decks"] as Dictionary)[label])
	return {"games": int(ranked["games"]), "matches": int(ranked["matches"]), "no_winner": int(ranked["no_winner"]),
		"mirrors": int(ranked["mirrors"]), "decks": decks, "two_nil": int(ranked["two_nil"]),
		"two_one": int(ranked["two_one"]), "ended_early": int(ranked["short"]), "game_one_takes": _rate_json(_game_one_takes(ranked))}


# --- Card pass --------------------------------------------------------------

## Replays the duel from its seed and commands, then reads the card behind each command that put
## one to use. A card counts for its owner's seat; a duel counts once per seat that played it.
func _count_cards(group: Dictionary, record: MatchRecord) -> void:
	if record.catalog != current_catalog:
		group["cards_other_catalog"] = int(group["cards_other_catalog"]) + 1
		return
	var winner: int = int(record.result["winner"])
	var referee: Referee = record.setup_referee(library, strike_table, false)
	var problem: String = ""
	if referee == null:
		problem = "a deck is not in this build"
	else:
		problem = referee.replay(record.commands)
		if problem == "" and RULES_REASONS.has(str(record.result["reason"])) and referee.engine.state.winner != winner:
			problem = "the replay ended with another winner"
	if problem != "":
		group["cards_failed"] = int(group["cards_failed"]) + 1
		var notes: Array = group["card_notes"]
		if notes.size() < NOTES_MAX:
			notes.append("%s: %s" % [record.id, problem.left(160)])
		return
	group["cards_replayed"] = int(group["cards_replayed"]) + 1
	var seen: Array[Dictionary] = [{}, {}]
	for entry in record.commands:
		var command: Dictionary = entry
		if command.has("dev") or not PLAY_TYPES.has(str(command["type"])):
			continue
		var seat: int = int(command["player"])
		var card: CardInstance = referee.engine.card(int(command["card"]))
		if card == null or card.owner != seat:
			continue
		var row: Dictionary = _card_row(group, card.def.id)
		row["played"] = int(row["played"]) + 1
		seen[seat][card.def.id] = true
	for seat in range(2):
		for id in seen[seat].keys():
			var row: Dictionary = _card_row(group, str(id))
			row["duels"] = int(row["duels"]) + 1
			if winner == seat:
				row["won"] = int(row["won"]) + 1


# --- Text -------------------------------------------------------------------

## The report as text in matchlab's layout: what was skipped, then one block per catalog group,
## oldest first.
func to_text() -> String:
	var out: PackedStringArray = PackedStringArray()
	var skipped_total: int = 0
	for key in skipped.keys():
		skipped_total += int(skipped[key])
	out.append("%d records counted in %d catalog group%s, %d skipped" % [
		counted(), groups.size(), "" if groups.size() == 1 else "s", skipped_total])
	for reason in _by_count(skipped):
		out.append("  skipped %5d  %s" % [int(skipped[reason]), reason])
	for group in _ordered_groups():
		_group_text(group, out)
	return "\n".join(out)


func _group_text(group: Dictionary, out: PackedStringArray) -> void:
	var catalog: String = str(group["catalog"])
	var records: int = int(group["records"])
	out.append("")
	out.append("=== catalog %s: %d record%s, %s to %s%s ===" % [
		catalog.left(12) if catalog != "" else "(none)", records, "" if records == 1 else "s",
		_date(int(group["first_started"])), _date(int(group["last_started"])),
		", this build" if catalog == current_catalog and catalog != "" else ""])

	var decks: Dictionary = group["decks"]
	var ordered: Array[String] = _by_win_rate(decks)
	out.append("")
	out.append("DECKS  (mirror duels left out: %d)" % int(group["mirrors"]))
	out.append("%-20s %6s %-20s  %-12s %-12s %4s %6s %9s %7s" % [
		"deck", "duels", "win% (95% range)", "won by", "lost to", "none", "turns", "decisions", "minutes"])
	for label in ordered:
		var row: Dictionary = decks[label]
		var n: float = float(maxi(1, int(row["duels"])))
		out.append("%-20s %6d %-20s  %-12s %-12s %4d %6.1f %9.1f %7.1f" % [
			label, int(row["duels"]), SimReport.rate_text(int(row["won"]), int(row["duels"])),
			_counts_of(row["win_by"]), _counts_of(row["loss_to"]), int(row["no_winner"]),
			float(int(row["turns"])) / n, float(int(row["decisions"])) / n,
			float(int(row["duration_ms"])) / 60000.0 / n])
	out.append("won by / lost to: %s; a concede, timeout or left is the loser's" % "/".join(PackedStringArray(DECIDED)))

	var matchup: Dictionary = group["matchup"]
	if not matchup.is_empty():
		var names: Array[String] = []
		for key in decks.keys():
			names.append(str(key))
		names.sort()
		out.append("")
		out.append("MATCHUPS  (row deck's win% against the column deck, from both seats, n in brackets)")
		var head: PackedStringArray = ["%-20s" % "row \\ column"]
		for name in names:
			head.append("%12s" % name.left(12))
		out.append(" ".join(head))
		for row_name in names:
			var line: PackedStringArray = ["%-20s" % row_name]
			var cells: Dictionary = matchup.get(row_name, {})
			for col_name in names:
				var cell: Array = cells.get(col_name, [0, 0])
				if int(cell[1]) == 0:
					line.append("%12s" % "-")
				else:
					line.append("%8.0f%%[%d]" % [100.0 * float(int(cell[0])) / float(int(cell[1])), int(cell[1])])
			out.append(" ".join(line))

	var first: Array = group["first"]
	out.append("")
	out.append("FIRST PLAYER  (duels with a winner, mirrors included)")
	out.append("the seat that went first won %d of %d: %s" % [
		int(first[0]), int(first[1]), SimReport.rate_text(int(first[0]), int(first[1])).strip_edges()])
	out.append("%-20s %6s %-20s   %6s %s" % ["deck", "first", "win% (95% range)", "second", "win% (95% range)"])
	for label in ordered:
		var row: Dictionary = decks[label]
		var on: Array = row["first"]
		var off: Array = row["second"]
		out.append(("%-20s %6d %-20s   %6d %-20s" % [label, int(on[1]), SimReport.rate_text(int(on[0]), int(on[1])),
			int(off[1]), SimReport.rate_text(int(off[0]), int(off[1]))]).rstrip(" "))

	var endings: Dictionary = group["endings"]
	var buckets: Array = group["concede_turns"]
	var per: float = 100.0 / float(maxi(1, records))
	out.append("")
	out.append("ENDINGS  (%d duel%s)" % [records, "" if records == 1 else "s"])
	for reason in MatchRecord.RESULT_REASONS:
		var n: int = int(endings.get(reason, 0))
		out.append("%-10s %6d %6.1f%%" % [reason, n, float(n) * per])
	out.append("conceded on turn %s: %d, %s: %d, %s: %d" % [CONCEDE_BUCKETS[0], int(buckets[0]),
		CONCEDE_BUCKETS[1], int(buckets[1]), CONCEDE_BUCKETS[2], int(buckets[2])])
	out.append("per 100 duels: %.1f disconnects, %.1f reconnects" % [
		float(int(group["disconnects"])) * per, float(int(group["reconnects"])) * per])

	if int((group["ranked"] as Dictionary)["games"]) > 0:
		_ranked_text(group["ranked"], out)

	if library == null or strike_table == null:
		return
	out.append("")
	out.append("CARDS  (%d duels replayed; a duel counts once for each seat that played the card)" % int(group["cards_replayed"]))
	if int(group["cards_other_catalog"]) > 0:
		out.append("%d duels were recorded on another catalog and not replayed" % int(group["cards_other_catalog"]))
	if int(group["cards_failed"]) > 0:
		out.append("%d duels could not be replayed:" % int(group["cards_failed"]))
		for note in group["card_notes"]:
			out.append("  %s" % str(note))
	var cards: Dictionary = group["cards"]
	if cards.is_empty():
		return
	out.append("%-28s %6s %6s %s" % ["card", "played", "duels", "win% (95% range)"])
	for id in _by_use(cards):
		var row: Dictionary = cards[id]
		out.append("%-28s %6d %6d %s" % [id, int(row["played"]), int(row["duels"]),
			SimReport.rate_text(int(row["won"]), int(row["duels"]))])


# --- Files ------------------------------------------------------------------

## One row per counted duel.
func to_tsv() -> String:
	var out: PackedStringArray = PackedStringArray([TSV_HEADER])
	out.append_array(PackedStringArray(tsv_rows))
	return "\n".join(out) + "\n"


func to_json() -> Dictionary:
	var out_groups: Array[Dictionary] = []
	for group in _ordered_groups():
		out_groups.append(_group_json(group))
	return {"version": 1, "counted": counted(), "skipped": skipped.duplicate(), "groups": out_groups}


func _group_json(group: Dictionary) -> Dictionary:
	var records: int = int(group["records"])
	var per: float = 100.0 / float(maxi(1, records))
	var decks: Dictionary = {}
	for label in (group["decks"] as Dictionary).keys():
		var row: Dictionary = (group["decks"] as Dictionary)[label]
		var n: float = float(maxi(1, int(row["duels"])))
		var overall: Dictionary = _rate_json([int(row["won"]), int(row["duels"])])
		decks[label] = {"duels": int(row["duels"]), "won": int(row["won"]), "win_rate": overall["rate"],
			"win_low": overall["low"], "win_high": overall["high"], "no_winner": int(row["no_winner"]),
			"mean_turns": float(int(row["turns"])) / n, "mean_decisions": float(int(row["decisions"])) / n,
			"mean_minutes": float(int(row["duration_ms"])) / 60000.0 / n,
			"win_by": (row["win_by"] as Dictionary).duplicate(), "loss_to": (row["loss_to"] as Dictionary).duplicate(),
			"first": _rate_json(row["first"]), "second": _rate_json(row["second"])}
	var matchups: Dictionary = {}
	for row_name in (group["matchup"] as Dictionary).keys():
		var cells: Dictionary = (group["matchup"] as Dictionary)[row_name]
		var out_cells: Dictionary = {}
		for col_name in cells.keys():
			out_cells[col_name] = _rate_json(cells[col_name])
		matchups[row_name] = out_cells
	var cards: Dictionary = {}
	for id in (group["cards"] as Dictionary).keys():
		var row: Dictionary = (group["cards"] as Dictionary)[id]
		var rate: Dictionary = _rate_json([int(row["won"]), int(row["duels"])])
		cards[id] = {"played": int(row["played"]), "duels": int(row["duels"]), "won": int(row["won"]),
			"win_rate": rate["rate"], "win_low": rate["low"], "win_high": rate["high"]}
	var buckets: Array = group["concede_turns"]
	var catalog: String = str(group["catalog"])
	var out: Dictionary = {
		"catalog": catalog, "this_build": catalog == current_catalog and catalog != "",
		"records": records, "first_date": _date(int(group["first_started"])), "last_date": _date(int(group["last_started"])),
		"mirrors": int(group["mirrors"]), "decks": decks, "matchups": matchups,
		"first_player": _rate_json(group["first"]),
		"endings": (group["endings"] as Dictionary).duplicate(),
		"concede_turns": {CONCEDE_BUCKETS[0]: int(buckets[0]), CONCEDE_BUCKETS[1]: int(buckets[1]), CONCEDE_BUCKETS[2]: int(buckets[2])},
		"disconnects_per_100": float(int(group["disconnects"])) * per,
		"reconnects_per_100": float(int(group["reconnects"])) * per,
		"cards": cards, "cards_replayed": int(group["cards_replayed"]), "cards_failed": int(group["cards_failed"]),
		"cards_other_catalog": int(group["cards_other_catalog"]), "card_notes": (group["card_notes"] as Array).duplicate(),
	}
	if int((group["ranked"] as Dictionary)["games"]) > 0:
		out["ranked"] = _ranked_json(group["ranked"])
	return out


func _rate_json(pair: Array) -> Dictionary:
	var won: int = int(pair[0])
	var n: int = int(pair[1])
	var bounds: Array[float] = SimReport.wilson(won, n)
	return {"won": won, "duels": n, "rate": float(won) / float(maxi(1, n)), "low": bounds[0], "high": bounds[1]}


# --- Internals --------------------------------------------------------------

static func _blank_group(catalog: String) -> Dictionary:
	return {
		"catalog": catalog, "records": 0, "first_started": 0, "last_started": 0, "mirrors": 0,
		"decks": {},             # label -> deck row
		"matchup": {},           # row label -> column label -> [row wins, duels]
		"first": [0, 0],         # [opener won, duels with a winner]
		"endings": {},           # result reason -> duels
		"concede_turns": [0, 0, 0],
		"disconnects": 0, "reconnects": 0,
		"cards": {},             # card id -> {"played", "duels", "won"}
		"cards_replayed": 0, "cards_failed": 0, "cards_other_catalog": 0, "card_notes": [],
		"ranked": {"games": 0, "matches": 0, "no_winner": 0, "mirrors": 0, "two_nil": 0, "two_one": 0, "short": 0,
			"decks": {},         # label -> [matches won, matches with a winner]
			"game_one": {},      # match id -> game 1's winner
			"decided": {}},      # match id -> the match's winner
	}


func _group(catalog: String) -> Dictionary:
	if not groups.has(catalog):
		groups[catalog] = _blank_group(catalog)
	return groups[catalog]


func _deck_row(group: Dictionary, label: String) -> Dictionary:
	var decks: Dictionary = group["decks"]
	if not decks.has(label):
		decks[label] = {"duels": 0, "won": 0, "no_winner": 0, "turns": 0, "decisions": 0, "duration_ms": 0,
			"win_by": {}, "loss_to": {}, "first": [0, 0], "second": [0, 0]}
	return decks[label]


func _cell(group: Dictionary, row_name: String, col_name: String) -> Array:
	var matchup: Dictionary = group["matchup"]
	if not matchup.has(row_name):
		matchup[row_name] = {}
	var cells: Dictionary = matchup[row_name]
	if not cells.has(col_name):
		cells[col_name] = [0, 0]
	return cells[col_name]


func _card_row(group: Dictionary, id: String) -> Dictionary:
	var cards: Dictionary = group["cards"]
	if not cards.has(id):
		cards[id] = {"played": 0, "duels": 0, "won": 0}
	return cards[id]


func _ordered_groups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in groups.keys():
		out.append(groups[key])
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(x["first_started"]) < int(y["first_started"]))
	return out


func _by_win_rate(decks: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in decks.keys():
		out.append(str(key))
	out.sort_custom(func(x: String, y: String) -> bool:
		var rx: float = float(int(decks[x]["won"])) / float(maxi(1, int(decks[x]["duels"])))
		var ry: float = float(int(decks[y]["won"])) / float(maxi(1, int(decks[y]["duels"])))
		return rx > ry if rx != ry else x < y)
	return out


func _by_use(cards: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in cards.keys():
		out.append(str(key))
	out.sort_custom(func(x: String, y: String) -> bool:
		var dx: int = int(cards[x]["duels"])
		var dy: int = int(cards[y]["duels"])
		if dx != dy:
			return dx > dy
		var px: int = int(cards[x]["played"])
		var py: int = int(cards[y]["played"])
		return px > py if px != py else x < y)
	return out


func _by_count(counts: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in counts.keys():
		out.append(str(key))
	out.sort_custom(func(x: String, y: String) -> bool:
		return int(counts[x]) > int(counts[y]) if int(counts[x]) != int(counts[y]) else x < y)
	return out


func _counts_of(counts: Dictionary) -> String:
	var out: PackedStringArray = PackedStringArray()
	for r in DECIDED:
		out.append(str(int(counts.get(r, 0))))
	return "/".join(out)


func _skip(reason: String) -> void:
	skipped[reason] = int(skipped.get(reason, 0)) + 1


static func _bump(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


static func _tally(pair: Array, won: bool) -> void:
	pair[0] = int(pair[0]) + (1 if won else 0)
	pair[1] = int(pair[1]) + 1


static func _date(unix: int) -> String:
	return Time.get_date_string_from_unix_time(unix)
