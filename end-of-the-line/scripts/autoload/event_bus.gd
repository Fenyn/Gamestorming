extends Node

# Economy
signal gold_changed(new_amount: float)
signal tickets_changed(new_amount: int)

# Network
signal network_reset()
signal node_connected(node_id: String)
signal track_segment_built(from_pos: Vector3, to_pos: Vector3)

# Trains
signal train_departed(train_id: int, from_node: String, to_node: String)
signal train_arrived(train_id: int, node_id: String)
signal delivery_completed(gold_earned: float)

# Builders
signal builder_started(builder_id: int, target_node: String)
signal builder_finished(builder_id: int, node_id: String)

# Loop
signal day_changed(day: int)
signal loop_ending()
signal loop_reset(tickets_earned: int)

# UI
signal notification(message: String)
signal purchase_failed(reason: String)
