class_name ZenithRng
extends RefCounted
## Seeded random source for the engine. Every random decision goes through here
## so a seed plus a command list replays the same game.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_rng.seed = seed_value


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func shuffle(arr: Array) -> void:
	# Fisher-Yates on the seeded generator; Array.shuffle() would use the global RNG.
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
