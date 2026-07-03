class_name CrewTransitState3D
extends BaseState
## NPC walks toward a room exit, then signals ready for reparenting.
## After reparenting, walks away from the entrance into the new room.

signal arrived_at_exit(crew_id: String)

enum Phase { WALKING_TO_EXIT, WAITING_REPARENT, ENTERING_ROOM }

const EXIT_ARRIVE_THRESHOLD: float = 0.8
const ENTER_WALK_DISTANCE: float = 2.0

var _phase: int = Phase.WALKING_TO_EXIT
var _exit_position: Vector3 = Vector3.ZERO
var _enter_target: Vector3 = Vector3.ZERO
var _target_room_id: String = ""


func enter(msg: Dictionary = {}) -> void:
	var crew: CrewMember3D = owner as CrewMember3D
	_target_room_id = msg.get("target_room", "") as String
	var exit_direction: String = msg.get("exit_direction", "") as String
	crew.collision_mask = 0

	var room: BaseRoom3D = crew.get_parent() as BaseRoom3D
	if room == null:
		state_machine.transition_to(&"Idle")
		return

	if exit_direction != "" and room.has_entrance(exit_direction):
		_exit_position = room.get_entrance_position(exit_direction)
	else:
		_exit_position = _find_nearest_exit(crew, room)

	if _exit_position == Vector3.ZERO:
		_phase = Phase.WAITING_REPARENT
		arrived_at_exit.emit(crew.crew_id)
		return

	_phase = Phase.WALKING_TO_EXIT
	crew.nav_agent.target_position = _exit_position


func physics_update(delta: float) -> void:
	var crew: CrewMember3D = owner as CrewMember3D

	match _phase:
		Phase.WALKING_TO_EXIT:
			if crew.nav_agent.is_navigation_finished() or crew.global_position.distance_to(_exit_position) < EXIT_ARRIVE_THRESHOLD:
				crew.visible = false
				_phase = Phase.WAITING_REPARENT
				arrived_at_exit.emit(crew.crew_id)
				return
			var next_pos: Vector3 = crew.nav_agent.get_next_path_position()
			var dir: Vector3 = crew.global_position.direction_to(next_pos)
			dir.y = 0.0
			crew.global_position += dir.normalized() * CrewMember3D.SPEED * delta

		Phase.ENTERING_ROOM:
			var dist: float = crew.global_position.distance_to(_enter_target)
			if dist < 0.3:
				crew.collision_mask = 1
				state_machine.transition_to(&"Idle")
				return
			var dir: Vector3 = crew.global_position.direction_to(_enter_target)
			dir.y = 0.0
			crew.global_position += dir.normalized() * CrewMember3D.SPEED * delta


func begin_enter(entrance_pos: Vector3) -> void:
	var crew: CrewMember3D = owner as CrewMember3D
	crew.visible = true
	_phase = Phase.ENTERING_ROOM
	var inward: Vector3 = Vector3.ZERO
	var room: BaseRoom3D = crew.get_parent() as BaseRoom3D
	if room:
		inward = (room.global_position - entrance_pos).normalized()
		inward.y = 0.0
	_enter_target = entrance_pos + inward * ENTER_WALK_DISTANCE


func exit() -> void:
	var crew: CrewMember3D = owner as CrewMember3D
	crew.visible = true
	crew.collision_mask = 1
	crew.velocity = Vector3.ZERO


func _find_nearest_exit(crew: CrewMember3D, room: BaseRoom3D) -> Vector3:
	var best_pos: Vector3 = Vector3.ZERO
	var best_dist: float = INF
	for dir_name: String in ["north", "south", "east", "west"]:
		if not room.has_entrance(dir_name):
			continue
		var pos: Vector3 = room.get_entrance_position(dir_name)
		var dist: float = crew.global_position.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best_pos = pos
	return best_pos
