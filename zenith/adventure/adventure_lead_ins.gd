class_name AdventureLeadIns
extends RefCounted
## Pre-duel lead-ins: a context line and a short exchange before each adventure duel, authored in
## data/adventure/lead_ins.json. A connected pair has its own scenes, picked by how the two have
## met; anyone else gets the opponent's call and the main's tagged reply. A joined Ally can add a
## line, and a main with whispers (Ashmark) can hear someone he beat this run.

const DATA: String = "res://data/adventure/lead_ins.json"
## Pair slots in the order they are tried. Each holds when its condition does (`_slot_holds`).
const SLOT_ORDER: Array[String] = ["boss_again", "boss", "after_loss", "level", "act3", "again", "first"]
## The order the preview lists a pair's slots in, the order a player meets them.
const BROWSE_ORDER: Array[String] = ["first", "again", "after_loss", "level", "act3", "boss", "boss_again"]
const DEFAULT_LEVEL_MIN: int = 3

## Side a spoken line sits on.
const SIDE_MAIN: String = "main"
const SIDE_OPPONENT: String = "opponent"
const SIDE_ALLY: String = "ally"
const SIDE_WHISPER: String = "whisper"


static func read_data() -> Dictionary:
	if not FileAccess.file_exists(DATA):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return parsed if parsed is Dictionary else {}


## What a lead-in is picked from. Every field has a default, so tests and the preview can pass
## only what they need.
##   main, opponent: characters. family: the opponent's deck family.
##   boss: a boss node. act: 1 to 3. level: the main's personality level.
##   met: finished duels between the two, any run. last: "won", "lost" or "" for the main.
##   construct: the opponent is tagged construct. joined: characters that joined the run deck.
##   beaten: characters the main beat this run, oldest first. shown: keys already shown this run.
##   seed: for the picks that are not ordered.
static func empty_context() -> Dictionary:
	return {
		"main": "", "opponent": "", "family": "", "boss": false, "act": 1, "level": 1,
		"met": 0, "last": "", "construct": false, "joined": [], "beaten": [], "shown": [],
		"seed": 0,
	}


## The context for the duel the run stands on.
static func context_for(run: AdventureRun, map: AdventureMap, library: CardLibrary,
		progress: AdventureProgress, story_log: AdventureStoryLog) -> Dictionary:
	var ctx: Dictionary = empty_context()
	var here: Dictionary = map.node(run.node_id)
	var opponent_id: String = str(map.duel_for(run.node_id).get("opponent", ""))
	var family: String = AdventureDecks.family_of(opponent_id)
	var main: String = AdventureDecks.character_of(AdventureDecks.family_of(run.starter_id))
	var opponent: String = AdventureDecks.character_of(family)
	ctx["main"] = main
	ctx["opponent"] = opponent
	ctx["family"] = family
	ctx["boss"] = str(here.get("type", "")) == "boss"
	ctx["act"] = int(here.get("act", 1))
	ctx["level"] = progress.personality_level(main) if progress != null else 1
	ctx["met"] = story_log.met(main, opponent)
	ctx["last"] = story_log.last(main, opponent)
	ctx["construct"] = _is_construct(family, library)
	var joined: Array[String] = []
	for pick in run.picks:
		if str(pick.get("kind", "")) == "joined" and library.has(str(pick.get("id", ""))):
			var who: String = library.get_def(str(pick["id"])).character
			if who != "" and not joined.has(who):
				joined.append(who)
	ctx["joined"] = joined
	ctx["beaten"] = story_log.beaten.duplicate()
	ctx["shown"] = story_log.shown.duplicate()
	ctx["seed"] = run.stage_seed(run.stage)
	return ctx


## The lead-in for a context: {key, keys, title, narration, lines, main, opponent}, or {} when
## there is nothing to show. `lines` are {speaker, text, side}. `keys` are every entry used, to
## mark shown.
static func pick(ctx: Dictionary, data: Dictionary = {}) -> Dictionary:
	if data.is_empty():
		data = read_data()
	var main: String = str(ctx.get("main", ""))
	var opponent: String = str(ctx.get("opponent", ""))
	if main == "" or opponent == "":
		return {}
	var out: Dictionary = _pair_scene(ctx, data)
	if out.is_empty():
		out = _general_scene(ctx, data)
	if out.is_empty():
		return {}
	out["main"] = main
	out["opponent"] = opponent
	_add_joined(out, ctx, data)
	_add_whisper(out, ctx, data)
	return out


static func _pair_scene(ctx: Dictionary, data: Dictionary) -> Dictionary:
	var main: String = str(ctx["main"])
	var opponent: String = str(ctx["opponent"])
	var slots: Dictionary = ((data.get("pairs", {}) as Dictionary).get(main, {}) as Dictionary).get(opponent, {})
	if slots.is_empty():
		return {}
	var shown: Array = ctx.get("shown", [])
	var fallback: Dictionary = {}
	for slot in SLOT_ORDER:
		if not slots.has(slot):
			continue
		var scene: Dictionary = _variant(slots[slot], ctx)
		if scene.is_empty() or not _slot_holds(slot, scene, ctx):
			continue
		var key: String = "%s|%s|%s" % [main, opponent, slot]
		var built: Dictionary = _build(key, scene, ctx, data)
		if not shown.has(key):
			return built
		if fallback.is_empty():
			fallback = built
	return fallback


static func _slot_holds(slot: String, scene: Dictionary, ctx: Dictionary) -> bool:
	var boss: bool = bool(ctx.get("boss", false))
	var lost: bool = str(ctx.get("last", "")) == "lost"
	var met: int = int(ctx.get("met", 0))
	match slot:
		"boss_again":
			return boss and lost
		"boss":
			return boss
		"after_loss":
			return lost
		"level":
			return met > 0 and int(ctx.get("level", 1)) >= int(scene.get("level_min", DEFAULT_LEVEL_MIN))
		"act3":
			return int(ctx.get("act", 1)) >= 3
		"again":
			return met > 0
		"first":
			return true
	return false


## A slot is one scene or a list of variants; the first variant whose conditions hold wins.
static func _variant(value: Variant, ctx: Dictionary) -> Dictionary:
	var options: Array = value if value is Array else [value]
	for option in options:
		if not (option is Dictionary):
			continue
		var scene: Dictionary = option
		if scene.has("deck") and str(scene["deck"]) != str(ctx.get("family", "")):
			continue
		if scene.has("met") and bool(scene["met"]) != (int(ctx.get("met", 0)) > 0):
			continue
		return scene
	return {}


static func _general_scene(ctx: Dictionary, data: Dictionary) -> Dictionary:
	var main: String = str(ctx["main"])
	var opponent: String = str(ctx["opponent"])
	var call: Dictionary = (data.get("calls", {}) as Dictionary).get(opponent, {})
	if call.is_empty():
		return {}
	var reply: Dictionary = _reply(ctx, data, str(call.get("kind", "")))
	var scene: Dictionary = {"narration": call.get("narration", ""), "lines": [call.get("line", "")]}
	var out: Dictionary = _build("call|%s" % opponent, scene, ctx, data)
	if not reply.is_empty():
		(out["lines"] as Array).append(parse_line(str(reply["line"]), ctx, data))
		(out["keys"] as Array).append(str(reply["key"]))
	return out


## The main's reply to a call of `kind`: one that fits it (or "any"), not yet heard this run when
## possible. A reply with a level_min is preferred once the main has reached it.
static func _reply(ctx: Dictionary, data: Dictionary, kind: String) -> Dictionary:
	var main: String = str(ctx["main"])
	var replies: Array = (data.get("replies", {}) as Dictionary).get(main, [])
	var level: int = int(ctx.get("level", 1))
	var shown: Array = ctx.get("shown", [])
	var plain: Array[Dictionary] = []
	var levelled: Array[Dictionary] = []
	for i in replies.size():
		var r: Dictionary = replies[i]
		var fits: Array = r.get("fits", [])
		if not (fits.has(kind) or fits.has("any")):
			continue
		if bool(r.get("construct", false)) and not bool(ctx.get("construct", false)):
			continue
		if r.has("level_min") and level < int(r["level_min"]):
			continue
		var entry: Dictionary = {"line": str(r.get("line", "")), "key": "reply|%s|%d" % [main, i]}
		if shown.has(entry["key"]):
			continue
		if r.has("level_min"):
			levelled.append(entry)
		else:
			plain.append(entry)
	var pool: Array[Dictionary] = levelled if not levelled.is_empty() else plain
	if pool.is_empty():
		for i in replies.size():
			var r: Dictionary = replies[i]
			var fits: Array = r.get("fits", [])
			if (fits.has(kind) or fits.has("any")) and not r.has("level_min") and not bool(r.get("construct", false)):
				pool.append({"line": str(r.get("line", "")), "key": "reply|%s|%d" % [main, i]})
	if pool.is_empty():
		return {}
	return pool[absi(int(ctx.get("seed", 0))) % pool.size()]


## A joined character's line, at most once per act: `once` the first time, then the opponent's
## own line, `construct`, or `any`.
static func _add_joined(out: Dictionary, ctx: Dictionary, data: Dictionary) -> void:
	var joined_data: Dictionary = data.get("joined", {})
	var shown: Array = ctx.get("shown", [])
	for who in ctx.get("joined", []):
		var lines: Dictionary = joined_data.get(str(who), {})
		if lines.is_empty():
			continue
		var act_key: String = "joined|%s|act%d" % [who, int(ctx.get("act", 1))]
		if shown.has(act_key):
			continue
		var once_key: String = "joined|%s|once" % who
		var line: String = ""
		if lines.has("once") and not shown.has(once_key):
			line = str(lines["once"])
			(out["keys"] as Array).append(once_key)
		elif lines.has(str(ctx["opponent"])):
			line = str(lines[str(ctx["opponent"])])
		elif bool(ctx.get("construct", false)) and lines.has("construct"):
			line = str(lines["construct"])
		elif lines.has("any"):
			line = str(lines["any"])
		if line == "":
			continue
		var parsed: Dictionary = parse_line(line, ctx, data)
		parsed["side"] = SIDE_ALLY
		(out["lines"] as Array).append(parsed)
		(out["keys"] as Array).append(act_key)
		return


## A whisper from someone the main beat this run, newest first, or one of the main's own once no
## beaten voice is left. Only after a first win in the run, and only on every other duel.
static func _add_whisper(out: Dictionary, ctx: Dictionary, data: Dictionary) -> void:
	var whispers: Dictionary = (data.get("whispers", {}) as Dictionary).get(str(ctx["main"]), {})
	var beaten: Array = ctx.get("beaten", [])
	if whispers.is_empty() or beaten.is_empty() or int(ctx.get("seed", 0)) % 2 != 0:
		return
	var shown: Array = ctx.get("shown", [])
	var from: Dictionary = whispers.get("from", {})
	var text: String = ""
	var key: String = ""
	for i in range(beaten.size() - 1, -1, -1):
		var who: String = str(beaten[i])
		var k: String = "whisper|%s|%s" % [ctx["main"], who]
		if from.has(who) and not shown.has(k):
			text = str(from[who])
			key = k
			break
	if text == "":
		var own: Array = whispers.get("own", [])
		for i in own.size():
			var k: String = "whisper|%s|own%d" % [ctx["main"], i]
			if not shown.has(k):
				text = str(own[i])
				key = k
				break
	if text == "":
		return
	(out["lines"] as Array).append({"speaker": "", "text": text, "side": SIDE_WHISPER})
	(out["keys"] as Array).append(key)
	var answer: String = str(whispers.get("answer", ""))
	if answer != "" and (int(ctx.get("seed", 0)) / 2) % 2 == 0:
		(out["lines"] as Array).append(parse_line(answer, ctx, data))


static func _build(key: String, scene: Dictionary, ctx: Dictionary, data: Dictionary) -> Dictionary:
	var lines: Array = []
	for raw in scene.get("lines", []):
		lines.append(parse_line(str(raw), ctx, data))
	return {"key": key, "keys": [key], "narration": str(scene.get("narration", "")), "lines": lines}


## "Speaker: text" -> {speaker, text, side}. The side follows whose short name the speaker is.
static func parse_line(raw: String, ctx: Dictionary, data: Dictionary) -> Dictionary:
	var at: int = raw.find(": ")
	var speaker: String = raw.substr(0, at).strip_edges() if at > 0 else ""
	var text: String = raw.substr(at + 2).strip_edges() if at > 0 else raw.strip_edges()
	var names: Dictionary = data.get("names", {})
	var side: String = SIDE_ALLY
	if speaker == str(names.get(str(ctx.get("main", "")), "")):
		side = SIDE_MAIN
	elif speaker == str(names.get(str(ctx.get("opponent", "")), "")):
		side = SIDE_OPPONENT
	return {"speaker": speaker, "text": text, "side": side}


static func _is_construct(family: String, library: CardLibrary) -> bool:
	var deck: DeckList = DeckList.resolve(family)
	if deck == null:
		return false
	var def: CardDef = library.defs.get(deck.duelist_face_id())
	return def != null and (def.raw.get("tags", []) as Array).has("construct")


## Every authored scene as a lead-in, for the preview screen: pair slots and their variants, then
## each call with its first fitting reply. Each has a `title` naming where it lives in the file.
static func all_scenes(data: Dictionary = {}) -> Array[Dictionary]:
	if data.is_empty():
		data = read_data()
	var out: Array[Dictionary] = []
	var pairs: Dictionary = data.get("pairs", {})
	for main in pairs.keys():
		for opponent in (pairs[main] as Dictionary).keys():
			var slots: Dictionary = pairs[main][opponent]
			for slot in BROWSE_ORDER:
				if not slots.has(slot):
					continue
				var options: Array = slots[slot] if slots[slot] is Array else [slots[slot]]
				for i in options.size():
					var ctx: Dictionary = empty_context()
					ctx["main"] = main
					ctx["opponent"] = opponent
					var scene: Dictionary = _build("%s|%s|%s" % [main, opponent, slot], options[i], ctx, data)
					scene["main"] = main
					scene["opponent"] = opponent
					var tag: String = slot if options.size() == 1 else "%s %d" % [slot, i + 1]
					scene["title"] = "%s vs %s  /  %s" % [main, opponent, tag]
					out.append(scene)
	var calls: Dictionary = data.get("calls", {})
	var mains: Array = (data.get("replies", {}) as Dictionary).keys()
	for opponent in calls.keys():
		for main in mains:
			if main == opponent or ((pairs.get(main, {}) as Dictionary).has(opponent)):
				continue
			var ctx: Dictionary = empty_context()
			ctx["main"] = main
			ctx["opponent"] = opponent
			var scene: Dictionary = _general_scene(ctx, data)
			scene["main"] = main
			scene["opponent"] = opponent
			scene["title"] = "%s vs %s  /  call and reply" % [main, opponent]
			out.append(scene)
	return out
