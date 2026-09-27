class_name MatchQueue
extends RefCounted
## Find a duel on the duel server: the players waiting for an opponent, oldest first. Pairing is
## first come, first served, and runs on every join and re-queue rather than on a timer. Every call
## takes the clock as an argument, so the tests drive it without sockets or waiting.
##
## A `rated` queue (ranked) pairs on mu instead: a player accepts an opponent within a window that
## widens the longer it waits, and anyone at all after OPEN_AFTER_MS. Two players pair when either's
## window holds the gap. The same two identities are not paired twice in a row until both have
## waited REPEAT_AFTER_MS, and an identity never meets itself.

const WINDOW_BASE_MU: float = 3.0
const WINDOW_STEP_MU: float = 3.0
const WINDOW_STEP_MS: int = 30000
const OPEN_AFTER_MS: int = 90000
const REPEAT_AFTER_MS: int = 60000

## {"peer": int, "joined_msec": int, "mu": float, "identity": String}, sorted by `joined_msec`,
## oldest first.
var entries: Array[Dictionary] = []
var rated: bool = false
## Rated: identity id -> the identity it was last paired with.
var last_opponent: Dictionary = {}


func has(peer: int) -> bool:
	return _index_of(peer) >= 0


func size() -> int:
	return entries.size()


func clear() -> void:
	entries.clear()
	last_opponent.clear()


## Joins at the back. False when the peer is already waiting, which keeps its place.
func join(peer: int, now: int, mu: float = 0.0, identity: String = "") -> bool:
	if has(peer):
		return false
	entries.append({"peer": peer, "joined_msec": now, "mu": mu, "identity": identity})
	return true


## False when the peer was not waiting.
func leave(peer: int) -> bool:
	var i: int = _index_of(peer)
	if i < 0:
		return false
	entries.remove_at(i)
	return true


## Back in line with the time it first joined, so a player whose opponent left before the deal is
## ahead of everyone who joined after it, or in the same millisecond.
func requeue(peer: int, joined_msec: int, mu: float = 0.0, identity: String = "") -> void:
	leave(peer)
	var at: int = entries.size()
	for i in range(entries.size()):
		if int(entries[i]["joined_msec"]) >= joined_msec:
			at = i
			break
	entries.insert(at, {"peer": peer, "joined_msec": joined_msec, "mu": mu, "identity": identity})


## Takes pairs out while they can be made, at most `room_for` pairs (-1 for no limit), so a full
## server holds pairs back: the two oldest, or in a rated queue the oldest player with the oldest
## opponent it accepts. Each pair is two entries, each with `waited_ms` added.
func pair(now: int, room_for: int = -1) -> Array:
	var out: Array = []
	var i: int = 0
	while entries.size() >= 2 and i < entries.size() - 1 and (room_for < 0 or out.size() < room_for):
		var j: int = i + 1
		if rated:
			while j < entries.size() and not fits(entries[i], entries[j], now):
				j += 1
			if j >= entries.size():
				i += 1
				continue
		var two: Array[Dictionary] = [entries[i], entries[j]]
		entries.remove_at(j)
		entries.remove_at(i)
		for entry: Dictionary in two:
			entry["waited_ms"] = maxi(0, now - int(entry["joined_msec"]))
		if rated:
			last_opponent[str(two[0]["identity"])] = str(two[1]["identity"])
			last_opponent[str(two[1]["identity"])] = str(two[0]["identity"])
		out.append(two)
	return out


## Rated: whether two waiting entries may be paired now.
func fits(a: Dictionary, b: Dictionary, now: int) -> bool:
	var id_a: String = str(a["identity"])
	var id_b: String = str(b["identity"])
	if id_a == id_b:
		return false
	var waited_a: int = now - int(a["joined_msec"])
	var waited_b: int = now - int(b["joined_msec"])
	var repeat: bool = str(last_opponent.get(id_a, "")) == id_b or str(last_opponent.get(id_b, "")) == id_a
	if repeat and mini(waited_a, waited_b) < REPEAT_AFTER_MS:
		return false
	return absf(float(a["mu"]) - float(b["mu"])) <= maxf(window_mu(waited_a), window_mu(waited_b))


## How far from its own mu a player who has waited `waited_ms` accepts an opponent; INF once it
## takes anyone.
static func window_mu(waited_ms: int) -> float:
	if waited_ms >= OPEN_AFTER_MS:
		return INF
	return WINDOW_BASE_MU + WINDOW_STEP_MU * (maxi(0, waited_ms) / float(WINDOW_STEP_MS))


## Takes out every peer that has waited `max_wait_ms` or longer, and returns them.
func drop_stale(now: int, max_wait_ms: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(entries.size() - 1, -1, -1):
		if now - int(entries[i]["joined_msec"]) >= max_wait_ms:
			out.push_front(int(entries[i]["peer"]))
			entries.remove_at(i)
	return out


## How long the peer has waited, -1 when it is not waiting.
func waiting(peer: int, now: int) -> int:
	var i: int = _index_of(peer)
	return -1 if i < 0 else maxi(0, now - int(entries[i]["joined_msec"]))


func _index_of(peer: int) -> int:
	for i in range(entries.size()):
		if int(entries[i]["peer"]) == peer:
			return i
	return -1
