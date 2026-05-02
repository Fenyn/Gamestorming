extends Node

const SFX_PATHS := {
	"item_pickup": "res://audio/sfx/item_pickup.ogg",
	"item_place": "res://audio/sfx/item_place.ogg",
	"plant_seed": "res://audio/sfx/plant_seed.ogg",
	"water_pour": "res://audio/sfx/water_pour.ogg",
	"pollinate": "res://audio/sfx/pollinate.ogg",
	"harvest": "res://audio/sfx/harvest.ogg",
	"deliver": "res://audio/sfx/deliver.ogg",
	"bloom": "res://audio/sfx/bloom.ogg",
	"bee_buzz": "res://audio/sfx/bee_buzz.ogg",
	"bee_assign": "res://audio/sfx/bee_assign.ogg",
	"milestone": "res://audio/sfx/milestone.ogg",
	"o2_warning": "res://audio/sfx/o2_warning.ogg",
	"o2_refill": "res://audio/sfx/o2_refill.ogg",
	"death": "res://audio/sfx/death.ogg",
	"build_place": "res://audio/sfx/build_place.ogg",
	"build_complete": "res://audio/sfx/build_complete.ogg",
	"power_on": "res://audio/sfx/power_on.ogg",
	"brownout": "res://audio/sfx/brownout.ogg",
	"win": "res://audio/sfx/win.ogg",
	"ambient_hum": "res://audio/sfx/ambient_hum.ogg",
}

const POOL_SIZE := 8

var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _loops: Dictionary = {}
var _cache: Dictionary = {}


func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func play(sound_name: String, volume_db: float = 0.0) -> void:
	var stream := _get_stream(sound_name)
	if not stream:
		return
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func play_loop(sound_name: String, volume_db: float = 0.0) -> void:
	if sound_name in _loops:
		return
	var stream := _get_stream(sound_name)
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()
	_loops[sound_name] = player


func stop_loop(sound_name: String) -> void:
	if sound_name not in _loops:
		return
	var player: AudioStreamPlayer = _loops[sound_name]
	player.stop()
	player.queue_free()
	_loops.erase(sound_name)


func stop_all_loops() -> void:
	for key in _loops.keys():
		stop_loop(key)


func _get_stream(sound_name: String) -> AudioStream:
	if sound_name in _cache:
		return _cache[sound_name]
	if sound_name not in SFX_PATHS:
		return null
	var path: String = SFX_PATHS[sound_name]
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	_cache[sound_name] = stream
	return stream
