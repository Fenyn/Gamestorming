class_name DuelRoom
extends RefCounted
## One pairing on the duel server: the share code, the peer behind each seat, the lobby picks,
## and the DuelHost once the duel has started. Rooms live in `Net.rooms` on the server.

const CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # no 0/O, 1/I
const CODE_LENGTH: int = 5

var code: String = ""
var seat_peer: Array[int] = [0, 0]
var lobby: Array[Dictionary] = []
var host: DuelHost = null
var seed_value: int = 0
var color_seed: int = 0   # cosmetic only: the seat colours both clients draw
var started: bool = false


static func new_code(rng: RandomNumberGenerator) -> String:
	var out: String = ""
	for i in range(CODE_LENGTH):
		out += CODE_ALPHABET[rng.randi_range(0, CODE_ALPHABET.length() - 1)]
	return out


func _init() -> void:
	lobby = [
		{"name": "Player 1", "deck": -1, "deck_name": "", "ready": false},
		{"name": "Player 2", "deck": -1, "deck_name": "", "ready": false},
	]


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
	return filled() and int(lobby[0]["deck"]) >= 0 and int(lobby[1]["deck"]) >= 0 \
		and bool(lobby[0]["ready"]) and bool(lobby[1]["ready"])


func other_peer(seat: int) -> int:
	return seat_peer[1 - seat]
