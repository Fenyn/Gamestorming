class_name AdventureElite
extends RefCounted
## The Elite node (design 7.2). An Elite draws its opponent from the band a Duel on the same node
## would, and that opponent holds Resonances of its own: `elite_resonances` per act in map.json,
## drawn from the ones that serve the opponent family's archetype and subthemes and from the style
## ones, at most MAX_STYLE of those, never two of the same. The draw comes from the run seed and
## the node, so a regenerated map holds the same ones and nothing is saved.
##
## Winning an Elite ends with a claim: after the Aspect and bundle steps the run is offered three
## Resonances by the Shrine's rules (AdventureShrine), on the claim's own seed, and may take none.

const MAX_STYLE: int = 1

static var _themes: Dictionary = {}   # opponent id -> Array[String]


## What an opponent deck is built around: its archetype, then its family's subthemes. The opponent
## tiers carry only the archetype, so the subthemes come from the family's starter.
static func themes_of(opponent_id: String) -> Array[String]:
	if _themes.has(opponent_id):
		return (_themes[opponent_id] as Array[String]).duplicate()
	var out: Array[String] = []
	var deck: DeckList = _deck_if_present(opponent_id)
	if deck != null and deck.archetype != "":
		out.append(deck.archetype)
	var starter: DeckList = _deck_if_present("%s_start" % AdventureDecks.family_of(opponent_id))
	if starter != null:
		if starter.archetype != "" and not out.has(starter.archetype):
			out.append(starter.archetype)
		for theme in starter.subthemes:
			if not out.has(theme):
				out.append(theme)
	_themes[opponent_id] = out.duplicate()
	return out


## The Resonances the opponent `opponent_id` holds on an Elite: `count` of them, the non-style ones
## that serve its themes and the style ones shuffled together, no more than MAX_STYLE style ones,
## and any other non-style ones only when those run out.
static func resonances_for(opponent_id: String, count: int, seed_value: int) -> Array[String]:
	var out: Array[String] = []
	if count <= 0:
		return out
	var themes: Array[String] = themes_of(opponent_id)
	var fitting: Array[String] = []
	var others: Array[String] = []
	for id in ResonanceData.ids():
		if ResonanceData.is_style(id) or AdventureShrine.serves(id, themes):
			fitting.append(id)
		else:
			others.append(id)
	var rng: ZenithRng = ZenithRng.new(seed_value)
	rng.shuffle(fitting)
	rng.shuffle(others)
	var styles: int = 0
	for id in fitting + others:
		if out.size() >= count:
			break
		if ResonanceData.is_style(id):
			if styles >= MAX_STYLE:
				continue
			styles += 1
		out.append(id)
	return out


## The seed an Elite's Resonances are drawn from.
static func seed_for(run_seed: int, node_id: String) -> int:
	return hash("%d:%s:elite" % [run_seed, node_id])


## The opponent's deck for a map duel row, holding the row's Resonances. Null when the deck is
## missing.
static func opponent_deck(row: Dictionary) -> DeckList:
	var deck: DeckList = DeckList.resolve(str(row.get("opponent", "")))
	if deck == null:
		return null
	deck.resonances = resonances_of(row)
	return deck


## The Resonances a map duel row's opponent holds; empty for anyone but an Elite.
static func resonances_of(row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in row.get("resonances", []):
		out.append(str(id))
	return out


## After the reward steps of a won Elite: the run stands on the claim with three offers, or goes
## straight back to the map when there is nothing left to offer. Any other node leaves the run
## where it is.
static func open_claim(run: AdventureRun, map: AdventureMap) -> void:
	if run.status != "map" or str(map.node(run.node_id).get("type", "")) != "elite":
		return
	run.status = AdventureShrine.CLAIM_STATUS
	run.shrine_offers.clear()
	AdventureShrine.open(run)
	if run.shrine_offers.is_empty():
		run.status = "map"


static func _deck_if_present(deck_id: String) -> DeckList:
	for dir in DeckList.DIRS:
		var path: String = "%s/%s.json" % [dir, deck_id]
		if FileAccess.file_exists(path):
			return DeckList.load_from(path)
	return null
