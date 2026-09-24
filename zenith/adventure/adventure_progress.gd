class_name AdventureProgress
extends RefCounted
## School and personality XP (design doc 8.3 and 8.4), kept in user://adventure/progress.json, and
## the one place a reward from XP or an achievement is granted. Numbers and authored milestones
## live in data/adventure/progression.json.

const PATH: String = "user://adventure/progress.json"
const DATA: String = "res://data/adventure/progression.json"
const SAVE_VERSION: int = 1
const EXCLUDED_POOL_TYPES: Array[int] = [
	CardDef.Type.PERSONALITY, CardDef.Type.MASTERY, CardDef.Type.SEAL, CardDef.Type.RELIC,
	CardDef.Type.GROUNDS,
]

## Tests point this somewhere else so nothing lands on the player's save.
static var path_override: String = ""

var school_xp: Dictionary = {}        # school -> XP
var personality_xp: Dictionary = {}   # character -> XP
## "school:<school>" or "personality:<character>" -> the highest level already paid out.
var paid: Dictionary = {}
## school -> how many cards of its pool have been handed out, across passes.
var school_cursor: Dictionary = {}


static func path() -> String:
	return path_override if path_override != "" else PATH


static func data() -> Dictionary:
	if not FileAccess.file_exists(DATA):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return parsed if parsed is Dictionary else {}


## The level `xp` stands at on `curve`, 1 at 0 XP. Past the curve's end, each level costs
## `step` more than the last threshold.
static func level_of(xp: int, curve: Array, step: int) -> int:
	var level: int = 0
	for threshold in curve:
		if xp >= int(threshold):
			level += 1
	if level == curve.size() and step > 0 and not curve.is_empty():
		level += (xp - int(curve[curve.size() - 1])) / step
	return maxi(1, level)


func school_level(school: String) -> int:
	var d: Dictionary = data()
	return level_of(int(school_xp.get(school, 0)), d.get("school_levels", [0]), int(d.get("past_end_step", 0)))


func personality_level(character: String) -> int:
	var d: Dictionary = data()
	return level_of(int(personality_xp.get(character, 0)), d.get("personality_levels", [0]), int(d.get("past_end_step", 0)))


# --- A new run --------------------------------------------------------------

## Fills in what a new run carries from the meta save: the main's owned Aspect cards above its
## starting stack, and a starting Relic and Reserve (from the character's own precon) when the
## character has earned them. A Relic the starter already prints is kept, and a result the
## validator refuses is dropped.
static func prepare_run(run: AdventureRun, library: CardLibrary, collection: AdventureCollection,
		unlocks: AdventureUnlocks) -> void:
	var family: String = AdventureDecks.family_of(run.starter_id)
	var main: String = AdventureDecks.character_of(family)
	run.owned_aspects.clear()
	for id in collection.all_ids():
		var def: CardDef = library.defs.get(id)
		if def != null and def.is_personality() and def.character == main and not run.duelist_ids.has(id):
			run.owned_aspects.append(id)
	var own: DeckList = run.deck()
	if own == null or own.relic_id != "" or not unlocks.has_ability(main, AdventureUnlocks.ABILITY_RELIC):
		return
	var precon_path: String = "res://data/decks/%s.json" % family
	if not FileAccess.file_exists(precon_path):
		return
	var precon: DeckList = DeckList.load_from(precon_path)
	if precon.relic_id == "":
		return
	run.relic_id = precon.relic_id
	run.reserve.clear()
	if unlocks.has_ability(main, AdventureUnlocks.ABILITY_RESERVE):
		run.reserve = precon.reserve.duplicate()
	if not DeckValidator.validate(run.deck(), library).is_empty():
		run.relic_id = ""
		run.reserve.clear()


# --- One won duel -------------------------------------------------------------

## Everything a won duel pays outside the run's own rewards, applied in order: a storyline join,
## XP and the levels it reaches, then achievements. Returns one line per thing that happened, for
## the screen after the duel. Nothing here saves; the caller does.
static func record_win(run: AdventureRun, map: AdventureMap, engine: DuelEngine,
		library: CardLibrary, collection: AdventureCollection, unlocks: AdventureUnlocks,
		progress: AdventureProgress, wallet: AdventureWallet) -> Array[String]:
	var lines: Array[String] = []
	var joined: String = AdventureStory.apply_boss_win(run, map, library)
	if joined != "":
		lines.append("%s joins your deck." % library.get_def(joined).title)
	var result: Dictionary = duel_result(run, map, engine)
	for levelup in progress.award(result):
		var key: String = str(levelup["key"])
		var school: bool = str(levelup["kind"]) == "school"
		var granted: Array[String] = grant(progress.reward_for(levelup, library), "" if school else key,
			library, collection, unlocks, wallet, run)
		var head: String = "%s reaches level %d" % [key.capitalize() if school else key, int(levelup["level"])]
		lines.append(head + (": " + ", ".join(granted) if not granted.is_empty() else "."))
	var events: Array[Dictionary] = [result]
	if bool(result["run_won"]):
		events.append({"event": "run_won", "main": result["main"], "starter": run.starter_id})
	for a in AdventureAchievements.apply(unlocks, events):
		var granted: Array[String] = grant(a, str(a.get("character", "")), library, collection,
			unlocks, wallet, run)
		var head: String = "Achievement: %s" % str(a.get("title", a.get("id", "")))
		lines.append(head + (" (" + ", ".join(granted) + ")" if not granted.is_empty() else ""))
	return lines

## What a won duel on the run's current node amounts to, for XP and achievements. `engine` is the
## duel's own engine, read for what was in play at the end and the tallies it kept; null leaves
## those empty.
static func duel_result(run: AdventureRun, map: AdventureMap, engine: DuelEngine) -> Dictionary:
	var here: Dictionary = map.node(run.node_id)
	var opponent_id: String = str(map.duel_for(run.node_id).get("opponent", ""))
	var main: String = AdventureDecks.character_of(AdventureDecks.family_of(run.starter_id))
	var allies: Array[String] = []
	var blocks: int = 0
	var aspect: int = run.duelist_ids.size() if run.duelist_ids.size() > 0 else 1
	if engine != null and engine.state != null and not engine.state.players.is_empty():
		var p: PlayerState = engine.state.players[0]
		for c in p.in_play:
			if c.def.is_personality() and c.def.character != "" and c.def.character != main \
					and not allies.has(c.def.character):
				allies.append(c.def.character)
		blocks = int((engine.tallies["blocks"] as Array)[0])
		aspect = maxi(p.duelist.aspect, int((engine.tallies["peak_aspect"] as Array)[0]))
	var d: DeckList = run.deck()
	return {
		"event": "duel_won",
		"main": main,
		"starter": run.starter_id,
		"school": d.style if d != null else "",
		"node": str(here.get("type", "")),
		"act": int(here.get("act", 0)),
		"opponent": AdventureDecks.character_of(AdventureDecks.family_of(opponent_id)),
		"allies": allies,
		"blocks": blocks,
		"aspect": aspect,
		"run_won": run.node_id == map.final_id(),
	}


## Adds the XP a won duel is worth. Returns the levels newly reached, lowest first:
## {"kind": "school" or "personality", "key": school or character, "level": int}.
func award(result: Dictionary) -> Array[Dictionary]:
	var xp: Dictionary = data().get("xp", {})
	var boss: bool = str(result.get("node", "")) == "boss"
	var run_won: bool = bool(result.get("run_won", false))
	var before: Dictionary = _levels_snapshot()
	var main: String = str(result.get("main", ""))
	if main != "":
		var gain: int = int(xp.get("main_boss" if boss else "main_duel", 0))
		if run_won:
			gain += int(xp.get("main_run", 0))
		_add(personality_xp, main, gain)
	for who in result.get("allies", []):
		_add(personality_xp, str(who), int(xp.get("ally_in_play", 0)))
	var beaten: String = str(result.get("opponent", ""))
	if beaten != "" and beaten != main:
		_add(personality_xp, beaten, int(xp.get("beaten_boss" if boss else "beaten_duel", 0)))
	var school: String = str(result.get("school", ""))
	if school != "":
		var school_gain: int = int(xp.get("school_boss" if boss else "school_duel", 0))
		if run_won:
			school_gain += int(xp.get("school_run", 0))
		_add(school_xp, school, school_gain)
	return _levels_gained(before)


static func _add(book: Dictionary, key: String, amount: int) -> void:
	if key == "" or amount <= 0:
		return
	book[key] = int(book.get(key, 0)) + amount


func _levels_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for school in school_xp.keys():
		out["school:%s" % school] = school_level(str(school))
	for character in personality_xp.keys():
		out["personality:%s" % character] = personality_level(str(character))
	return out


## Every level above what `paid` records, which is also above `before`, marked paid.
func _levels_gained(before: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in _levels_snapshot().keys():
		var kind: String = str(key).get_slice(":", 0)
		var name: String = str(key).substr(kind.length() + 1)
		var now: int = school_level(name) if kind == "school" else personality_level(name)
		var from: int = maxi(int(paid.get(key, 1)), int(before.get(key, 1)))
		for level in range(from + 1, now + 1):
			out.append({"kind": kind, "key": name, "level": level})
		if now > int(paid.get(key, 1)):
			paid[key] = now
	return out


# --- Rewards ----------------------------------------------------------------

## What reaching `levelup` gives, as a reward dictionary for `grant`.
func reward_for(levelup: Dictionary, library: CardLibrary) -> Dictionary:
	var key: String = str(levelup.get("key", ""))
	var level: int = int(levelup.get("level", 0))
	var d: Dictionary = data()
	if str(levelup.get("kind", "")) == "school":
		var cards: Array[String] = _next_school_batch(key, int(d.get("school_batch", 3)), library)
		if _int_list(d.get("mastery_levels", [])).has(level):
			var mastery: String = _mastery_for(key, level, d, library)
			if mastery != "":
				cards.append(mastery)
		return {"cards": cards}
	var track: Dictionary = (d.get("tracks", {}) as Dictionary).get(key, {})
	if not track.is_empty():
		return track.get(str(level), {})
	return {"signatures": 2}


## The school's pool in the order it is handed out: cards printed at higher limits first, then by
## id. Freestyle's pool is the cards of no school.
static func school_pool(school: String, library: CardLibrary) -> Array[String]:
	var wanted: String = "" if school == "freestyle" else school
	var defs: Array[CardDef] = []
	for id in library.all_ids():
		var def: CardDef = library.defs[id]
		if def.school != wanted or EXCLUDED_POOL_TYPES.has(int(def.type)):
			continue
		defs.append(def)
	defs.sort_custom(func(a: CardDef, b: CardDef) -> bool:
		if a.limit_per_deck != b.limit_per_deck:
			return a.limit_per_deck > b.limit_per_deck
		return a.id < b.id)
	var out: Array[String] = []
	for def in defs:
		out.append(def.id)
	return out


func _next_school_batch(school: String, size: int, library: CardLibrary) -> Array[String]:
	var pool: Array[String] = school_pool(school, library)
	var out: Array[String] = []
	if pool.is_empty():
		return out
	var cursor: int = int(school_cursor.get(school, 0))
	for i in range(size):
		out.append(pool[(cursor + i) % pool.size()])
	school_cursor[school] = cursor + size
	return out


## The school's Masteries in id order; the Nth mastery level gives the Nth.
static func _mastery_for(school: String, level: int, d: Dictionary, library: CardLibrary) -> String:
	var wanted: String = "" if school == "freestyle" else school
	var masteries: Array[String] = []
	for id in library.all_ids():
		var def: CardDef = library.defs[id]
		if def.type == CardDef.Type.MASTERY and def.school == wanted:
			masteries.append(id)
	masteries.sort()
	var index: int = _int_list(d.get("mastery_levels", [])).find(level)
	return masteries[index] if index >= 0 and index < masteries.size() else ""


## JSON hands numbers back as floats, which `has` and `find` do not match against an int.
static func _int_list(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v in values:
		out.append(int(v))
	return out


## Grants a reward from a level or an achievement: `cards` into the collection (past the cap they
## dust into Motes), `signatures` (that many of the character's own named cards the collection
## lacks, in id order), `starter` opened, `abilities` for `character`. A personality card of the
## run's own character also becomes climbable in that run. Returns one line per thing granted.
static func grant(reward: Dictionary, character: String, library: CardLibrary,
		collection: AdventureCollection, unlocks: AdventureUnlocks, wallet: AdventureWallet,
		run: AdventureRun = null) -> Array[String]:
	var lines: Array[String] = []
	var cards: Array[String] = []
	for id in reward.get("cards", []):
		cards.append(str(id))
	var want: int = int(reward.get("signatures", 0))
	if want > 0:
		cards.append_array(_missing_signatures(character, want, library, collection))
	for id in cards:
		if not library.has(id):
			continue
		var report: Dictionary = collection.bank(id, 1, library, wallet)
		var def: CardDef = library.get_def(id)
		if int(report.get("added", 0)) > 0:
			lines.append(def.title if def.aspect_title == "" else "%s, %s" % [def.title, def.aspect_title])
		elif int(report.get("motes", 0)) > 0:
			lines.append("%s (dusted for %d Motes)" % [def.title, int(report["motes"])])
		if run != null and def.is_personality() and not run.owned_aspects.has(id):
			var main: String = AdventureDecks.character_of(AdventureDecks.family_of(run.starter_id))
			if def.character == main:
				run.owned_aspects.append(id)
	var starter: String = str(reward.get("starter", ""))
	if starter != "" and unlocks.unlock(starter):
		var deck: DeckList = DeckList.resolve(starter)
		lines.append("Unlocked: %s" % (deck.name if deck != null else starter))
	for ability in reward.get("abilities", []):
		if unlocks.grant_ability(character, str(ability)):
			lines.append(ability_name(str(ability)))
	return lines


static func ability_name(ability: String) -> String:
	match ability:
		AdventureUnlocks.ABILITY_RELIC:
			return "Starts runs with a Relic"
		AdventureUnlocks.ABILITY_RESERVE:
			return "Starts runs with a Reserve"
	return ability


static func _missing_signatures(character: String, n: int, library: CardLibrary,
		collection: AdventureCollection) -> Array[String]:
	var ids: Array[String] = []
	for id in library.all_ids():
		var def: CardDef = library.defs[id]
		if def.character == character and not def.is_personality() and collection.copies(id) == 0:
			ids.append(id)
	ids.sort()
	return ids.slice(0, n)


## Cards only XP milestones or achievements give: every card a track or an achievement names. The
## vendor never stocks them.
static func exclusive_ids() -> Array[String]:
	var out: Array[String] = []
	for track in (data().get("tracks", {}) as Dictionary).values():
		for level in (track as Dictionary).values():
			for id in (level as Dictionary).get("cards", []):
				if not out.has(str(id)):
					out.append(str(id))
	for a in AdventureAchievements.all():
		for id in a.get("cards", []):
			if not out.has(str(id)):
				out.append(str(id))
	return out


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"school_xp": school_xp.duplicate(),
		"personality_xp": personality_xp.duplicate(),
		"paid": paid.duplicate(),
		"school_cursor": school_cursor.duplicate(),
	}


static func from_dict(d: Dictionary) -> AdventureProgress:
	var p: AdventureProgress = AdventureProgress.new()
	for field in ["school_xp", "personality_xp", "paid", "school_cursor"]:
		var src: Dictionary = d.get(field, {})
		var dst: Dictionary = p.get(field)
		for k in src.keys():
			dst[str(k)] = int(src[k])
	return p


static func load_progress() -> AdventureProgress:
	var file: String = path()
	if not FileAccess.file_exists(file):
		return AdventureProgress.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not (parsed is Dictionary):
		push_error("AdventureProgress: %s is not a JSON object" % file)
		return AdventureProgress.new()
	return AdventureProgress.from_dict(parsed)


func save() -> bool:
	var file: String = AdventureProgress.path()
	var dir: String = file.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var handle: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	if handle == null:
		push_error("AdventureProgress: cannot write %s" % file)
		return false
	handle.store_string(JSON.stringify(to_dict(), "  "))
	handle.close()
	return true


static func clear() -> void:
	var file: String = path()
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
