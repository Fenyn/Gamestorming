class_name BaseStateMachine
extends Node

signal state_changed(old_state_name: StringName, new_state_name: StringName)

@export var initial_state: BaseState = null

var current_state: BaseState = null


func _ready() -> void:
	for child: Node in get_children():
		if child is BaseState:
			child.state_machine = self


func start() -> void:
	if initial_state == null and get_child_count() > 0:
		initial_state = get_child(0) as BaseState
	if initial_state:
		current_state = initial_state
		current_state.enter()


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func transition_to(target_name: StringName, msg: Dictionary = {}) -> void:
	var target: BaseState = get_node_or_null(NodePath(target_name)) as BaseState
	if target == null:
		push_warning("BaseStateMachine: state '%s' not found" % target_name)
		return
	var old_name: StringName = current_state.name if current_state else &""
	if current_state:
		current_state.exit()
	current_state = target
	current_state.enter(msg)
	state_changed.emit(old_name, target_name)


func get_current_state_name() -> StringName:
	if current_state:
		return current_state.name
	return &""
