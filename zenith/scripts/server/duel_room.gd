class_name DuelRoom
extends RefCounted
## One pairing on the duel server: the share code, the peer behind each seat, the lobby picks,
## where the room is in its life, and the seed once dealt. Rooms live in `Net.rooms` on the server;
## the DuelHost of a dealt room lives in the server scene.

const CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # no 0/O, 1/I
const CODE_LENGTH: int = 5

## LOBBY: the seats pick. DUEL: dealt and running. OVER: finished; the room waits for a rematch,
## a return to the lobby, or both players to leave. BETWEEN: ranked, a game is over and the match
## is not; the next game is dealt at `next_deal_msec`, or once both seats are ready.
enum Phase { LOBBY, DUEL, OVER, BETWEEN }

var code: String = ""
## "code": opened by a player and joined with its share code. "queue": paired by Find a duel; its
## code is only an id, never shown, and nobody joins it by code.
var kind: String = "code"
## A queue room from the ranked queue: a best-of-3 match on the two locked decks, rated once when
## it is decided. Never a share-code room.
var ranked: bool = false
var best_of: int = 1
## Ranked: the game being played or just finished, from 1; 0 before the first deal.
var game: int = 0
var wins: Array[int] = [0, 0]
## Ranked: 16 hex characters from `Crypto` at the first deal, in every game's record.
var match_id: String = ""
## Ranked: the seat that lost the last game, which opens the next one; -1 before any result.
var last_loser: int = -1
## Ranked: set at the first deal. The picks stand for the whole match.
var series_locked: bool = false
## Ranked, in BETWEEN: per seat, its player asked for the next game.
var next_ready: Array[bool] = [false, false]
var next_deal_msec: int = 0
## Ranked: the game whose result is counted into `wins`, so no path counts one twice.
var settled_game: int = 0
## Ranked: the seat whose player conceded the match (Leave match, or a give-up while cut off), -1
## while nobody has.
var leaving: int = -1
## Ranked, once the match is decided: {"winner": seat or -1, "wins": [int, int], "reason"}, the
## reason one of `MatchRecord.MATCH_REASONS` ("concede_match" when `leaving` decided it).
var match_result: Dictionary = {}
## Ranked, once rated: per seat {"before": {"mu", "sigma"}, "after": {"mu", "sigma"}}; [] unrated.
var rating_change: Array = []
var seat_peer: Array[int] = [0, 0]
## Queue room, per seat: ticks msec the player joined the queue, kept for a re-queue at the front.
var joined_msec: Array[int] = [0, 0]
## Per seat: the identity id the player proved in its greeting (`Identity`), "" for an empty seat.
## It stays with an away seat, and only that identity can rejoin or give it up.
var seat_identity: Array[String] = ["", ""]
## Queue room in LOBBY: ticks msec by which both seats must lock in, 0 once both have.
var pick_deadline_msec: int = 0
## Queue room in LOBBY: ticks msec at which the server deals, set when both lock in, 0 otherwise.
var deal_at_msec: int = 0
var lobby: Array[Dictionary] = []
var host: DuelHost = null
var seed_value: int = 0
var color_seed: int = 0   # cosmetic only: the seat colours both clients draw
var phase: Phase = Phase.LOBBY
## Per seat, in LOBBY: this client has shown the matchup and the server may deal.
var deal_ready: Array[bool] = [false, false]
## Per seat, in OVER: this player asked for a rematch.
var rematch: Array[bool] = [false, false]
## Ticks msec since which the room has held a single player, 0 while it holds two.
var alone_since: int = 0
## Per seat in DUEL: the secret a dropped player rejoins with, 64 hex characters, new at each deal
## and "" outside a duel. It goes to that seat's client with each deal, and nowhere else. A ranked
## match keeps one per seat from its first deal to its end.
var tokens: Array[String] = ["", ""]
## Per seat in DUEL, and in BETWEEN: ticks msec since the seat's connection dropped, 0 while it is
## connected.
var away_since: Array[int] = [0, 0]
## Ticks msec since both seats have been away, 0 otherwise. Both clocks stand still meanwhile.
var both_away_since: int = 0


## A share code from `bytes`, one byte per character. 256 is a multiple of the alphabet's 32, so
## every character is equally likely.
static func new_code(bytes: PackedByteArray) -> String:
	var out: String = ""
	for i in range(CODE_LENGTH):
		out += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length()]
	return out


static func valid_code(text: String) -> bool:
	if text.length() != CODE_LENGTH:
		return false
	for ch in text:
		if not CODE_ALPHABET.contains(ch):
			return false
	return true


## The lobby entry of a seat nobody has picked for.
static func empty_pick(seat: int) -> Dictionary:
	return {"name": "Player %d" % (seat + 1), "deck": -1, "deck_name": "", "ready": false}


func _init() -> void:
	lobby = [empty_pick(0), empty_pick(1)]


func free_seat() -> int:
	for seat in range(2):
		if seat_peer[seat] == 0:
			return seat
	return -1


func seat_of(id: int) -> int:
	for seat in range(2):
		if id != 0 and seat_peer[seat] == id:
			return seat
	return -1


func filled() -> bool:
	return seat_peer[0] != 0 and seat_peer[1] != 0


func both_locked() -> bool:
	return filled() and seat_locked(0) and seat_locked(1)


func seat_locked(seat: int) -> bool:
	return int(lobby[seat]["deck"]) >= 0 and bool(lobby[seat]["ready"])


## The name the other player, the rules and the record get for a seat: what its player typed in a
## share-code room, the stock name in a queue room, where strangers never see each other's typing.
func shown_name(seat: int) -> String:
	return str(empty_pick(seat)["name"]) if kind == "queue" else str(lobby[seat]["name"])


func other_peer(seat: int) -> int:
	return seat_peer[1 - seat]


## The seat `token` belongs to in the running duel, or -1. Compared in constant time.
func seat_of_token(token: String) -> int:
	var crypto: Crypto = Crypto.new()
	for seat in range(2):
		if tokens[seat] != "" and token.length() == tokens[seat].length() \
				and crypto.constant_time_compare(token.to_utf8_buffer(), tokens[seat].to_utf8_buffer()):
			return seat
	return -1
