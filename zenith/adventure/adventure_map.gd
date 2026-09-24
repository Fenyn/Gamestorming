class_name AdventureMap
extends RefCounted
## The run's node map: three acts, each seven tiers of nodes joined by random connections and one
## boss node at tier 8. Rolled from the run seed and never saved: the same seed rolls the same map
## on resume. The numbers live in data/adventure/map.json; the design is section 7.1 of
## designs/zenith_adventure.md.

const DATA: String = "res://data/adventure/map.json"
## Tiers 1 to 7 are the paths; tier 8 is the boss.
const PATH_TIERS: int = 7
const BOSS_TIER: int = 8
## Node types that put the player in a duel. The boss counts as one but never towards the per-path
## count, which covers tiers 1 to 7 only.
const FIGHT_TYPES: Array[String] = ["duel", "elite", "key", "twist", "encounter", "boss"]
## Type rolls tried on one layout before a fresh layout is drawn, and layouts tried per act.
const TYPE_ATTEMPTS: int = 40
const LAYOUT_ATTEMPTS: int = 40

var starter_id: String = ""
var run_seed: int = 0
## id -> node: {id, act, tier, lane, type, next: Array[String]}. A fighting node also carries
## `duel`, the row a ladder stage used to be: {opponent, tier, band, ai_level, grant, story, node},
## plus `guest` on an Encounter: the personality card that starts in play on the player's side.
## Inside `duel`, `tier` is the opponent deck's tier (t1..t5, boss), not the map tier.
var nodes: Dictionary = {}
var acts: int = 0
## How many lanes a tier spreads across, for drawing.
var lanes: int = 4


static func generate(starter_id_value: String, run_seed_value: int) -> AdventureMap:
	var data: Dictionary = read_data()
	var bands: Dictionary = AdventureDecks.read_bands()
	if data.is_empty() or bands.is_empty():
		push_error("AdventureMap: cannot read %s or %s" % [DATA, AdventureDecks.BANDS])
		return null
	var map: AdventureMap = AdventureMap.new()
	map.starter_id = starter_id_value
	map.run_seed = run_seed_value
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:map" % [starter_id_value, run_seed_value])
	# Random draws never meet the run's own character; a storyline's set boss may.
	var own: Array[String] = AdventureDecks.same_character_families(AdventureDecks.family_of(starter_id_value))
	var guests: Array[String] = AdventureStory.guests_for(starter_id_value)
	var story_bosses: Array[String] = []
	var specs: Array = data.get("acts", [])
	for a in range(specs.size()):
		var set_boss: String = str(AdventureStory.boss_for(starter_id_value, a + 1).get("family", ""))
		if set_boss != "":
			story_bosses.append(set_boss)
	map.acts = specs.size()
	map.lanes = int(data.get("lanes", 4))
	var bosses: Array[String] = []
	var previous_boss: String = ""
	for a in range(specs.size()):
		var act: int = a + 1
		var spec: Dictionary = specs[a]
		var act_nodes: Dictionary = {}
		for attempt in range(LAYOUT_ATTEMPTS):
			act_nodes = _roll_act(act, spec, data, rng)
			if not act_nodes.is_empty():
				break
		if act_nodes.is_empty():
			push_error("AdventureMap: act %d found no layout inside the fight range" % act)
			return null
		map.nodes.merge(act_nodes)
		if previous_boss != "":
			(map.nodes[previous_boss]["next"] as Array).append_array(map.ids_at(act, 1))
		# The boss is drawn first so the tier 7 fights just before it can steer clear of its family.
		var boss_family: String = map._draw_boss(act, a == specs.size() - 1, spec, data, bands, own, bosses, rng)
		if boss_family == "":
			push_error("AdventureMap: no boss for act %d of %s" % [act, starter_id_value])
			return null
		map._fill_duels(act, spec, bands, own, previous_boss, boss_family,
			str((data.get("final_boss", {}) as Dictionary).get("family", "")), story_bosses, guests, rng)
		bosses.append(boss_family)
		previous_boss = boss_id_of(act)
	return map


# --- Reading the map --------------------------------------------------------

func node(id: String) -> Dictionary:
	return nodes.get(id, {})


## The duel a fighting node puts the player in, empty for any other node.
func duel_for(id: String) -> Dictionary:
	return node(id).get("duel", {})


func next_of(id: String) -> Array[String]:
	var out: Array[String] = []
	for n in node(id).get("next", []):
		out.append(str(n))
	return out


## Where a run begins: the tier 1 nodes of act 1.
func start_ids() -> Array[String]:
	return ids_at(1, 1)


## The nodes on one tier of one act, left to right.
func ids_at(act: int, tier: int) -> Array[String]:
	var found: Array[Dictionary] = []
	for id in nodes.keys():
		var n: Dictionary = nodes[id]
		if int(n["act"]) == act and int(n["tier"]) == tier:
			found.append(n)
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["lane"]) < int(y["lane"]))
	var out: Array[String] = []
	for n in found:
		out.append(str(n["id"]))
	return out


static func id_of(act: int, tier: int, lane: int) -> String:
	return "a%dt%dl%d" % [act, tier, lane]


static func boss_id_of(act: int) -> String:
	return "a%dt%d" % [act, BOSS_TIER]


static func is_fight(type: String) -> bool:
	return FIGHT_TYPES.has(type)


## The run's last node: beating it wins the run.
func final_id() -> String:
	return boss_id_of(acts)


## How far into the run a node sits, from 0.0 at act 1 tier 1 towards 1.0 at the final boss. The
## reward tier gates read it. -1.0 for an unknown node.
func progress_of(id: String) -> float:
	var n: Dictionary = node(id)
	if n.is_empty() or acts <= 0:
		return -1.0
	var step: int = (int(n["act"]) - 1) * BOSS_TIER + int(n["tier"]) - 1
	return float(step) / float(acts * BOSS_TIER)


## "act 2, tier 5", or "the act 2 boss", for the screens.
func place_of(id: String) -> String:
	var n: Dictionary = node(id)
	if n.is_empty():
		return "the start"
	if int(n["tier"]) == BOSS_TIER:
		return "the act %d boss" % int(n["act"])
	return "act %d, tier %d" % [int(n["act"]), int(n["tier"])]


## One line on what a node type does, for the screens.
static func type_blurb(type: String) -> String:
	match type:
		"duel":
			return "An ordinary duel."
		"elite":
			return "A duel against a stronger deck, for a better reward."
		"key":
			return "A meeting with a character the story wants you to reach."
		"boss":
			return "The act's boss, with two lives."
		"twist":
			return "A duel under a stated special rule."
		"encounter":
			return "A duel with an ally fighting beside you."
		"sensei":
			return "Choose your Sensei: a Relic and a starting Reserve."
		"shop":
			return "Spend Mana on cards and services."
		"shrine":
			return "Choose a Resonance to carry through the run."
		"forge":
			return "Cut cards from the deck, or copy one already in it."
		"mystery":
			return "Something waits here."
	return ""


## What a screen calls a node type.
static func type_name(type: String) -> String:
	match type:
		"key":
			return "Key character"
		_:
			return type.capitalize()


## The fewest and most fighting nodes on any path through tiers 1 to 7 of `act`.
func fight_range(act: int) -> Vector2i:
	return _fight_range_of(_act_nodes(act))


## How many paths through tiers 1 to 7 of `act` hold each fight count: {count: paths}.
func path_fight_counts(act: int) -> Dictionary:
	var act_nodes: Dictionary = _act_nodes(act)
	var ways: Dictionary = {}  # id -> {fights so far: paths}
	for tier in range(1, PATH_TIERS + 1):
		for id in _ids_at_in(act_nodes, tier):
			var here: int = 1 if is_fight(str(act_nodes[id]["type"])) else 0
			var counts: Dictionary = {}
			if tier == 1:
				counts[here] = 1
			for parent in _parents_in(act_nodes, id):
				var from: Dictionary = ways[parent]
				for k in from.keys():
					counts[int(k) + here] = int(counts.get(int(k) + here, 0)) + int(from[k])
			ways[id] = counts
	var out: Dictionary = {}
	for id in _ids_at_in(act_nodes, PATH_TIERS):
		var counts: Dictionary = ways[id]
		for k in counts.keys():
			out[int(k)] = int(out.get(int(k), 0)) + int(counts[k])
	return out


func _act_nodes(act: int) -> Dictionary:
	var out: Dictionary = {}
	for id in nodes.keys():
		if int(nodes[id]["act"]) == act:
			out[id] = nodes[id]
	return out


# --- Rolling one act ----------------------------------------------------------

## One act's nodes with their types, or {} when this layout found no type roll inside the fight
## range. Duels are filled in afterwards, once the previous act's boss is linked.
static func _roll_act(act: int, spec: Dictionary, data: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var lanes: int = int(data.get("lanes", 4))
	var walks: int = int(data.get("walks", 4))
	var act_nodes: Dictionary = _roll_layout(act, lanes, walks, rng)
	var bounds: Array = data.get("fights_per_path", [2, 5])
	for attempt in range(TYPE_ATTEMPTS):
		_roll_types(act_nodes, act, spec, data, rng)
		var got: Vector2i = _fight_range_of(act_nodes)
		if got.x >= int(bounds[0]) and got.y <= int(bounds[1]):
			return act_nodes
	return {}


## Paths drawn in the Slay the Spire manner: `walks` walks climb from tier 1 to tier 7, each step
## going up-left, up or up-right, never crossing an edge already drawn. The first two walks start
## in different lanes so tier 1 always offers a choice. Every tier 7 node leads to the boss.
static func _roll_layout(act: int, lanes: int, walks: int, rng: RandomNumberGenerator) -> Dictionary:
	var present: Array[Dictionary] = []   # per tier index: lane -> true
	var edges: Array[Array] = []          # per tier index: [from lane, to lane] pairs
	for t in range(PATH_TIERS):
		present.append({})
		edges.append([])
	var first_lane: int = -1
	for w in range(walks):
		var lane: int = rng.randi_range(0, lanes - 1)
		if w == 0:
			first_lane = lane
		elif w == 1:
			while lane == first_lane:
				lane = rng.randi_range(0, lanes - 1)
		present[0][lane] = true
		for t in range(PATH_TIERS - 1):
			var options: Array[int] = []
			for step in [-1, 0, 1]:
				var to: int = lane + int(step)
				if to >= 0 and to < lanes and not _crosses(edges[t], lane, to):
					options.append(to)
			# Straight up never crosses, because every edge moves at most one lane.
			var chosen: int = options[rng.randi_range(0, options.size() - 1)]
			var pair: Array = [lane, chosen]
			if not edges[t].has(pair):
				edges[t].append(pair)
			present[t + 1][chosen] = true
			lane = chosen
	var out: Dictionary = {}
	var boss: String = boss_id_of(act)
	for t in range(PATH_TIERS):
		var tier: int = t + 1
		var tier_lanes: Array = present[t].keys()
		tier_lanes.sort()
		for l in tier_lanes:
			var id: String = id_of(act, tier, int(l))
			var next: Array[String] = []
			if tier == PATH_TIERS:
				next.append(boss)
			else:
				var to_lanes: Array[int] = []
				for pair in edges[t]:
					if int(pair[0]) == int(l):
						to_lanes.append(int(pair[1]))
				to_lanes.sort()
				for to in to_lanes:
					next.append(id_of(act, tier + 1, to))
			out[id] = {"id": id, "act": act, "tier": tier, "lane": int(l), "type": "", "next": next}
	out[boss] = {"id": boss, "act": act, "tier": BOSS_TIER, "lane": int((lanes - 1) / 2.0),
		"type": "boss", "next": [] as Array[String]}
	return out


## True when an edge from lane `a` to lane `b` would cross one already drawn on the same tier.
static func _crosses(tier_edges: Array, a: int, b: int) -> bool:
	for pair in tier_edges:
		var c: int = int(pair[0])
		var d: int = int(pair[1])
		if (c < a and d > b) or (c > a and d < b):
			return true
	return false


## Tier 1 is always a duel, and the Sensei tier is all Sensei so every path meets one. Every other
## node is a fight with the act's `fight_chance`, else a rest node that differs from its parents'.
## An Elite waits until the act's `elite_from` tier.
static func _roll_types(act_nodes: Dictionary, act: int, spec: Dictionary, data: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var sensei: Dictionary = data.get("sensei", {})
	var chance: float = float(spec.get("fight_chance", 0.5))
	var fight_weights: Dictionary = data.get("fight_weights", {"duel": 1})
	var rest_weights: Dictionary = data.get("rest_weights", {"forge": 1})
	for tier in range(1, PATH_TIERS + 1):
		for id in _ids_at_in(act_nodes, tier):
			var type: String = ""
			if tier == 1:
				type = "duel"
			elif act == int(sensei.get("act", 0)) and tier == int(sensei.get("tier", 0)):
				type = "sensei"
			elif rng.randf() < chance:
				var weights: Dictionary = fight_weights.duplicate()
				if tier < int(spec.get("elite_from", 1)):
					weights.erase("elite")
				type = _weighted(weights, rng)
			else:
				var weights: Dictionary = rest_weights.duplicate()
				for parent in _parents_in(act_nodes, id):
					var parent_type: String = str(act_nodes[parent]["type"])
					if weights.size() > 1 and weights.has(parent_type):
						weights.erase(parent_type)
				type = _weighted(weights, rng)
			act_nodes[id]["type"] = type


static func _weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var keys: Array = weights.keys()
	keys.sort()
	var total: float = 0.0
	for k in keys:
		total += maxf(0.0, float(weights[k]))
	if total <= 0.0:
		return str(keys[0]) if not keys.is_empty() else "duel"
	var roll: float = rng.randf() * total
	for k in keys:
		roll -= maxf(0.0, float(weights[k]))
		if roll < 0.0:
			return str(k)
	return str(keys[keys.size() - 1])


## The fewest and most fighting nodes on any path through tiers 1 to 7 of one act's nodes.
static func _fight_range_of(act_nodes: Dictionary) -> Vector2i:
	var lo: Dictionary = {}
	var hi: Dictionary = {}
	for tier in range(1, PATH_TIERS + 1):
		for id in _ids_at_in(act_nodes, tier):
			var here: int = 1 if is_fight(str(act_nodes[id]["type"])) else 0
			var parents: Array[String] = _parents_in(act_nodes, id)
			if tier == 1 or parents.is_empty():
				lo[id] = here
				hi[id] = here
				continue
			var best_lo: int = 1 << 30
			var best_hi: int = -1
			for parent in parents:
				best_lo = mini(best_lo, int(lo[parent]))
				best_hi = maxi(best_hi, int(hi[parent]))
			lo[id] = best_lo + here
			hi[id] = best_hi + here
	var out: Vector2i = Vector2i(1 << 30, -1)
	for id in _ids_at_in(act_nodes, PATH_TIERS):
		out.x = mini(out.x, int(lo[id]))
		out.y = maxi(out.y, int(hi[id]))
	return out


static func _ids_at_in(act_nodes: Dictionary, tier: int) -> Array[String]:
	var found: Array[Dictionary] = []
	for id in act_nodes.keys():
		if int(act_nodes[id]["tier"]) == tier:
			found.append(act_nodes[id])
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["lane"]) < int(y["lane"]))
	var out: Array[String] = []
	for n in found:
		out.append(str(n["id"]))
	return out


## The nodes of the same act that lead into `id`.
static func _parents_in(act_nodes: Dictionary, id: String) -> Array[String]:
	var out: Array[String] = []
	for other in act_nodes.keys():
		if (act_nodes[other]["next"] as Array).has(id):
			out.append(str(other))
	out.sort()
	return out


# --- Opponents ----------------------------------------------------------------

## Gives every fighting node of tiers 1 to 7 its duel. A family is drawn from the node type's band,
## never one of `own` (the run's own character), and never one already met on a path into this node
## while the band still has another; failing that, never one met on the fight just before or just
## after (the boss, for tier 7). The final boss's family and the storyline's set bosses are kept for
## their own nodes while the band allows. An Encounter brings in one of `guests`, and becomes a
## plain duel for a run with none.
func _fill_duels(act: int, spec: Dictionary, bands: Dictionary, own: Array[String], previous_boss: String,
		boss_family_here: String, final_family: String, story_bosses: Array[String], guests: Array[String],
		rng: RandomNumberGenerator) -> void:
	var act_nodes: Dictionary = _act_nodes(act)
	var seen: Dictionary = {}  # id -> families met on some path up to and including this node
	var tiers: Array = spec.get("tiers", [])
	var boss_family: String = ""
	if previous_boss != "":
		boss_family = AdventureDecks.family_of(str(duel_for(previous_boss).get("opponent", "")))
	for tier in range(1, PATH_TIERS + 1):
		for id in _ids_at_in(act_nodes, tier):
			var before: Array[String] = []
			var parent_families: Array[String] = []
			var parents: Array[String] = _parents_in(act_nodes, id)
			if parents.is_empty() and boss_family != "":
				before.append(boss_family)
				parent_families.append(boss_family)
			for parent in parents:
				for f in seen[parent]:
					if not before.has(str(f)):
						before.append(str(f))
				var met: String = AdventureDecks.family_of(str(duel_for(parent).get("opponent", "")))
				if met != "" and not parent_families.has(met):
					parent_families.append(met)
			var type: String = str(nodes[id]["type"])
			if not is_fight(type):
				seen[id] = before
				continue
			if type == "encounter" and guests.is_empty():
				type = "duel"
				nodes[id]["type"] = type
			if tier == PATH_TIERS and not parent_families.has(boss_family_here):
				parent_families.append(boss_family_here)
			var neighbours_and_final: Array[String] = parent_families.duplicate()
			neighbours_and_final.append(final_family)
			neighbours_and_final.append_array(story_bosses)
			var everything: Array[String] = neighbours_and_final.duplicate()
			everything.append_array(before)
			var band: String = str(spec.get("elite_band" if type == "elite" else "band", "weaker"))
			# LORE: placeholder, make lore-relevant. A key character is a random opponent until
			# the character links name who the player is meant to meet here.
			var family: String = _draw(bands.get(band, []), own,
				[everything, neighbours_and_final, parent_families], rng)
			if parent_families.has(family):
				# The band has nothing but the neighbours left; a neighbouring band does.
				var excluded: Array[String] = own.duplicate()
				excluded.append_array(parent_families)
				for other in ["medium", "stronger", "weaker"]:
					var swap: String = _draw(bands.get(other, []), excluded, [everything], rng) \
						if other != band else ""
					if swap != "":
						family = swap
						band = other
						break
			var deck_tier: String = str(tiers[tier - 1]) if tier - 1 < tiers.size() else "t1"
			var ai: String = str(spec.get("elite_ai_level" if type == "elite" else "ai_level", "default"))
			var grant: String = "aspect" if tier == 1 and bool(spec.get("grant_first_tier", false)) else ""
			nodes[id]["duel"] = _duel_row(family, deck_tier, band, ai, grant, type)
			if type == "encounter":
				nodes[id]["duel"]["guest"] = guests[rng.randi_range(0, guests.size() - 1)]
			var after: Array[String] = before.duplicate()
			if not after.has(family):
				after.append(family)
			seen[id] = after


## The act's boss. The last act's boss is the final boss from map.json, unless that is the run's
## own character. A storyline's set boss comes next (AdventureStory). Every other boss is drawn
## from `boss_bands` in order, never the run's own character, the final boss or an earlier boss
## while any other remains.
func _draw_boss(act: int, last: bool, spec: Dictionary, data: Dictionary, bands: Dictionary,
		own: Array[String], earlier: Array[String], rng: RandomNumberGenerator) -> String:
	var final: Dictionary = data.get("final_boss", {})
	var final_family: String = str(final.get("family", ""))
	var deck_tier: String = str(spec.get("boss_tier", "boss"))
	var family: String = ""
	var band: String = ""
	var set_boss: String = str(AdventureStory.boss_for(starter_id, act).get("family", ""))
	if last and final_family != "" and not own.has(final_family):
		family = final_family
		deck_tier = str(final.get("tier", "boss"))
		band = _band_of(bands, family)
	elif set_boss != "":
		family = set_boss
		band = _band_of(bands, family)
	else:
		# LORE: placeholder, make lore-relevant. Act bosses of a starter without a storyline are
		# random. A run of the final boss's own deck has no final boss yet (build plan 6.7).
		var avoid: Array[String] = earlier.duplicate()
		if final_family != "":
			avoid.append(final_family)
		for b in spec.get("boss_bands", ["stronger"]):
			var pool: Array[String] = []
			for f in bands.get(str(b), []):
				if not own.has(str(f)) and not avoid.has(str(f)):
					pool.append(str(f))
			if not pool.is_empty():
				family = pool[rng.randi_range(0, pool.size() - 1)]
				band = str(b)
				break
		if family == "":
			family = _draw(bands.get("stronger", []), own, [earlier], rng)
			band = "stronger"
	if family == "":
		return ""
	var grant: String = "aspect" if bool(spec.get("boss_grant", false)) else ""
	var ai: String = str(spec.get("boss_ai_level", "default"))
	nodes[boss_id_of(act)]["duel"] = _duel_row(family, deck_tier, band, ai, grant, "boss")
	return family


static func _duel_row(family: String, deck_tier: String, band: String, ai: String, grant: String,
		type: String) -> Dictionary:
	return {
		"opponent": "%s_%s" % [family, deck_tier],
		"tier": deck_tier,
		"band": band,
		"ai_level": ai,
		"grant": grant,
		"story": "",
		"node": type,
	}


## A family from `members`, never one of `own`. Each list in `avoid_levels` is tried in turn as the
## set to avoid; the first level that leaves a choice wins, and with none left any non-own member
## will do.
static func _draw(members: Array, own: Array[String], avoid_levels: Array, rng: RandomNumberGenerator) -> String:
	var legal: Array[String] = []
	for f in members:
		if not own.has(str(f)):
			legal.append(str(f))
	if legal.is_empty():
		return ""
	for avoid in avoid_levels:
		var pool: Array[String] = []
		for f in legal:
			if not (avoid as Array).has(f):
				pool.append(f)
		if not pool.is_empty():
			return pool[rng.randi_range(0, pool.size() - 1)]
	return legal[rng.randi_range(0, legal.size() - 1)]


static func _band_of(bands: Dictionary, family: String) -> String:
	for b in bands.keys():
		if (bands[b] as Array).has(family):
			return str(b)
	return ""


static func read_data() -> Dictionary:
	return _read_json(DATA)


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
