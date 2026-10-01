class_name TutorialDirector
extends RefCounted
## The training session of lessons 1 to 5 (`docs/tutorial_script.md`), read as a list of steps
## from `data/tutorial/lessons.json`. It holds no engine and no Node: a caller asks `next` with the
## two seats' views and prompts, applies what comes back through its Referee, and reports with
## `done`. The rival seat is played by picking from its own PromptView; for the player it says
## which options are open and why every other one is not. RefCounted only, like `engine/`.
##
## A step is one of:
## - a `stop`: lines said while the table waits, one after another (`TutorialPacing` times them),
##   each `{who, text, ring}`. It ends on its own, or with a click when it `hold`s.
## - a `bark`: one line `{who, text, ring}` that shows and fades while play goes straight on.
## - an `op`, a board adjustment for `Referee.script`.
## - a `player` step: the prompt kind the player is asked, the options it `take`s, and the
##   `callout` Vale gives for it, with an optional `ring` on where to look.
## - a `rival` step: the same for the rival seat.
## A player or rival step may carry `says`, a line said as the move is made. A stop, bark or op may
## `wait` for a prompt of a given seat and kind; until it comes, the rival answers quietly. A rival
## prompt the script does not name is always answered quietly.
##
## Who speaks decides where: `vale` in the coach box, `narration` in the caption, `emrys` at
## Emrys' duelist card, `caedan` at the rival's (lessons 3 to 5, where he fights).

const LESSONS: String = "res://data/tutorial/lessons.json"
const DECKS: String = "res://data/tutorial/decks.json"
const CARDS: String = "res://data/tutorial/cards.json"
const PLAYER: int = 0
const RIVAL: int = 1
## The rival's answer when the script names none, quietest first.
const QUIET: Array[StringName] = [&"pass", &"no_defense", &"no_endure", &"no_critical", &"skip", &"done",
	&"no_recover", &"discard_all", &"decline", &"pick_none", &"reserve_done", &"order_confirm"]
const MAX_STEPS: int = 20000

var data: Dictionary = {}
var decks: Dictionary = {}
## Every step of the lessons in play, in order, each stamped with its `lesson` number and `title`.
var steps: Array[Dictionary] = []
## The step to act on next.
var index: int = 0


## Lessons 1 to `last` (0 for all of them). A range that stops before the last lesson ends the
## session after it. A later start is reached with `fast_forward`, which leaves the board where
## the script has it.
func _init(last: int = 0) -> void:
	data = _read(LESSONS)
	decks = _read(DECKS)
	var lessons: Array = data.get("lessons", [])
	var final: int = int((lessons.back() as Dictionary).get("n", 1)) if not lessons.is_empty() else 1
	var stop: int = final if last <= 0 else mini(last, final)
	for lesson in lessons:
		var n: int = int((lesson as Dictionary).get("n", 0))
		if n > stop:
			break
		for s in (lesson as Dictionary).get("steps", []):
			var step: Dictionary = (s as Dictionary).duplicate(true)
			step["lesson"] = n
			step["title"] = str((lesson as Dictionary).get("title", ""))
			steps.append(step)
	if stop < final:
		steps.append({"op": {"op": "end_session"}, "lesson": stop, "title": "", "b": 0})


static func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The shipped pool plus the tutorial's own cards, which live in `data/tutorial/` so that no deck,
## collection, vendor or adventure list ever sees them.
static func library_from(base: CardLibrary) -> CardLibrary:
	var lib: CardLibrary = CardLibrary.new()
	for id in base.defs:
		lib.defs[id] = base.defs[id]
	lib.load_file(CARDS)
	return lib


func deck(key: String) -> DeckList:
	var d: DeckList = DeckList.from_dict(decks.get(key, {}))
	d.id = key
	return d


func seat_decks() -> Array[DeckList]:
	var keys: Array = data.get("decks", ["emrys", "straw_knight"])
	var out: Array[DeckList] = [deck(str(keys[0])), deck(str(keys[1]))]
	return out


func names() -> Array[String]:
	var out: Array[String] = []
	for n in data.get("names", []):
		out.append(str(n))
	return out


## A scripted referee dealt for lesson 1, not yet started. The caller starts it.
func build_referee(library: CardLibrary, table: StrikeTable, capture_display: bool = true) -> Referee:
	var referee: Referee = Referee.new()
	referee.engine.scripted = true
	referee.setup(seat_decks(), library, table, int(data.get("seed", 1)), names(), capture_display)
	var opening: Array = data.get("opening", [])
	for seat in range(mini(2, opening.size())):
		referee.engine.set_opening(seat, opening[seat])
	return referee


# --- Where the script stands ----------------------------------------------------

func finished() -> bool:
	return index >= steps.size()


func current() -> Dictionary:
	return steps[index] if index < steps.size() else {}


func lesson_at(i: int) -> int:
	return int(steps[i].get("lesson", 0)) if i >= 0 and i < steps.size() else 0


func lesson() -> int:
	return lesson_at(mini(index, steps.size() - 1))


func lesson_title(n: int) -> String:
	for s in steps:
		if int(s.get("lesson", 0)) == n:
			return str(s.get("title", ""))
	return ""


## The first step of lesson `n`, or the end when there is no such lesson.
func lesson_start(n: int) -> int:
	for i in range(steps.size()):
		if int(steps[i].get("lesson", 0)) >= n:
			return i
	return steps.size()


## The `nth` step (from 0) of lesson `n` numbered `beat` in the script, -1 when there is none.
func beat_index(n: int, beat: int, nth: int = 0) -> int:
	var seen: int = 0
	for i in range(steps.size()):
		if int(steps[i].get("lesson", 0)) == n and int(steps[i].get("b", -1)) == beat:
			if seen == nth:
				return i
			seen += 1
	return -1


## The last lesson this session plays.
func last_lesson() -> int:
	return lesson_at(steps.size() - 1)


## The last lesson the script has, whatever range this session plays.
func final_lesson() -> int:
	var lessons: Array = data.get("lessons", [])
	return int((lessons.back() as Dictionary).get("n", 1)) if not lessons.is_empty() else 1


## Name, portrait card and place (`at`: coach, caption, you or rival) of a line's speaker.
func speaker(who: String) -> Dictionary:
	return (data.get("speakers", {}) as Dictionary).get(who, {"name": "", "card": "", "at": "coach"})


## The card id of the practice dummy, which wobbles when hit.
func dummy() -> String:
	return str(data.get("dummy", ""))


## The lines a stop says, or a bark's one line, each `{who, text, ring}`; [] for any other step.
static func lines_of(step: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if step.get("stop") is Array:
		for l in step["stop"]:
			out.append(l as Dictionary)
	elif step.get("bark") is Dictionary:
		out.append(step["bark"] as Dictionary)
	return out


## The line a move carries as it is made, {} for none.
static func says_of(step: Dictionary) -> Dictionary:
	return step["says"] if step.get("says") is Dictionary else {}


## How many times lesson `n` stops the table.
func stop_count(n: int) -> int:
	var count: int = 0
	for s in steps:
		if int(s.get("lesson", 0)) == n and s.has("stop"):
			count += 1
	return count


# --- The next thing to do -------------------------------------------------------

## What the caller does next, as a Dictionary with `do`:
## - "say": play the stop `step` while the table waits, then report it done.
## - "bark": show the bark `step` and report it done at once; it fades on its own.
## - "op": apply `op` through `Referee.script`.
## - "rival": submit `wire` for the rival seat.
## - "player": the player's prompt is up; `gate` holds `enabled` and `reasons` per option index,
##   `library` the reason for a searched deck's cards that are not choices.
## - "end": the script is over.
## - "mismatch": the table is not where the script expects; `why` says how. `gate` opens every
##   option when the player's prompt is up, so a client never locks the player out.
## Report every action that was carried out with `done`, which moves on when it should. `at` is
## the step the action belongs to.
func next(view: SeatView, prompt: PromptView, rival_view: SeatView, rival_prompt: PromptView) -> Dictionary:
	var action: Dictionary = _next(view, prompt, rival_view, rival_prompt)
	action["at"] = index
	return action


func _next(view: SeatView, prompt: PromptView, rival_view: SeatView, rival_prompt: PromptView) -> Dictionary:
	for _i in range(steps.size() + 1):
		if finished():
			return {"do": "end", "advance": false}
		var step: Dictionary = steps[index]
		if step.has("wait") and not _waited(step["wait"], prompt, rival_prompt):
			if rival_prompt != null:
				return _rival_quietly(rival_prompt, rival_view)
			return _mismatch(step, prompt, "waits for %s" % str(step["wait"]))
		if step.has("player"):
			if prompt != null and _fits(step, str(step["player"]), prompt, view):
				return {"do": "player", "step": step, "gate": gate(step, prompt, view), "advance": true}
			if rival_prompt != null:
				return _rival_quietly(rival_prompt, rival_view)
			if bool(step.get("optional", false)):
				index += 1
				continue
			return _mismatch(step, prompt, "expects the player's %s" % str(step["player"]))
		if step.has("rival"):
			if rival_prompt != null:
				if _fits(step, str(step["rival"]), rival_prompt, rival_view):
					return {"do": "rival", "wire": _first_taken(step, rival_prompt, rival_view).to_command(RIVAL).to_dict(),
						"step": step, "advance": true}
				return _rival_quietly(rival_prompt, rival_view)
			if bool(step.get("optional", false)):
				index += 1
				continue
			return _mismatch(step, prompt, "expects the rival's %s" % str(step["rival"]))
		if step.has("op"):
			return {"do": "op", "op": _expanded(step["op"]), "step": step, "advance": true}
		if step.has("stop"):
			return {"do": "say", "step": step, "advance": true}
		if step.has("bark"):
			return {"do": "bark", "step": step, "advance": true}
		index += 1
	return {"do": "end", "advance": false}


## The same question put through a referee's own views.
func next_for(referee: Referee) -> Dictionary:
	return next(referee.view_for(PLAYER), referee.prompt_for(PLAYER), referee.view_for(RIVAL), referee.prompt_for(RIVAL))


func done(action: Dictionary) -> void:
	if bool(action.get("advance", false)):
		index += 1


## Per option of `p`: open or not, and Caedan's reason for every one that is not.
func gate(step: Dictionary, p: PromptView, v: SeatView) -> Dictionary:
	var enabled: Array[bool] = []
	var reasons: Array[String] = []
	for o in p.options:
		var open: bool = _taken(step, o, v)
		enabled.append(open)
		reasons.append("" if open else reason(step, o))
	return {"enabled": enabled, "reasons": reasons, "library": str(step.get("library", data.get("reason", "")))}


func reason(step: Dictionary, o: OptionView) -> String:
	var by_type: Dictionary = step.get("reasons", {})
	return str(by_type.get(String(o.type), data.get("reason", "")))


## Plays on with a stand-in player who takes the first open option and skips through every stop,
## until step `stop` is the next one or the script ends. `choose` may pick another open option:
## it gets the action and returns an option index, or -1 for the first open one. Returns "" or
## why it stopped short.
func fast_forward(referee: Referee, stop: int, choose: Callable = Callable()) -> String:
	for _i in range(MAX_STEPS):
		if index >= stop or finished():
			return ""
		var problem: String = play_one(referee, choose)
		if problem != "":
			return problem
	return "the script did not reach step %d" % stop


## Carries out one action with the stand-in player. "" or why not.
func play_one(referee: Referee, choose: Callable = Callable()) -> String:
	var action: Dictionary = next_for(referee)
	var problem: String = ""
	match str(action["do"]):
		"say", "bark":
			pass
		"op":
			problem = referee.script(action["op"])
		"rival":
			problem = referee.submit(RIVAL, action["wire"])
		"player":
			var p: PromptView = referee.prompt_for(PLAYER)
			var pick: int = int(choose.call(action)) if choose.is_valid() else -1
			if pick < 0:
				pick = first_open(action["gate"])
			if pick < 0:
				return "no open option at lesson %d beat %d" % [lesson(), int(action["step"].get("b", -1))]
			problem = referee.submit(PLAYER, p.options[pick].to_command(PLAYER).to_dict())
		"end":
			return ""
		_:
			return "lesson %d: %s" % [lesson(), str(action.get("why", "the script stalled"))]
	if problem != "":
		return "lesson %d beat %d: %s" % [lesson(), int((action.get("step", {}) as Dictionary).get("b", -1)), problem]
	done(action)
	return ""


static func first_open(g: Dictionary) -> int:
	var enabled: Array = g.get("enabled", [])
	for i in range(enabled.size()):
		if bool(enabled[i]):
			return i
	return -1


# --- Matching -------------------------------------------------------------------

func _waited(wait: Dictionary, prompt: PromptView, rival_prompt: PromptView) -> bool:
	var p: PromptView = prompt if int(wait.get("seat", PLAYER)) == PLAYER else rival_prompt
	return p != null and String(p.kind) == str(wait.get("kind", ""))


func _fits(step: Dictionary, kind: String, p: PromptView, v: SeatView) -> bool:
	if String(p.kind) != kind:
		return false
	for o in p.options:
		if _taken(step, o, v):
			return true
	return false


func _taken(step: Dictionary, o: OptionView, v: SeatView) -> bool:
	var takes: Array = step["take"] if step.get("take") is Array else [step.get("take", {})]
	for t in takes:
		if _matches(o, t, v):
			return true
	return false


func _first_taken(step: Dictionary, p: PromptView, v: SeatView) -> OptionView:
	for o in p.options:
		if _taken(step, o, v):
			return o
	return p.options[0]


static func _matches(o: OptionView, take: Dictionary, v: SeatView) -> bool:
	if take.has("type") and String(o.type) != str(take["type"]):
		return false
	if take.has("value") and not _same(o.value, take["value"]):
		return false
	if take.has("id"):
		var c: SeatCard = v.card(o.card) if o.card >= 0 and v != null else null
		if c == null or c.def_id != str(take["id"]):
			return false
	return true


## JSON reads every number as a float, so a number compares by value and anything else as text.
static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return str(a) == str(b)


func _rival_quietly(p: PromptView, v: SeatView) -> Dictionary:
	return {"do": "rival", "wire": quiet_option(p).to_command(RIVAL).to_dict(), "advance": false, "step": {}}


## The rival's answer to a prompt the script does not name: the quietest option, a "no" to any
## "you may", or the first option.
static func quiet_option(p: PromptView) -> OptionView:
	for quiet in QUIET:
		for o in p.options:
			if o.type == quiet:
				return o
	for o in p.options:
		if o.type == &"pick_option" and str(o.value) == "no":
			return o
	return p.options[0]


func _mismatch(step: Dictionary, prompt: PromptView, why: String) -> Dictionary:
	var open: Dictionary = {}
	if prompt != null:
		var enabled: Array[bool] = []
		var reasons: Array[String] = []
		for o in prompt.options:
			enabled.append(true)
			reasons.append("")
		open = {"enabled": enabled, "reasons": reasons, "library": ""}
	var at: String = "beat %d" % int(step.get("b", -1))
	var pending: String = "the player's %s" % String(prompt.kind) if prompt != null else "no player prompt"
	return {"do": "mismatch", "step": step, "gate": open, "advance": false, "why": "%s %s, but %s is up" % [at, why, pending]}


## An op as the referee takes it: a deck named by key becomes the full list, so the history of the
## session holds everything needed to replay it.
func _expanded(op: Dictionary) -> Dictionary:
	var out: Dictionary = op.duplicate(true)
	if out.get("deck") is String:
		out["deck"] = decks.get(str(out["deck"]), {})
	return out
