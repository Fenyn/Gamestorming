class_name GhostRecorder
extends Node

var _snapshots: Array[Dictionary] = []
var _recording: bool = false
var _elapsed: float = 0.0
var _ship: RigidBody3D


func start(ship: RigidBody3D) -> void:
	_ship = ship
	_snapshots.clear()
	_elapsed = 0.0
	_recording = true


func stop() -> void:
	_recording = false


func _physics_process(delta: float) -> void:
	if not _recording or _ship == null:
		return

	_elapsed += delta
	_snapshots.append({
		"t": _elapsed,
		"p": _ship.global_position,
		"b": _ship.global_basis,
	})


func get_snapshots() -> Array[Dictionary]:
	return _snapshots


func save_ghost(track_name: String) -> void:
	var dir_path: String = "user://ghosts"
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file_path: String = "%s/%s.dat" % [dir_path, track_name]
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return

	file.store_32(_snapshots.size())
	for snap: Dictionary in _snapshots:
		file.store_float(snap["t"])
		var pos: Vector3 = snap["p"]
		file.store_float(pos.x)
		file.store_float(pos.y)
		file.store_float(pos.z)
		var b: Basis = snap["b"]
		for row: int in range(3):
			var v: Vector3 = b[row]
			file.store_float(v.x)
			file.store_float(v.y)
			file.store_float(v.z)

	file.close()


static func load_ghost(track_name: String) -> Array[Dictionary]:
	var file_path: String = "user://ghosts/%s.dat" % track_name
	if not FileAccess.file_exists(file_path):
		return []

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return []

	var count: int = file.get_32()
	var snapshots: Array[Dictionary] = []
	snapshots.resize(count)

	for i: int in range(count):
		var t: float = file.get_float()
		var px: float = file.get_float()
		var py: float = file.get_float()
		var pz: float = file.get_float()

		var rows: Array[Vector3] = []
		for _r: int in range(3):
			var vx: float = file.get_float()
			var vy: float = file.get_float()
			var vz: float = file.get_float()
			rows.append(Vector3(vx, vy, vz))

		snapshots[i] = {
			"t": t,
			"p": Vector3(px, py, pz),
			"b": Basis(rows[0], rows[1], rows[2]),
		}

	file.close()
	return snapshots
