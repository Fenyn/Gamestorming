class_name AdventureProgress
extends RefCounted
## School and personality XP (design doc 8.3, 8.4), saved in user://adventure/progress.json, and
## the one place an XP or achievement reward is granted.

const PATH: String = "user://adventure/progress.json"
const DATA: String = "res://data/adventure/progression.json"
const SAVE_VERSION: int = 1
const EXCLUDED_POOL_TYPES: Array[int] = [
	CardDef.Type.PERSONALITY, CardDef.Type.MASTERY, CardDef.Type.SEAL, CardDef.Type.RELIC,
	CardDef.Type.GROUNDS,
]

static var path_override: String = ""

var school_xp: Dictionary = {}
var personality_xp: Dictionary = {}
## "school:<school>" or "personality:<character>" -> the highest level already paid out.
var paid: Dictionary = {}
## school -> cards of its pool handed out so far, across passes.
var school_cursor: Dictionary = {}
## key -> XP the last `award` added, for the screen after a win. Not saved.
var last_gains: Dictionary = {}
## The tutorial: the lesson it resumes at (0 before it was ever begun), and whether the whole
## session was once played to its end.
var tutorial_lesson: int = 0
var tutorial_done: bool = false


static func path() -> String:
	return path_override if path_override != "" else PATH


static func data() -> Dictionary:
	if not FileAccess.file_exists(DATA):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return parsed if parsed is Dictionary else {}


# --- Levels -------------------------------------------------------------------

## Past the curve's end, each level costs `step` more.
static func level_of(xp: int, curve: Array, step: int) -> int:
	var level: int = 0
	for threshold in curve:
		if xp >= int(threshold):
			level += 1
	if level == curve.size() and step > 0 and not curve.is_empty():
		level += (xp - int(curve[curve.size() - 1])) / step
	return maxi(1, level)


static func threshold_of(level: int, curve: Array, step: int) -> int:
	if curve.is_empty():
		return 0
	if level <= curve.size():
		return int(curve[maxi(0, level - 1)])
	return int(curve[curve.size() - 1]) + (level - curve.size()) * step


## {level, xp, from, to}: the XP the current level began at and the next one starts at.
static func standing(xp: int, curve: Array, step: int) -> Dictionary:
	var level: int = level_of(xp, curve, step)
	return {"level": level, "xp": xp, "from": threshold_of(level, curve, step),
		"to": threshold_of(level + 1, curve, step)}


func school_standing(school: String) -> Dictionary:
	var d: Dictionary = data()
	return standing(int(school_xp.get(school, 0)), d.get("school_levels", [0]), int(d.get("past_end_step", 0)))


## The standing any XP total would have on the school or personality curve.
func standing_of(kind: String, xp: int) -> Dictionary:
	var d: Dictionary = data()
	var curve: Array = d.get("school_levels", [0]) if kind == "school" else d.get("personality_levels", [0])
	return standing(xp, curve, int(d.get("past_end_step", 0)))


## A gain from `from_xp` to `to_xp` cut at each level it crosses, for a bar that fills level by
## level: [{level, from, to, start, end}], `from`/`to` the level's bounds, `start`/`end` the fill.
func xp_segments(kind: String, from_xp: int, to_xp: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var xp: int = from_xp
	while true:
		var s: Dictionary = standing_of(kind, xp)
		var end: int = mini(to_xp, int(s["to"]))
		out.append({"level": int(s["level"]), "from": int(s["from"]), "to": int(s["to"]), "start": xp, "end": end})
		if end >= to_xp or int(s["to"]) <= xp:
			break
		xp = int(s["to"])
	return out


func personality_standing(character: String) -> Dictionary:
	var d: Dictionary = data()
	return standing(int(personality_xp.get(character, 0)), d.get("personality_levels", [0]),
		int(d.get("past_end_step", 0)))


func school_level(school: String) -> int:
	return int(school_standing(school)["level"])


func personality_level(character: String) -> int:
	return int(personality_standing(character)["level"])


## The next level that gives the character something: {level, text}, or {} when nothing is left.
func next_milestone(character: String, library: CardLibrary, collection: AdventureCollection = null,
		unlocks: AdventureUnlocks = null) -> Dictionary:
	var now: int = personality_level(character)
	var track: Dictionary = (data().get("tracks", {}) as Dictionary).get(character, {})
	if track.is_empty():
		var missing: int = 2
		if collection != null:
			missing = mini(2, _missing_signatures(character, 2, library, collection).size())
		return {} if missing == 0 else {"level": now + 1, "text": "%d signature card%s" % [missing, "" if missing == 1 else "s"]}
	var levels: Array[int] = []
	for key in track.keys():
		if int(key) > now:
			levels.append(int(key))
	if levels.is_empty():
		return {}
	levels.sort()
	return {"level": levels[0], "text": reward_text(track.get(str(levels[0]), {}), library, collection, unlocks)}


## Every authored level of a character's track, in level order: [{level, reward, reached}]. Empty
## for a character with no authored track.
func milestones(character: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var track: Dictionary = (data().get("tracks", {}) as Dictionary).get(character, {})
	var levels: Array[int] = []
	for key in track.keys():
		levels.append(int(key))
	levels.sort()
	var now: int = personality_level(character)
	for level in levels:
		out.append({"level": level, "reward": track[str(level)], "reached": level <= now})
	return out


## XP still needed for the character to reach `level`; 0 once there.
func personality_xp_to(character: String, level: int) -> int:
	var d: Dictionary = data()
	var at: int = threshold_of(level, d.get("personality_levels", [0]), int(d.get("past_end_step", 0)))
	return maxi(0, at - int(personality_xp.get(character, 0)))


## The school's cards the collection holds at least one copy of, and the pool's size.
static func school_library(school: String, library: CardLibrary, collection: AdventureCollection) -> Vector2i:
	var pool: Array[String] = school_pool(school, library)
	var owned: int = 0
	for id in pool:
		if collection != null and collection.copies(id) > 0:
			owned += 1
	return Vector2i(owned, pool.size())


## A reward in a few words, for a milestone tile: "Deck: Ember Ascendant", "Aspect 4 card",
## "2 signature cards", "Starting Relic and Reserve".
static func reward_short(reward: Dictionary, library: CardLibrary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var starter: String = str(reward.get("starter", ""))
	if starter != "":
		parts.append("Deck: %s" % deck_name(starter))
	var signatures: int = int(reward.get("signatures", 0))
	for id in reward.get("cards", []):
		if not library.has(str(id)):
			continue
		var def: CardDef = library.get_def(str(id))
		if def.is_personality():
			parts.append("Aspect %d card" % def.aspect)
		elif def.is_signature():
			signatures += 1
		else:
			parts.append(card_name(def))
	if signatures > 0:
		parts.append("%d signature card%s" % [signatures, "" if signatures == 1 else "s"])
	var abilities: Array = reward.get("abilities", [])
	if abilities.has(AdventureUnlocks.ABILITY_RELIC) and abilities.has(AdventureUnlocks.ABILITY_RESERVE):
		parts.append("Starting Relic and Reserve")
	else:
		for ability in abilities:
			parts.append(ability_name(str(ability)))
	return ", ".join(parts)


## The card a reward is pictured by: its first personality, else its first card. "" for none.
static func reward_card(reward: Dictionary, library: CardLibrary) -> String:
	var first: String = ""
	for id in reward.get("cards", []):
		if not library.has(str(id)):
			continue
		if library.get_def(str(id)).is_personality():
			return str(id)
		if first == "":
			first = str(id)
	return first


## What the school's next level gives, in words, without advancing the pool.
func school_next_text(school: String, library: CardLibrary) -> String:
	var d: Dictionary = data()
	var text: String = "%d %s cards" % [int(d.get("school_batch", 3)), school.capitalize()]
	var next: int = school_level(school) + 1
	if _int_list(d.get("mastery_levels", [])).has(next) and _mastery_for(school, next, d, library) != "":
		text += " and a %s Mastery" % school.capitalize()
	return text


## With `collection` and `unlocks`, what the player already has is marked.
static func reward_text(reward: Dictionary, library: CardLibrary, collection: AdventureCollection = null,
		unlocks: AdventureUnlocks = null) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var signatures: PackedStringArray = PackedStringArray()
	for id in reward.get("cards", []):
		if library.has(str(id)):
			var def: CardDef = library.get_def(str(id))
			var owned: String = " (owned)" if collection != null and collection.copies(str(id)) > 0 else ""
			if def.is_signature() and not def.is_personality():
				signatures.append(def.title + owned)
			else:
				parts.append(card_name(def) + owned)
	if not signatures.is_empty():
		parts.append("Signature card%s: %s" % ["s" if signatures.size() > 1 else "", ", ".join(signatures)])
	var starter: String = str(reward.get("starter", ""))
	if starter != "":
		var open: bool = unlocks != null and unlocks.is_open(starter)
		parts.append("Opens deck: %s%s" % [deck_name(starter), " (already open)" if open else ""])
	for ability in reward.get("abilities", []):
		parts.append(ability_name(str(ability)))
	if int(reward.get("signatures", 0)) > 0:
		parts.append("%d signature cards" % int(reward["signatures"]))
	return ", ".join(parts)


static func card_name(def: CardDef) -> String:
	if def.is_personality():
		var who: String = def.title if def.aspect_title == "" else "%s, %s" % [def.title, def.aspect_title]
		return "Aspect %d card: %s" % [def.aspect, who]
	if def.is_signature():
		return "Signature card: %s" % def.title
	if def.type == CardDef.Type.MASTERY:
		return "Mastery: %s" % def.title
	if def.type == CardDef.Type.RELIC:
		return "Relic: %s" % def.title
	return def.title


static func deck_name(starter_id: String) -> String:
	var deck: DeckList = DeckList.resolve(starter_id)
	return deck.name.trim_suffix(" (Starter)") if deck != null else starter_id


static func ability_name(ability: String) -> String:
	match ability:
		AdventureUnlocks.ABILITY_RELIC:
			return "Starts runs with a Relic"
		AdventureUnlocks.ABILITY_RESERVE:
			return "Starts runs with a Reserve"
	return ability


# --- A new run ----------------------------------------------------------------

## The main's owned Aspect cards above its starting stack, and a starting Relic and Reserve from
## the character's precon once earned. A starter's own Relic is kept; an illegal result is dropped.
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
	run.starter_reserve = run.reserve.duplicate()


# --- One won duel -------------------------------------------------------------

## Applies a storyline join, XP, levels and achievements, in that order, and returns what the
## screen after the duel shows: {kind, tag, title, details}, kind being join, xp, level, school or
## achievement. The xp entry also carries `bars`, one {name, school, gained, segments} per track
## (see `xp_segments`). Nothing here saves.
static func record_win(run: AdventureRun, map: AdventureMap, engine: DuelEngine,
		library: CardLibrary, collection: AdventureCollection, unlocks: AdventureUnlocks,
		progress: AdventureProgress, wallet: AdventureWallet) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var joined: String = AdventureStory.apply_boss_win(run, map, library)
	if joined != "":
		out.append({"kind": "join", "tag": "JOINED", "title": library.get_def(joined).title,
			"details": ["In your deck for the rest of this run"] as Array[String]})
	var result: Dictionary = duel_result(run, map, engine)
	var levelups: Array[Dictionary] = progress.award(result)
	var keys: Array = progress.last_gains.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(progress.last_gains[a]) > int(progress.last_gains[b]))
	var details: Array[String] = []
	var bars: Array[Dictionary] = []
	var title: String = ""
	for key in keys:
		var kind: String = str(key).get_slice(":", 0)
		var name: String = str(key).substr(kind.length() + 1)
		var s: Dictionary = progress.school_standing(name) if kind == "school" else progress.personality_standing(name)
		var amount: int = int(progress.last_gains[key])
		var shown: String = name.capitalize() if kind == "school" else name
		var gained: String = "%s +%d XP" % [shown, amount]
		var left: String = "%d XP to level %d" % [int(s["to"]) - int(s["xp"]), int(s["level"]) + 1]
		if title == "":
			title = gained
			details.append(left)
		else:
			details.append("%s, %s" % [gained, left])
		bars.append({"name": shown, "school": name if kind == "school" else "", "gained": amount,
			"segments": progress.xp_segments(kind, int(s["xp"]) - amount, int(s["xp"]))})
	if title != "":
		out.append({"kind": "xp", "tag": "XP", "title": title, "details": details, "bars": bars})
	for levelup in levelups:
		var key: String = str(levelup["key"])
		var school: bool = str(levelup["kind"]) == "school"
		var granted: Array[String] = grant(progress.reward_for(levelup, library), "" if school else key,
			library, collection, unlocks, wallet, run)
		out.append({"kind": "school" if school else "level",
			"tag": "%sLEVEL %d" % ["SCHOOL " if school else "", int(levelup["level"])],
			"title": key.capitalize() if school else key, "details": granted})
	var events: Array[Dictionary] = [result]
	if bool(result["run_won"]):
		events.append({"event": "run_won", "main": result["main"], "starter": run.starter_id})
	for a in AdventureAchievements.apply(unlocks, events):
		out.append({"kind": "achievement", "tag": "ACHIEVEMENT",
			"title": str(a.get("title", a.get("id", ""))),
			"details": grant(a, str(a.get("character", "")), library, collection, unlocks, wallet, run)})
	return out


## `engine` is the duel's own engine; null leaves allies, blocks and peak Aspect unread.
static func duel_result(run: AdventureRun, map: AdventureMap, engine: DuelEngine) -> Dictionary:
	var here: Dictionary = map.node(run.node_id)
	var opponent_id: String = str(map.duel_for(run.node_id).get("opponent", ""))
	var main: String = AdventureDecks.character_of(AdventureDecks.family_of(run.starter_id))
	var allies: Array[String] = []
	var blocks: int = 0
	var aspect: int = maxi(1, run.duelist_ids.size())
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


## Returns the levels newly reached, lowest first: {kind: school or personality, key, level}.
func award(result: Dictionary) -> Array[Dictionary]:
	var xp: Dictionary = data().get("xp", {})
	var boss: bool = str(result.get("node", "")) == "boss"
	var run_won: bool = bool(result.get("run_won", false))
	var before: Dictionary = _levels_snapshot()
	last_gains = {}
	var main: String = str(result.get("main", ""))
	if main != "":
		var gain: int = int(xp.get("main_boss" if boss else "main_duel", 0))
		if run_won:
			gain += int(xp.get("main_run", 0))
		_add("personality", main, gain)
	for who in result.get("allies", []):
		_add("personality", str(who), int(xp.get("ally_in_play", 0)))
	var beaten: String = str(result.get("opponent", ""))
	if beaten != "" and beaten != main:
		_add("personality", beaten, int(xp.get("beaten_boss" if boss else "beaten_duel", 0)))
	var school: String = str(result.get("school", ""))
	if school != "":
		var school_gain: int = int(xp.get("school_boss" if boss else "school_duel", 0))
		if run_won:
			school_gain += int(xp.get("school_run", 0))
		_add("school", school, school_gain)
	return _levels_gained(before)


func _add(kind: String, key: String, amount: int) -> void:
	if key == "" or amount <= 0:
		return
	var book: Dictionary = school_xp if kind == "school" else personality_xp
	book[key] = int(book.get(key, 0)) + amount
	var tag: String = "%s:%s" % [kind, key]
	last_gains[tag] = int(last_gains.get(tag, 0)) + amount


func _levels_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for school in school_xp.keys():
		out["school:%s" % school] = school_level(str(school))
	for character in personality_xp.keys():
		out["personality:%s" % character] = personality_level(str(character))
	return out


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


# --- Rewards ------------------------------------------------------------------

## Advances the school pool: call once per school level reached.
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


## Cards printed at higher limits first, then by id. Freestyle's pool is the cards of no school.
static func school_pool(school: String, library: CardLibrary) -> Array[String]:
	var defs: Array[CardDef] = []
	for id in library.all_ids():
		var def: CardDef = library.defs[id]
		if def.card_group() != school or EXCLUDED_POOL_TYPES.has(int(def.type)):
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


## The Nth mastery level gives the school's Nth Mastery by id.
## The Mastery a school level gives, or "" when that level gives none.
static func school_mastery(school: String, level: int, library: CardLibrary) -> String:
	return _mastery_for(school, level, data(), library)


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


## JSON numbers are floats, which `has` and `find` do not match against an int.
static func _int_list(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v in values:
		out.append(int(v))
	return out


## Cards past the collection cap dust into Motes. A personality card of the run's own character
## becomes climbable in that run. Returns one line per thing granted.
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
			lines.append(card_name(def))
		elif int(report.get("motes", 0)) > 0:
			lines.append("%s, dusted for %d Motes" % [def.title, int(report["motes"])])
		if run != null and def.is_personality() and not run.owned_aspects.has(id):
			if def.character == AdventureDecks.character_of(AdventureDecks.family_of(run.starter_id)):
				run.owned_aspects.append(id)
	var starter: String = str(reward.get("starter", ""))
	if starter != "":
		var opened: bool = unlocks.unlock(starter)
		lines.append("Opens deck: %s%s" % [deck_name(starter), "" if opened else " (already open)"])
	for ability in reward.get("abilities", []):
		if unlocks.grant_ability(character, str(ability)):
			lines.append(ability_name(str(ability)))
	return lines


static func _missing_signatures(character: String, n: int, library: CardLibrary,
		collection: AdventureCollection) -> Array[String]:
	var ids: Array[String] = []
	for id in library.all_ids():
		var def: CardDef = library.defs[id]
		if def.character == character and not def.is_personality() and collection.copies(id) == 0:
			ids.append(id)
	ids.sort()
	return ids.slice(0, n)


## Every card a track or an achievement names. The vendor never stocks them.
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


# --- Tutorial -------------------------------------------------------------------

## Lesson `n` has begun, so a later start resumes there. Only ever moves forward.
func reach_lesson(n: int) -> void:
	tutorial_lesson = maxi(tutorial_lesson, n)


## The session was played to its end: the next one starts from the first lesson again.
func finish_tutorial() -> void:
	tutorial_done = true
	tutorial_lesson = 0


## The lesson a tutorial started with no lesson named begins at.
func tutorial_resume_lesson() -> int:
	return maxi(1, tutorial_lesson)


# --- Save ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"school_xp": school_xp.duplicate(),
		"personality_xp": personality_xp.duplicate(),
		"paid": paid.duplicate(),
		"school_cursor": school_cursor.duplicate(),
		"tutorial_lesson": tutorial_lesson,
		"tutorial_done": tutorial_done,
	}


static func from_dict(d: Dictionary) -> AdventureProgress:
	var p: AdventureProgress = AdventureProgress.new()
	for field in ["school_xp", "personality_xp", "paid", "school_cursor"]:
		var src: Dictionary = d.get(field, {})
		var dst: Dictionary = p.get(field)
		for k in src.keys():
			dst[str(k)] = int(src[k])
	p.tutorial_lesson = int(d.get("tutorial_lesson", 0))
	p.tutorial_done = bool(d.get("tutorial_done", false))
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
