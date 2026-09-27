class_name DuelClock
extends RefCounted
## Decision timers for a server room: per seat, a timer on the decision it owes and a time bank
## behind it. Nothing is ever played for a seat. A decision waits until its timer and then the
## bank are gone, and the seat has then lost. Every call takes the time, so tests drive it without
## a scene; the owner passes `Time.get_ticks_msec()`.

const DECIDE_MS: int = 30000
## A prompt that shows a pile or takes several cards (`context.library`, `batch_max` above 1,
## `name_card`).
const LONG_MS: int = 45000
const RESERVE_MS: int = 60000
const WARN_MS: int = 10000
const BANK_START_MS: int = 60000
const BANK_TURN_MS: int = 10000
const BANK_MAX_MS: int = 120000
## An armed decision starts this long after it was owed if its panel is never reported open.
const SHOW_GRACE_MS: int = 10000

## `state().phase`: no timer counting, the decision timer, its last WARN_MS, the bank.
const OFF: String = "off"
const RUN: String = "run"
const WARN: String = "warn"
const BANK: String = "bank"
const PHASES: Array[String] = [OFF, RUN, WARN, BANK]

var _bank: Array[int] = [BANK_START_MS, BANK_START_MS]
## Per seat while running: when the decision timer runs out. `_bank` is then the bank as it will
## stand at that moment, and it drains from there.
var _deadline: Array[int] = [0, 0]
var _running: Array[bool] = [false, false]
var _armed: Array[bool] = [false, false]
var _armed_until: Array[int] = [0, 0]
var _armed_ms: Array[int] = [0, 0]


## The decision timer a prompt gets.
static func decision_ms(kind: StringName, context: Dictionary) -> int:
	if kind == &"reserve":
		return RESERVE_MS
	if kind == &"name_card" or context.has("library") or int(context.get("batch_max", 0)) > 1:
		return LONG_MS
	return DECIDE_MS


## The seat owes a decision. Its timer starts at `shown`, or SHOW_GRACE_MS from now.
func arm(seat: int, kind: StringName, context: Dictionary, now_msec: int) -> void:
	if not _seat(seat):
		return
	stop(seat, now_msec)
	_armed[seat] = true
	_armed_until[seat] = now_msec + SHOW_GRACE_MS
	_armed_ms[seat] = decision_ms(kind, context)


## The seat owes a decision and its timer starts now.
func start(seat: int, kind: StringName, context: Dictionary, now_msec: int) -> void:
	if not _seat(seat):
		return
	stop(seat, now_msec)
	_begin(seat, decision_ms(kind, context), now_msec)


## The seat's decision panel is up: an armed timer starts now.
func shown(seat: int, now_msec: int) -> void:
	if _seat(seat) and _armed[seat]:
		_begin(seat, _armed_ms[seat], mini(now_msec, _armed_until[seat]))


## The seat answered, or owes nothing. Time taken past the decision timer comes off the bank.
func stop(seat: int, now_msec: int) -> void:
	if not _seat(seat):
		return
	if _running[seat]:
		_bank[seat] = bank_left(seat, now_msec)
	_running[seat] = false
	_armed[seat] = false


## The seat's own turn starts: BANK_TURN_MS more on the bank, up to BANK_MAX_MS.
func bank_turn(seat: int, now_msec: int) -> void:
	if not _seat(seat):
		return
	var left: int = bank_left(seat, now_msec)
	_bank[seat] += mini(BANK_MAX_MS, left + BANK_TURN_MS) - left


## Starts armed timers whose grace is over and returns the seats whose timer and bank are both
## gone, the earliest first.
func tick(now_msec: int) -> Array[int]:
	for seat in range(2):
		if _armed[seat] and now_msec >= _armed_until[seat]:
			_begin(seat, _armed_ms[seat], _armed_until[seat])
	var gone: Array[int] = []
	for seat in range(2):
		if _running[seat] and now_msec >= out_at(seat):
			gone.append(seat)
	gone.sort_custom(func(a: int, b: int) -> bool: return out_at(a) < out_at(b))
	return gone


## When the seat's timer and bank are both gone, -1 while nothing counts for it.
func out_at(seat: int) -> int:
	return _deadline[seat] + _bank[seat] if _seat(seat) and _running[seat] else -1


func bank_left(seat: int, now_msec: int) -> int:
	if not _seat(seat):
		return 0
	if not _running[seat]:
		return _bank[seat]
	return maxi(0, _bank[seat] - maxi(0, now_msec - _deadline[seat]))


## `{left_ms, bank_ms, phase}`: what is left on the decision timer and on the bank.
func state(seat: int, now_msec: int) -> Dictionary:
	var bank: int = bank_left(seat, now_msec)
	if not _seat(seat) or not _running[seat]:
		return {"left_ms": 0, "bank_ms": bank, "phase": OFF}
	var left: int = maxi(0, _deadline[seat] - now_msec)
	var phase: String = RUN if left > WARN_MS else (WARN if left > 0 else BANK)
	return {"left_ms": left, "bank_ms": bank, "phase": phase}


func _begin(seat: int, length_ms: int, at_msec: int) -> void:
	_armed[seat] = false
	_running[seat] = true
	_deadline[seat] = at_msec + length_ms


static func _seat(seat: int) -> bool:
	return seat == 0 or seat == 1
