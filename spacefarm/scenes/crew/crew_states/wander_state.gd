class_name CrewWanderState
extends BaseState

const STUCK_THRESHOLD: float = 2.0
const PHASE_DURATION: float = 1.5
const MIN_MOVE_DISTANCE: float = 1.0

var _last_position: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
var _phase_timer: float = 0.0
var _is_phasing: bool = false


func enter(_msg: Dictionary = {}) -> void:
	var crew: CrewMember = owner as CrewMember
	_last_position = crew.global_position
	_stuck_timer = 0.0
	_phase_timer = 0.0
	_is_phasing = false
	crew.collision_mask = 1
	var offset: Vector2 = Vector2(
		randf_range(-CrewMember.WANDER_RADIUS, CrewMember.WANDER_RADIUS),
		randf_range(-CrewMember.WANDER_RADIUS, CrewMember.WANDER_RADIUS)
	)
	crew.nav_agent.target_position = crew.home_position + offset


func physics_update(delta: float) -> void:
	var crew: CrewMember = owner as CrewMember
	if crew.nav_agent.is_navigation_finished():
		_end_phase(crew)
		state_machine.transition_to(&"Idle")
		return

	var next_pos: Vector2 = crew.nav_agent.get_next_path_position()
	var dir: Vector2 = crew.global_position.direction_to(next_pos)

	if _is_phasing:
		crew.global_position += dir * CrewMember.SPEED * delta
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_end_phase(crew)
	else:
		crew.velocity = dir * CrewMember.SPEED
		crew.move_and_slide()
		var moved: float = crew.global_position.distance_to(_last_position)
		if moved < MIN_MOVE_DISTANCE:
			_stuck_timer += delta
			if _stuck_timer >= STUCK_THRESHOLD:
				_begin_phase(crew)
		else:
			_stuck_timer = 0.0
	_last_position = crew.global_position


func exit() -> void:
	var crew: CrewMember = owner as CrewMember
	crew.velocity = Vector2.ZERO
	_end_phase(crew)


func _begin_phase(crew: CrewMember) -> void:
	_is_phasing = true
	_phase_timer = PHASE_DURATION
	crew.collision_mask = 0


func _end_phase(crew: CrewMember) -> void:
	_is_phasing = false
	_stuck_timer = 0.0
	crew.collision_mask = 1
