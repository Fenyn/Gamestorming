class_name AiProfile
extends RefCounted
## How one AI opponent values things. Everything is data: `own` weighs the AI's side of the
## table, `foe` weighs the opponent's, `effect` weighs card effect ops, and the knobs set how hard
## it thinks. A profile file only needs the entries it changes; the rest come from DEFAULTS.

const DIR: String = "res://data/ai/profiles"

const DEFAULTS: Dictionary = {
	"own": {
		"life": 1.0, "life_low": 1.5, "discard": 0.05, "energy": 0.6, "band": 1.0, "hand": 1.2,
		"aspect": 4.0, "ascension": 30.0, "fervor": 0.0, "seal": 25.0, "seal_guard": 6.0, "ally": 2.5, "ally_energy": 0.3, "drill": 2.0,
		"non_combat": 1.5, "attachment": 1.5, "forbid": 1.0, "grounds": 8.0,
	},
	"foe": {
		"life": 1.0, "life_low": 1.5, "discard": 0.05, "energy": 0.6, "band": 1.0, "hand": 1.0,
		"aspect": 4.0, "ascension": 30.0, "seal": 25.0, "seal_guard": 6.0, "ally": 2.5, "ally_energy": 0.3, "drill": 2.0,
		"non_combat": 1.5, "attachment": 1.5, "forbid": 1.0, "grounds": 8.0,
	},
	"effect": {
		"energy": 0.6, "fervor": 2.0, "draw": 1.2, "search": 1.8, "discard_in_play": 2.2,
		"discard_hand": 1.0, "discard_life": 1.0, "recover": 0.8, "remove_discard": 0.15,
		"forbid": 1.5, "float": 1.0, "stop_all": 2.5, "attach": 1.5, "capture_seal": 3.0,
		"other": 0.5, "if_successful": 0.6, "if_stopped": 0.3, "conditional": 0.7,
	},
	"play": {
		"damage_life": 1.0, "damage_stage": 0.5, "attack_cost": 0.5, "final_strike_penalty": 4.0,
		"defend_card": 1.0, "defend_in_play": 0.3, "use_cost": 0.3, "declare_bias": 0.5, "control_ally": 0.0, "grounds_skip": 0.6,
		# Off by default. Above zero, a hand holding cards that only work inside Combat is a reason
		# to declare one, which is the only reason a deck that never attacks would ever open Combat.
		"declare_use": 0.0,
		# Off by default. Above zero, a searching card is worth this share of the best card it can
		# reach, compounding down a chain, so a deck built around a combo goes and assembles it.
		"tutor_decay": 0.0, "bond_band": 0.0,
	},
	"reserve": {"tech": 3.0, "threshold": 1.0, "toolbox_keep": 2.0, "max_swaps": 4},
	# Matchup pivots, keyed by what the deck across the table declares itself to be. An archetype id
	# on its own, or "+<subtheme>" for one of its subthemes. Each value is a partial profile laid
	# over this one when that opponent is faced. Empty here: a deck opts in by listing its own.
	"vs": {},
	# Pivots that turn on partway through a duel, keyed by a fact about our own side of the table,
	# all of it public: `bonded` (a personality of ours has cards stacked under it), `allies_min:N`,
	# `aspect_min:N`, `fervor_min:N`, `seals_min:N`, `life_below:N`. Laid on after the matchup
	# pivots, so a deck can hold back until its plan is on the table and then press.
	"when": {},
	"think": {"search": true, "algorithm": "sequence", "top_k": 6, "samples": 2,
		"budget_ms": 1600, "max_steps": 80, "turns": 1, "noise": 0.0, "prior": 0.05,
		"sequence_depth": 6, "branch_width": 3, "response_width": 2, "node_budget": 6000,
		# 0 or 1 keeps every candidate; between them it drops the ones the move ordering already
		# puts far behind the leader. See AiSearch._within_margin.
		"branch_margin": 0.0,
		# 1 skips starting a depth that is projected not to finish before the deadline.
		# See AiSearch._depth_will_not_fit.
		"predict_depth": 0,
		# Prompt kinds answered by the scorer alone. See AiProfile.scorer_decides.
		"scorer_kinds": [],
		"rollout_steps": 4, "settle_steps": 8, "intent_margin": 0.15, "cache": false,
		# Stop deepening once the same option has been best for this many completed depths running
		# and leads the next by `settle_lead`. 0 spends the whole budget every time.
		"settle_plies": 0, "settle_lead": 0.0},
}

var name: String = "default"
var data: Dictionary = DEFAULTS.duplicate(true)


static func default_profile() -> AiProfile:
	return AiProfile.new()


static func load_from(path: String) -> AiProfile:
	var p: AiProfile = AiProfile.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "AI profile %s is not a JSON object" % path)
	p.merge(parsed)
	return p


## The profile for an AI playing `deck` at `level`: the defaults, then the deck's playstyle file
## (what it values), then the level file (how hard it thinks). Either name may be "".
static func for_deck(deck: DeckList, level: String) -> AiProfile:
	var p: AiProfile = AiProfile.new()
	var names: Array[String] = [deck.ai_profile if deck != null else "", level]
	for file in names:
		var path: String = DIR.path_join(file + ".json")
		if file == "" or not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			p.merge(parsed)
	return p


## A copy of this profile with its `vs` entries for the deck across the table laid on top, so one
## deck can turtle against a beatdown and press against a slow one. The archetype and its subthemes
## are declared to both players, so reading them is fair; nothing here looks at their cards.
##
## The archetype is applied first and the subthemes after, in the order the deck declares them, so
## the finer statement wins. Returns this profile untouched when it names no pivots.
func for_matchup(archetype: String, subthemes: Array) -> AiProfile:
	var pivots: Dictionary = data.get("vs", {})
	if pivots.is_empty():
		return self
	var keys: Array[String] = [archetype]
	for s in subthemes:
		keys.append("+" + str(s))
	var applied: Array[String] = []
	for k in keys:
		if pivots.has(k) and pivots[k] is Dictionary:
			applied.append(k)
	if applied.is_empty():
		return self
	var out: AiProfile = AiProfile.new()
	out.name = name
	out.data = data.duplicate(true)
	for k in applied:
		out.merge(pivots[k])
	return out


## Which `when` facts hold right now, as a stable key. "" when the profile names no state pivots,
## which is the common case and costs nothing.
func state_key(view: SeatView, seat: int) -> String:
	var pivots: Dictionary = data.get("when", {})
	if pivots.is_empty():
		return ""
	var hit: PackedStringArray = PackedStringArray()
	for k in pivots.keys():
		if _fact_holds(str(k), view, seat):
			hit.append(str(k))
	return "|".join(hit)


## A copy with the `when` pivots named by `key` laid on, in the order the profile lists them.
func for_state(key: String) -> AiProfile:
	if key == "":
		return self
	var pivots: Dictionary = data.get("when", {})
	var wanted: PackedStringArray = key.split("|")
	var out: AiProfile = AiProfile.new()
	out.name = name
	out.data = data.duplicate(true)
	for k in pivots.keys():
		if wanted.has(str(k)) and pivots[k] is Dictionary:
			out.merge(pivots[k])
	return out


## The same key as `state_key`, read straight off the engine. Every fact below is something the
## seat already knows about its own side, so this reads no more than the SeatView path did; it
## only skips building one. `SeatView.of` measured at 1135 us and the search paid it per world per
## node, which doubled the cost of every deck whose profile carries a `when` block.
## `test_profile_state_key_matches_the_seat_view` holds the two paths together.
func state_key_of(engine: DuelEngine, seat: int) -> String:
	var pivots: Dictionary = data.get("when", {})
	if pivots.is_empty():
		return ""
	var hit: PackedStringArray = PackedStringArray()
	for k in pivots.keys():
		if _fact_holds_engine(str(k), engine, seat):
			hit.append(str(k))
	return "|".join(hit)


static func _fact_holds_engine(key: String, engine: DuelEngine, seat: int) -> bool:
	var fact: String = key
	var n: int = 0
	var colon: int = key.find(":")
	if colon >= 0:
		fact = key.substr(0, colon)
		n = int(key.substr(colon + 1))
	var me: PlayerState = engine.player(seat)
	match fact:
		"bonded":
			for ally in me.allies():
				if ally.cards_under.size() > 0:
					return true
			return false
		"allies_min":
			return me.allies().size() >= n
		"aspect_min":
			return me.duelist != null and me.duelist.aspect >= n
		"fervor_min":
			return me.fervor >= n
		"seals_min":
			return me.seals().size() >= n
		"life_below":
			return me.life_deck.size() < n
	return false


## One `when` fact, read off the seat's own view so it sees only what the table shows.
static func _fact_holds(key: String, view: SeatView, seat: int) -> bool:
	var fact: String = key
	var n: int = 0
	var colon: int = key.find(":")
	if colon >= 0:
		fact = key.substr(0, colon)
		n = int(key.substr(colon + 1))
	var me: SeatPlayer = view.player(seat)
	match fact:
		"bonded":
			# Card-agnostic: a fused personality is one with its partners stacked underneath.
			for uid in me.allies:
				var c: SeatCard = view.card(uid)
				if c != null and c.under > 0:
					return true
			return false
		"allies_min":
			return me.allies.size() >= n
		"aspect_min":
			var d: SeatCard = view.card(me.duelist)
			return d != null and d.aspect >= n
		"fervor_min":
			return me.fervor >= n
		"seals_min":
			return me.seals.size() >= n
		"life_below":
			return me.life_deck.size() < n
	return false


## Lays `over` on top of what is here, group by group.
func merge(over: Dictionary) -> void:
	name = str(over.get("name", name))
	for group in over.keys():
		if not (over[group] is Dictionary) or not data.has(group):
			continue
		var target: Dictionary = data[group]
		var source: Dictionary = over[group]
		for key in source.keys():
			target[key] = source[key]


func w(group: String, key: String) -> float:
	var g: Dictionary = data.get(group, {})
	return float(g.get(key, 0.0))


func think_int(key: String) -> int:
	return int(w("think", key))


func searches() -> bool:
	var g: Dictionary = data["think"]
	return bool(g.get("search", true))


## Prompt kinds this profile answers with the scorer alone, skipping the search. Measured
## 2026-09-20 with tools/decision_agreement.gd: on these kinds the scorer already picks what the
## search picks most of the time, so the search spent its budget re-deriving the same answer.
func scorer_decides(kind: StringName) -> bool:
	var kinds: Array = (data["think"] as Dictionary).get("scorer_kinds", [])
	return kinds.has(String(kind))
