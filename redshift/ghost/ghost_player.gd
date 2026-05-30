class_name GhostPlayer
extends Node3D

var _snapshots: Array[Dictionary] = []
var _playing: bool = false
var _elapsed: float = 0.0
var _search_index: int = 0

@onready var _mesh: MeshInstance3D = %GhostMesh


func load_ghost(track_name: String) -> bool:
	_snapshots = GhostRecorder.load_ghost(track_name)
	return not _snapshots.is_empty()


func set_snapshots(snapshots: Array[Dictionary]) -> void:
	_snapshots = snapshots


func start() -> void:
	if _snapshots.is_empty():
		visible = false
		return
	_playing = true
	_elapsed = 0.0
	_search_index = 0
	visible = true


func stop() -> void:
	_playing = false
	visible = false


func reset() -> void:
	_elapsed = 0.0
	_search_index = 0
	_playing = false
	visible = false


func _physics_process(delta: float) -> void:
	if not _playing or _snapshots.is_empty():
		return

	_elapsed += delta

	var last_time: float = _snapshots[_snapshots.size() - 1]["t"]
	if _elapsed > last_time:
		stop()
		return

	while _search_index < _snapshots.size() - 2:
		if _snapshots[_search_index + 1]["t"] >= _elapsed:
			break
		_search_index += 1

	var a: Dictionary = _snapshots[_search_index]
	var b: Dictionary = _snapshots[mini(_search_index + 1, _snapshots.size() - 1)]
	var span: float = b["t"] - a["t"]
	var t: float = 0.0
	if span > 0.0001:
		t = clampf((_elapsed - a["t"]) / span, 0.0, 1.0)

	global_position = (a["p"] as Vector3).lerp(b["p"] as Vector3, t)
	global_basis = (a["b"] as Basis).slerp(b["b"] as Basis, t)
