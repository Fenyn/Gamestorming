class_name TurnEnemy
extends State

signal enemy_turn_started
signal enemy_turn_finished


func enter(_msg: Dictionary = {}) -> void:
	enemy_turn_started.emit()
	_run_enemy_turn()


func _run_enemy_turn() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(0.5)
	await timer.timeout
	enemy_turn_finished.emit()
