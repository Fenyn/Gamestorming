class_name AdventureRules
extends RefCounted
## The adventure-only rules a duel runs under, kept away from the screens so a headless runner can
## read them. `Session` is an autoload and a SceneTree script cannot see it, which is why the lives
## numbers live here and not in session.gd.

## Adventure lives (2026-09-22): points the rival must score to beat that seat.
const PLAYER_LIVES: int = 2
const OPPONENT_LIVES: int = 1
const BOSS_LIVES: int = 2


## Lives for one duel, player first. The player always has two; an opponent has one unless it is an
## act boss, who also has two. `row` is an `AdventureMap.duel_for` row; an empty row is read as an
## ordinary duel.
static func lives_for(row: Dictionary) -> Array[int]:
	var boss: bool = str(row.get("node", "")) == "boss" or str(row.get("tier", "")) == "boss"
	return [PLAYER_LIVES, BOSS_LIVES if boss else OPPONENT_LIVES]


## A boss's special power for one fight: a card on the banned list, picked at random from the run
## seed and the node, so a reload faces the same power and another boss or run likely a different
## one (user, 2026-09-24). "" for a fight that is not a boss.
static func boss_power_for(row: Dictionary, run_seed: int, node_id: String, library: CardLibrary) -> String:
	var boss: bool = str(row.get("node", "")) == "boss" or str(row.get("tier", "")) == "boss"
	if not boss:
		return ""
	var banned: Array[String] = []
	for id in library.all_ids():
		if bool((library.defs[id] as CardDef).raw.get("banned", false)):
			banned.append(id)
	if banned.is_empty():
		return ""
	banned.sort()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([run_seed, node_id, "boss_power"])
	return banned[rng.randi_range(0, banned.size() - 1)]
