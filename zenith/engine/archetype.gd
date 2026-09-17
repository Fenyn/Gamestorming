class_name Archetype
extends RefCounted
## What kind of deck a deck is: its label on the select screen and in the duel, and what an
## opponent may expect from it. A deck names one archetype and any number of subthemes in its
## JSON. The archetype is public, like the duelist and the Mastery; the card list is not.

## id -> {label, plan, signs}. `signs` are the kinds of card the deck is built around, 0 to 1,
## in the words AiPages uses: ally, drill, non_combat, seal.
const KINDS: Dictionary = {
	"strike_beatdown": {"label": "Strike beatdown", "plan": "Wins on wounds from a stream of Strikes.", "signs": {}},
	"art_beatdown": {"label": "Art beatdown", "plan": "Wins on wounds from Arts, paid for in Energy.", "signs": {}},
	"allies": {"label": "Allies", "plan": "Fills the table with Allies and lets them fight.", "signs": {"ally": 1.0}},
	"drills": {"label": "Drills", "plan": "Builds a row of Drills that make every attack heavier.", "signs": {"drill": 1.0, "non_combat": 0.6}},
	"seals": {"label": "Seals", "plan": "Collects a full set of Seals.", "signs": {"seal": 1.0, "non_combat": 0.5}},
	"ascension": {"label": "Ascension", "plan": "Climbs the Aspects on Fervor to win by Ascension.", "signs": {}},
	"control": {"label": "Control", "plan": "Stalls behind Non-Combats and blocks until the opponent runs dry.", "signs": {"non_combat": 1.0}},
}

## Subtheme id -> label. One word each, naming what the deck leans on beside its archetype:
## `energy` is attacking the opponent's Energy, `might` is caring who has the higher Might,
## `disruption` is stripping the opponent's hand and table. A subtheme may also imply signs.
const SUBTHEMES: Dictionary = {
	"fervor": "Fervor", "energy": "Energy", "draw": "Draw", "might": "Might", "disruption": "Disruption",
	"bond": "Bond", "arts": "Arts", "strikes": "Strikes", "swords": "Swords", "automatons": "Automatons",
	"seals": "Seals", "allies": "Allies", "drills": "Drills",
}
const SUBTHEME_SIGNS: Dictionary = {"seals": {"seal": 0.7}, "allies": {"ally": 0.7}, "drills": {"drill": 0.7}}
const DIFFICULTIES: Array[String] = ["easy", "medium", "hard"]


static func known(id: String) -> bool:
	return KINDS.has(id)


static func label(id: String) -> String:
	var entry: Dictionary = KINDS.get(id, {})
	return str(entry.get("label", ""))


static func plan(id: String) -> String:
	var entry: Dictionary = KINDS.get(id, {})
	return str(entry.get("plan", ""))


static func subtheme_label(id: String) -> String:
	return str(SUBTHEMES.get(id, id.capitalize()))


static func subtheme_labels(ids: Array[String]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id in ids:
		out.append(subtheme_label(id))
	return out


## The signs an archetype and its subthemes give, each the highest any of them says.
static func signs(id: String, subthemes: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	var entry: Dictionary = KINDS.get(id, {})
	var sources: Array[Dictionary] = [entry.get("signs", {})]
	for s in subthemes:
		sources.append(SUBTHEME_SIGNS.get(s, {}))
	for src in sources:
		for k in src.keys():
			out[k] = maxf(float(out.get(k, 0.0)), float(src[k]))
	return out
