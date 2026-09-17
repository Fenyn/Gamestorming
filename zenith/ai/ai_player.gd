class_name AiPlayer
extends RefCounted
## The Ai seat driver, peer of the local human and the remote joiner. It learns about the duel
## only through Referee.sim_for, which deals everything it may not see again at random, and it
## answers with the wire form of one of the prompt's own options.

var profile: AiProfile = AiProfile.default_profile()
var search: AiSearch = AiSearch.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_profile: AiProfile = null, seed_value: int = 1) -> void:
	if p_profile != null:
		profile = p_profile
	rng.seed = seed_value


## The command to submit for `seat`, or {} when the pending decision is not this seat's.
func choose(referee: Referee, seat: int) -> Dictionary:
	var pending: PromptView = referee.prompt_for(seat)
	if referee.is_over() or pending == null:
		return {}
	var cmd: Command = null
	# The Pages swap is judged by AiPages; a playout to the end of the turn says nothing about it.
	if profile.searches() and pending.kind != &"pages":
		cmd = search.choose(referee, seat, profile, rng)
	else:
		cmd = AiScorer.pick(referee.sim_for(seat, rng.randi()), profile, rng)
	return cmd.to_dict() if cmd != null else {}
