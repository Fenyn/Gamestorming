extends Node

# Drop .ogg or .wav files into res://audio/sfx/ matching these keys.
# Any missing file is silently skipped — no crashes.

const SFX_PATHS := {
	# Grinder
	"grind_loop": "res://audio/sfx/grind_loop.ogg",
	"grind_complete": "res://audio/sfx/grind_complete.ogg",

	# Aeropress
	"water_pour_loop": "res://audio/sfx/water_pour_loop.ogg",
	"stir_loop": "res://audio/sfx/stir_loop.ogg",
	"steep_tick": "res://audio/sfx/steep_tick.ogg",
	"shot_ready": "res://audio/sfx/shot_ready.ogg",
	"over_extract_warn": "res://audio/sfx/over_extract_warn.ogg",
	"press_loop": "res://audio/sfx/press_loop.ogg",
	"shot_complete": "res://audio/sfx/shot_complete.ogg",
	"shot_dead": "res://audio/sfx/shot_dead.ogg",

	# Pour over
	"pour_loop": "res://audio/sfx/pour_loop.ogg",
	"drip_loop": "res://audio/sfx/drip_loop.ogg",
	"drip_done": "res://audio/sfx/drip_done.ogg",
	"coffee_cooling": "res://audio/sfx/coffee_cooling.ogg",

	# Steam wand
	"steam_hiss_good": "res://audio/sfx/steam_hiss_good.ogg",
	"steam_screech": "res://audio/sfx/steam_screech.ogg",
	"steam_texture_loop": "res://audio/sfx/steam_texture_loop.ogg",
	"milk_ready": "res://audio/sfx/milk_ready.ogg",
	"milk_scald": "res://audio/sfx/milk_scald.ogg",

	# Hot water
	"kettle_fill_loop": "res://audio/sfx/kettle_fill_loop.ogg",
	"kettle_full": "res://audio/sfx/kettle_full.ogg",

	# Syrup
	"syrup_pump": "res://audio/sfx/syrup_pump.ogg",

	# Sauce
	"sauce_drizzle_loop": "res://audio/sfx/sauce_drizzle_loop.ogg",
	"sauce_prep_loop": "res://audio/sfx/sauce_prep_loop.ogg",
	"sauce_batch_done": "res://audio/sfx/sauce_batch_done.ogg",

	# Lid
	"lid_snap": "res://audio/sfx/lid_snap.ogg",

	# Register / Cash
	"register_beep": "res://audio/sfx/register_beep.ogg",
	"register_charge": "res://audio/sfx/register_charge.ogg",
	"cash_collect": "res://audio/sfx/cash_collect.ogg",
	"coin_clink": "res://audio/sfx/coin_clink.ogg",
	"change_complete": "res://audio/sfx/change_complete.ogg",

	# Hand-off / Review
	"review_good": "res://audio/sfx/review_good.ogg",
	"review_bad": "res://audio/sfx/review_bad.ogg",
	"tip_earned": "res://audio/sfx/tip_earned.ogg",

	# Customer
	"customer_arrive": "res://audio/sfx/customer_arrive.ogg",
	"customer_impatient": "res://audio/sfx/customer_impatient.ogg",
	"customer_happy": "res://audio/sfx/customer_happy.ogg",
	"customer_angry": "res://audio/sfx/customer_angry.ogg",

	# Day / UI
	"day_start": "res://audio/sfx/day_start.ogg",
	"day_end": "res://audio/sfx/day_end.ogg",
	"timer_warning": "res://audio/sfx/timer_warning.ogg",

	# Items
	"item_pickup": "res://audio/sfx/item_pickup.ogg",
	"item_place": "res://audio/sfx/item_place.ogg",
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

func is_loop_playing(sound_name: String) -> bool:
	return sound_name in _loops

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
