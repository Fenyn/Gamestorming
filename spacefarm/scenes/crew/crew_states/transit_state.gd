class_name CrewTransitState
extends BaseState
## NPC walks toward a room exit, then signals ready for reparenting.
## After reparenting, walks away from the entrance into the new room.

signal arrived_at_exit(crew_id: String)

enum Phase { WALKING_TO_EXIT, WAITING_REPARENT, ENTERING_ROOM }

const EXIT_ARRIVE_THRESHOLD: float = 24.0
const ENTER_WALK_DISTANCE: float = 60.0

var _phase: int = Phase.WALKING_TO_EXIT
var _exit_position: Vector2 = Vector2.ZERO
var _enter_target: Vector2 = Vector2.ZERO
var _target_room_id: String = ""


func enter(msg: Dictionary = {}) -> void:
	var crew: CrewMember = owner as CrewMember
	_target_room_id = msg.get("target_room", "") as String
	var exit_direction: String = msg.get("exit_direction", "") as String
	crew.collision_mask = 0

	var room: BaseRoom = crew.get_parent() as BaseRoom
	if room == null:
		state_machine.transition_to(&"Idle")
		return

	if exit_direction != "" and room.has_entrance(exit_direction):
		_exit_position = room.get_entrance_position(exit_direction)
	else:
		_exit_position = _find_nearest_exit(crew, room)

	if _exit_position == Vector2.ZERO:
		_phase = Phase.WAITING_REPARENT
		arrived_at_exit.emit(crew.crew_id)
		return

	_phase = Phase.WALKING_TO_EXIT
	crew.nav_agent.target_position = _exit_position


func physics_update(delta: float) -> void:
	var crew: CrewMember = owner as CrewMember

	match _phase:
		Phase.WALKING_TO_EXIT:
			if crew.nav_agent.is_navigation_finished() or crew.global_position.distance_to(_exit_position) < EXIT_ARRIVE_THRESHOLD:
				crew.visible = false
				_phase = Phase.WAITING_REPARENT
				arrived_at_exit.emit(crew.crew_id)
				return
			var next_pos: Vector2 = crew.nav_agent.get_next_path_position()
			var dir: Vector2 = crew.global_position.direction_to(next_pos)
			crew.global_position += dir * CrewMember.SPEED * delta

		Phase.ENTERING_ROOM:
			var dist: float = crew.global_position.distance_to(_enter_target)
			if dist < 8.0:
				crew.collision_mask = 1
				state_machine.transition_to(&"Idle")
				return
			var dir: Vector2 = crew.global_position.direction_to(_enter_target)
			crew.global_position += dir * CrewMember.SPEED * delta


func begin_enter(entrance_pos: Vector2) -> void:
	var crew: CrewMember = owner as CrewMember
	crew.visible = true
	_phase = Phase.ENTERING_ROOM
	var inward: Vector2 = Vector2.ZERO
	var room: BaseRoom = crew.get_parent() as BaseRoom
	if room:
		inward = (room.global_position - entrance_pos).normalized()
	_enter_target = entrance_pos + inward * ENTER_WALK_DISTANCE


func exit() -> void:
	var crew: CrewMember = owner as CrewMember
	crew.visible = true
	crew.collision_mask = 1
	crew.velocity = Vector2.ZERO


func _find_nearest_exit(crew: CrewMember, room: BaseRoom) -> Vector2:
	var best_pos: Vector2 = Vector2.ZERO
	var best_dist: float = INF
	for dir_name: String in ["north", "south", "east", "west"]:
		if not room.has_entrance(dir_name):
			continue
		var pos: Vector2 = room.get_entrance_position(dir_name)
		var dist: float = crew.global_position.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best_pos = pos
	return best_pos
