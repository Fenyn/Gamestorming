class_name TutorialPacing
extends RefCounted
## How long the tutorial's words stay up, and the clock of one blocking stop: its lines shown one
## after another, each for its own time, the text of each revealed first. A click (or Space, or
## Enter) shows the rest of a line at once, or moves to the next line when it is all shown. A
## stop that `hold`s waits on its last line for that click; any other stop ends on its own.
## RefCounted and engine-free, so the tests run it without a table.

const READ_BASE: float = 0.8
const READ_PER_WORD: float = 0.3
const READ_MIN: float = 2.0
const READ_MAX: float = 7.0
const BARK_BASE: float = 0.9
const BARK_PER_CHAR: float = 0.045
const BARK_MIN: float = 1.4
const BARK_MAX: float = 3.2
const REVEAL_RATE: float = 90.0   # characters a second
const REVEAL_MAX: float = 0.45
## A gated step with no input for this long nudges its target.
const IDLE_NUDGE: float = 6.0

## Seconds per line, and the reveal time of each.
var times: Array[float] = []
var reveals: Array[float] = []
var hold: bool = false
## The line shown now; `times.size()` once the stop is over.
var line: int = 0
var elapsed: float = 0.0


func _init(line_times: Array[float] = [], line_reveals: Array[float] = [], holds: bool = false) -> void:
	times = line_times
	reveals = line_reveals
	hold = holds
	while reveals.size() < times.size():
		reveals.append(0.0)


## A line someone reads in the coach box or the caption: 0.8 s plus 0.3 s a word, 2 to 7 s.
static func read_time(text: String) -> float:
	return clampf(READ_BASE + READ_PER_WORD * float(words(text)), READ_MIN, READ_MAX)


## A shouted line in a bubble: 0.9 s plus 0.045 s a character, 1.4 to 3.2 s.
static func bark_time(text: String) -> float:
	return clampf(BARK_BASE + BARK_PER_CHAR * float(text.length()), BARK_MIN, BARK_MAX)


## A line's time by where it shows (`TutorialDirector.speaker`'s `at`): shouted at a duelist
## card, or read in the coach box or the caption.
static func line_time(at: String, text: String) -> float:
	return bark_time(text) if at == "you" or at == "rival" else read_time(text)


## Typing the line out at 90 characters a second, never longer than 0.45 s.
static func reveal_time(text: String) -> float:
	return minf(float(text.length()) / REVEAL_RATE, REVEAL_MAX)


static func words(text: String) -> int:
	return text.split(" ", false).size()


## True when a word of the line is shouted in capitals ("STRAW", "HAAAH"), which shakes its bubble.
static func shouted(text: String) -> bool:
	for word in text.split(" ", false):
		var letters: String = ""
		for ch in word:
			if ch.to_upper() != ch.to_lower():
				letters += ch
		if letters.length() >= 2 and letters == letters.to_upper():
			return true
	return false


func finished() -> bool:
	return line >= times.size()


## True on the last line of a holding stop once its time is up: only a click ends it now.
func waits_for_click() -> bool:
	return hold and line == times.size() - 1 and elapsed >= times[line]


## Moves the clock on unless `paused`. True when the line shown changed.
func tick(delta: float, paused: bool) -> bool:
	if finished() or paused:
		return false
	elapsed += delta
	if elapsed < times[line]:
		return false
	if hold and line == times.size() - 1:
		elapsed = times[line]
		return false
	line += 1
	elapsed = 0.0
	return true


## The click: the rest of the line if it is still typing, else the next line. True when the line
## shown changed.
func skip() -> bool:
	if finished():
		return false
	if elapsed < reveals[line]:
		elapsed = reveals[line]
		return false
	line += 1
	elapsed = 0.0
	return true


## How much of the line shown is typed out, 0 to 1.
func revealed() -> float:
	if finished():
		return 1.0
	return 1.0 if reveals[line] <= 0.0 else clampf(elapsed / reveals[line], 0.0, 1.0)


## What is left of the line's time, 1 down to 0, for the timer bar. A held last line shows none.
func left() -> float:
	if finished() or (hold and line == times.size() - 1):
		return 0.0
	return clampf(1.0 - elapsed / maxf(0.001, times[line]), 0.0, 1.0)
