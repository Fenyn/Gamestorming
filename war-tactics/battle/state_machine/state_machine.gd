class_name StateMachine
extends Node

signal state_changed(new_state_name: StringName)

@export var initial_state: State = null

var current_state: State = null


func _ready() -> void:
	for child: Node in get_children():
		if child is State:
			child.state_machine = self


func start() -> void:
	if initial_state == null and get_child_count() > 0:
		initial_state = get_child(0) as State
	if initial_state:
		current_state = initial_state
		current_state.enter()


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func transition_to(target_name: StringName, msg: Dictionary = {}) -> void:
	var target: State = get_node_or_null(NodePath(target_name)) as State
	if target == null:
		push_warning("StateMachine: state '%s' not found" % target_name)
		return
	if current_state:
		current_state.exit()
	current_state = target
	current_state.enter(msg)
	state_changed.emit(target_name)
