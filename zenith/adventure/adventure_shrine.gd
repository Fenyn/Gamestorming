class_name AdventureShrine
extends RefCounted
## The Shrine node (design 7.7). Three offers, rolled once from the run seed and the node and saved
## with the run: two Resonances that serve the run's starter (its archetype and subthemes), any
## others when fewer than two do, and one style Resonance, which carries a penalty. A Resonance the
## run already holds is never offered. The player takes one or leaves with none; either ends the
## visit. The run stands on the node with status "shrine" until then.
##
## A won Elite ends with the same offer, the claim (AdventureElite.open_claim): status "claim",
## rolled on the claim's own seed, taken or left the same way.

const KIND: String = "resonance"
const STATUS: String = "shrine"
const CLAIM_STATUS: String = "claim"
const THEMED: int = 2
const STYLE: int = 1


## True while the run stands on a Shrine or an Elite's claim with its offers open.
static func is_open(run: AdventureRun) -> bool:
	return run != null and (run.status == STATUS or run.status == CLAIM_STATUS)


static func is_claim(run: AdventureRun) -> bool:
	return run != null and run.status == CLAIM_STATUS


## Rolls the offers of the Shrine or claim the run stands on, the first time only.
static func open(run: AdventureRun) -> void:
	if not is_open(run) or not run.shrine_offers.is_empty():
		return
	run.shrine_offers = claim_roll(run, run.node_id) if is_claim(run) else roll(run, run.node_id)


## The offers a Shrine on node `id` would make the run as it stands: the themed ones first, then the
## style one.
static func roll(run: AdventureRun, id: String) -> Array[String]:
	return _roll_seeded(run, run.shrine_seed(id))


## The offers the claim after a won Elite on node `id` would make, by the same rules on its own seed.
static func claim_roll(run: AdventureRun, id: String) -> Array[String]:
	return _roll_seeded(run, run.claim_seed(id))


static func _roll_seeded(run: AdventureRun, seed_value: int) -> Array[String]:
	var rng: ZenithRng = ZenithRng.new(seed_value)
	var themes: Array[String] = run_themes(run)
	var themed: Array[String] = []
	var others: Array[String] = []
	var style: Array[String] = []
	for resonance in ResonanceData.ids():
		if run.resonances.has(resonance):
			continue
		if ResonanceData.is_style(resonance):
			style.append(resonance)
		elif serves(resonance, themes):
			themed.append(resonance)
		else:
			others.append(resonance)
	rng.shuffle(themed)
	rng.shuffle(others)
	rng.shuffle(style)
	var out: Array[String] = []
	for resonance in themed + others:
		if out.size() >= THEMED:
			break
		out.append(resonance)
	for i in range(mini(STYLE, style.size())):
		out.append(style[i])
	return out


## What the run's starter is built around: its archetype and its subthemes.
static func run_themes(run: AdventureRun) -> Array[String]:
	var out: Array[String] = []
	var starter: DeckList = DeckList.resolve(run.starter_id)
	if starter == null:
		return out
	if starter.archetype != "":
		out.append(starter.archetype)
	for theme in starter.subthemes:
		if not out.has(theme):
			out.append(theme)
	return out


static func serves(resonance: String, themes: Array[String]) -> bool:
	for tag in ResonanceData.tags_of(resonance):
		if themes.has(tag):
			return true
	return false


## The word an offer's chip shows: STYLE for a style Resonance, else the first of its subthemes the
## run is built around, else its first tag. An archetype id matches but never names the chip.
static func chip_tag(run: AdventureRun, resonance: String) -> String:
	if ResonanceData.is_style(resonance):
		return "style"
	var tags: Array[String] = ResonanceData.tags_of(resonance)
	var themes: Array[String] = run_themes(run)
	for tag in tags:
		if themes.has(tag) and not Archetype.known(tag):
			return tag
	return tags[0] if not tags.is_empty() else ""


## Takes offer `index`: the run holds that Resonance for the rest of the run, the pick is recorded,
## and the visit is over. False, and nothing moves, when the run is not on a Shrine or a claim or the
## index is not an offer.
static func take(run: AdventureRun, index: int) -> bool:
	if not is_open(run) or index < 0 or index >= run.shrine_offers.size():
		return false
	var resonance: String = run.shrine_offers[index]
	if run.resonances.has(resonance) or not ResonanceData.has(resonance):
		return false
	run.resonances.append(resonance)
	AdventureRewards.record(run, KIND, resonance)
	run.shrine_offers.clear()
	run.status = "map"
	return true


## Ends the visit with nothing taken.
static func leave(run: AdventureRun) -> void:
	if not is_open(run):
		return
	run.shrine_offers.clear()
	run.status = "map"
