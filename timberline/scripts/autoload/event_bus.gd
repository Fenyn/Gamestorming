## Timberline event bus — pure signal hub, no state, no logic.
##
## Usage from any script:
##   EventBus.tree_felled.emit(tree)
##   EventBus.money_changed.connect(_on_money_changed)

extends Node


# --- Forestry ---
signal tree_felled(tree: Node3D)
signal tree_delimbed(trunk: Node3D)
signal log_bucked(trunk: Node3D, log_count: int)

# --- Processing ---
signal item_processed(station_id: String, product_id: String, count: int)

# --- Economy ---
signal item_sold(product_id: String, value: int)
signal money_changed(new_amount: int)
signal upgrade_purchased(upgrade_id: String)

# --- UI ---
signal interact_hint_changed(text: String)
signal notification_requested(message: String)
