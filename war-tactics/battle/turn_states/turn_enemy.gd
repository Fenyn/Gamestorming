class_name TurnEnemy
extends State

signal enemy_turn_started
signal enemy_turn_finished

var _battle: BattleScene = null


func enter(msg: Dictionary = {}) -> void:
	_battle = msg.get("battle", null) as BattleScene
	enemy_turn_started.emit()
	if _battle:
		_run_enemy_turn()
	else:
		enemy_turn_finished.emit()


func _run_enemy_turn() -> void:
	var enemies: Array[Unit] = _battle.get_living_enemies()
	for enemy: Unit in enemies:
		if not enemy.is_alive():
			continue
		enemy.refresh_ap()
		var brain: AIBrain = enemy.get_node_or_null("AIBrain") as AIBrain
		if brain == null:
			continue
		var actions: Array[Dictionary] = brain.decide(enemy, _battle.get_living_players(), _battle.get_unit_at_tile())
		for action: Dictionary in actions:
			if not enemy.is_alive():
				break
			if not is_instance_valid(_battle):
				return
			var action_type: int = action.get("type", -1) as int
			match action_type:
				AIBrain.ActionType.MOVE:
					var target_tile: Vector2i = action["target_tile"] as Vector2i
					await _battle.execute_ai_move(enemy, target_tile)
				AIBrain.ActionType.ATTACK:
					var target: Unit = action["target"] as Unit
					if target.is_alive():
						await _battle.execute_ai_attack(enemy, target)
		await get_tree().create_timer(0.3).timeout
	enemy_turn_finished.emit()
