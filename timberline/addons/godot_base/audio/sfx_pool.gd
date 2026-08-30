class_name SfxPool
extends Node

@export var pool_size: int = 8
@export var bus_name: StringName = &"Master"

var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _loops: Dictionary = {}
var _cache: Dictionary = {}


func _ready() -> void:
	for i: int in range(pool_size):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = bus_name
		add_child(p)
		_pool.append(p)


func play(stream_or_path: Variant, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _resolve_stream(stream_or_path)
	if not stream:
		return
	var player: AudioStreamPlayer = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % pool_size
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func play_loop(id: String, stream_or_path: Variant, volume_db: float = 0.0) -> void:
	if id in _loops:
		return
	var stream: AudioStream = _resolve_stream(stream_or_path)
	if not stream:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus_name
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()
	_loops[id] = player


func stop_loop(id: String) -> void:
	if id not in _loops:
		return
	var player: AudioStreamPlayer = _loops[id]
	player.stop()
	player.queue_free()
	_loops.erase(id)


func stop_all_loops() -> void:
	for key: String in _loops.keys():
		stop_loop(key)


func is_loop_playing(id: String) -> bool:
	return id in _loops


func _resolve_stream(stream_or_path: Variant) -> AudioStream:
	if stream_or_path is AudioStream:
		return stream_or_path as AudioStream
	var path: String = str(stream_or_path)
	if path in _cache:
		return _cache[path] as AudioStream
	if not ResourceLoader.exists(path):
		push_warning("SfxPool: Resource not found at '%s'" % path)
		return null
	var stream: AudioStream = load(path) as AudioStream
	_cache[path] = stream
	return stream
