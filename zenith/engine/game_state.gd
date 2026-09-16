class_name GameState
extends RefCounted
## Plain data for one duel. DuelEngine mutates it; nothing else should.

enum Step { SETUP, DRAW, NON_COMBAT, POWER_UP, DECLARE, COMBAT, DISCARD, RECOVER, GAME_OVER }
enum Phase { NONE, PREPARE_ACTIVE, PREPARE_OPPOSING, OPPOSING_DRAW, ATTACK, DEFEND, BATTLE, FIGHT_BACK }

var seed_value: int = 0
var players: Array[PlayerState] = []
var active: int = 0
var turn: int = 0
var step: Step = Step.SETUP
var phase: Phase = Phase.NONE
var attacker: int = 0
var consecutive_passes: int = 0
var combat_count: int = 0
var grounds: CardInstance = null
var attack: Dictionary = {}       # current attack context, see DuelEngine._begin_attack
var battle_step: int = 0
var discard_index: int = 0
var armory_index: int = 0          # which player is swapping Armory cards during setup
var floating: Array[Dictionary] = []   # {owner, op, duration, ...params}; see DuelEngine._float
var pending_play: Dictionary = {}      # a Combat card waiting on the opponent's counter window
var skip_discard: bool = false         # a card ended the turn early: no Discard step
var declare_window_done: bool = false  # the opponent already had their Declare-step response this turn
var winner: int = -1
var win_reason: String = ""


func opponent_of(i: int) -> int:
	return 1 - i


func opposing() -> int:
	return 1 - active


func active_player() -> PlayerState:
	return players[active]


func opposing_player() -> PlayerState:
	return players[1 - active]


func highest_tier_in_play() -> int:
	var best: int = 0
	for p in players:
		best = maxi(best, p.highest_tier)
	return best


func is_over() -> bool:
	return winner >= 0
