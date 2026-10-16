class_name AmbientLife
extends Node3D

## Background life around the stand: pedestrians on the sidewalks and cars on the
## road. Purely visual. Nothing here takes part in orders or blocks anyone.

const CAR_SCENES := [
	preload("res://assets/models/kenney/sedan.glb"),
	preload("res://assets/models/kenney/taxi.glb"),
	preload("res://assets/models/kenney/van.glb"),
	preload("res://assets/models/kenney/delivery.glb"),
]

# Sidewalk lanes: z position and walking direction along x.
const WALK_LANES := [
	# Far sidewalk: the planters sit at z 15.3, so walkers pass in front of and behind them.
	{"z": 14.6, "dir": 1.0, "weight": 1.0},
	{"z": 16.4, "dir": -1.0, "weight": 1.0},
	# Near sidewalk, between the seating/stalls (z < 3.9) and the customer
	# entry point at z 5.5.
	{"z": 4.4, "dir": 1.0, "weight": 0.35},
	{"z": 4.4, "dir": -1.0, "weight": 0.35},
]
# Road lanes: the near lane is kept clear of parked cars.
const DRIVE_LANES := [
	{"z": 10.6, "dir": 1.0},
	{"z": 12.8, "dir": -1.0},
]
const WALK_EXTENT := 24.0
const DRIVE_EXTENT := 34.0
const PEDESTRIAN_INTERVAL := Vector2(2.5, 6.0)
const CAR_INTERVAL := Vector2(4.0, 11.0)
const MAX_PEDESTRIANS := 8

var _pedestrian_timer := 1.0
var _car_timers: Array[float] = []
var _pedestrians: Array[Node3D] = []

func _ready() -> void:
	for i in range(DRIVE_LANES.size()):
		_car_timers.append(randf_range(0.5, 4.0))
	# Start with a few people already on the sidewalks so it doesn't look empty.
	for i in range(4):
		_spawn_pedestrian(randf_range(-WALK_EXTENT * 0.8, WALK_EXTENT * 0.8))

func _process(delta: float) -> void:
	for i in range(_pedestrians.size() - 1, -1, -1):
		if not is_instance_valid(_pedestrians[i]):
			_pedestrians.remove_at(i)
	_pedestrian_timer -= delta
	if _pedestrian_timer <= 0.0:
		_pedestrian_timer = randf_range(PEDESTRIAN_INTERVAL.x, PEDESTRIAN_INTERVAL.y)
		if _pedestrians.size() < MAX_PEDESTRIANS:
			_spawn_pedestrian()
	for i in range(_car_timers.size()):
		_car_timers[i] -= delta
		if _car_timers[i] <= 0.0:
			_car_timers[i] = randf_range(CAR_INTERVAL.x, CAR_INTERVAL.y)
			_spawn_car(DRIVE_LANES[i])

func _pick_walk_lane() -> Dictionary:
	var total := 0.0
	for lane in WALK_LANES:
		total += float(lane["weight"])
	var roll := randf() * total
	for lane in WALK_LANES:
		roll -= float(lane["weight"])
		if roll <= 0.0:
			return lane
	return WALK_LANES[0]

## start_x: place mid-walk instead of at the edge (used to pre-populate).
func _spawn_pedestrian(start_x: float = INF) -> void:
	var lane := _pick_walk_lane()
	var dir: float = lane["dir"]
	var walker := Pedestrian.new()
	walker.profile = CustomerProfile.generate()
	walker.direction = dir
	walker.end_x = WALK_EXTENT * dir
	add_child(walker)
	var x := -WALK_EXTENT * dir if start_x == INF else start_x
	walker.global_position = Vector3(x, 0, float(lane["z"]) + randf_range(-0.1, 0.1))
	_pedestrians.append(walker)

func _spawn_car(lane: Dictionary) -> void:
	var dir: float = lane["dir"]
	var scene: PackedScene = CAR_SCENES[randi() % CAR_SCENES.size()]
	var car := MovingCar.new()
	car.direction = dir
	car.speed = randf_range(6.0, 10.0)
	car.end_x = DRIVE_EXTENT * dir
	car.add_child(scene.instantiate())
	add_child(car)
	car.global_position = Vector3(-DRIVE_EXTENT * dir, 0, float(lane["z"]))
	# Kenney cars face -Z, so turn them to face their driving direction.
	car.rotation.y = -PI * 0.5 * dir
