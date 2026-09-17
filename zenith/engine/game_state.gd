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
var last_attack: Dictionary = {}  # public outcome of the last attack this Combat, see DuelEngine._finish_attack
var battle_step: int = 0
var control_asked: bool = false   # the attacker already chose who is in control this attack phase
var discard_index: int = 0
var reserve_index: int = 0          # which player is swapping Reserve cards during setup
var floating: Array[Dictionary] = []   # {owner, op, duration, ...params}; see DuelEngine._float
var pending_play: Dictionary = {}      # a Combat card waiting on the opponent's counter window
var skip_discard: bool = false         # a card ended the turn early: no Discard step
var declare_window_done: bool = false  # the opponent already had their Declare-step response this turn
var winner: int = -1
var win_reason: String = ""


## A copy for a simulated engine. `cards` maps uid to that engine's own CardInstance.
func copy(cards: Dictionary) -> GameState:
	var s: GameState = GameState.new()
	s.seed_value = seed_value
	for p in players:
		s.players.append(p.copy(cards))
	s.active = active
	s.turn = turn
	s.step = step
	s.phase = phase
	s.attacker = attacker
	s.consecutive_passes = consecutive_passes
	s.combat_count = combat_count
	s.grounds = cards[grounds.uid] if grounds != null else null
	s.attack = attack.duplicate(true)
	s.last_attack = last_attack.duplicate(true)
	s.battle_step = battle_step
	s.control_asked = control_asked
	s.discard_index = discard_index
	s.reserve_index = reserve_index
	s.floating = floating.duplicate(true)
	s.pending_play = pending_play.duplicate(true)
	s.skip_discard = skip_discard
	s.declare_window_done = declare_window_done
	s.winner = winner
	s.win_reason = win_reason
	return s


func opponent_of(i: int) -> int:
	return 1 - i


func opposing() -> int:
	return 1 - active


func active_player() -> PlayerState:
	return players[active]


func opposing_player() -> PlayerState:
	return players[1 - active]


func is_over() -> bool:
	return winner >= 0
