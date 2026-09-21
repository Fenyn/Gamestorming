class_name AiPlayer
extends RefCounted
## The Ai seat driver, peer of the local human and the remote joiner. It learns about the duel
## only through Referee.sim_for, which deals everything it may not see again at random, and it
## answers with the wire form of one of the prompt's own options.

var profile: AiProfile = AiProfile.default_profile()
var search: AiSearch = AiSearch.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## The profile actually played, once the deck across the table is known: `profile` with its `vs`
## pivots for that opponent laid on. Resolved on the first decision and kept, because a deck's
## declared archetype is fixed at setup. Both seats do this, so it holds for AI against AI.
var _matchup: AiProfile = null

## Matchup profiles keyed by which `when` facts hold, so a profile is built once per distinct board
## state rather than once per decision.
var _by_state: Dictionary = {}


func _init(p_profile: AiProfile = null, seed_value: int = 1) -> void:
	if p_profile != null:
		profile = p_profile
	rng.seed = seed_value


## The command to submit for `seat`, or {} when the pending decision is not this seat's.
func choose(referee: Referee, seat: int) -> Dictionary:
	if referee.is_over():
		return {}
	var pending_kind: StringName = referee.prompt_kind_for(seat)
	if pending_kind == &"":
		return {}
	var playing: AiProfile = _matchup_profile(referee, seat)
	var cmd: Command = null
	# The Reserve swap is judged by AiReserve; a playout to the end of the turn says nothing about it.
	if playing.searches() and pending_kind != &"reserve" and not playing.scorer_decides(pending_kind):
		cmd = search.choose(referee, seat, playing, rng, _matchup)
	else:
		search.metrics = {}
		search.last_report.clear()
		cmd = AiScorer.pick(referee.sim_for(seat, rng.randi()), playing, rng, seat)
	return cmd.to_dict() if cmd != null else {}


## The profile to play with now: the base, pivoted on who is across the table (fixed at setup, so
## resolved once), then pivoted on where the duel stands (recomputed, cached per distinct state).
func _matchup_profile(referee: Referee, seat: int) -> AiProfile:
	if _matchup != null:
		var pivots: Dictionary = _matchup.data.get("when", {})
		if pivots.is_empty():
			return _matchup
	# Profile pivots read public standings, never client attack previews.
	var view: SeatView = referee.view_for(seat, false)
	if view == null or view.players.size() < 2:
		return profile
	if _matchup == null:
		var rival: SeatPlayer = view.player(1 - seat)
		_matchup = profile.for_matchup(rival.archetype, rival.subthemes)
	var key: String = _matchup.state_key(view, seat)
	if key == "":
		return _matchup
	if not _by_state.has(key):
		_by_state[key] = _matchup.for_state(key)
	return _by_state[key]
