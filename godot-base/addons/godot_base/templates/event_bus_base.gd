## Event Bus Template
##
## Copy this file to your project's scripts/autoload/ directory and rename it
## to event_bus.gd. Register it as an autoload named "EventBus" in project.godot.
##
## Add your game-specific signals below. Keep this file as a pure signal hub —
## no state, no logic, just signal declarations with typed parameters.
##
## Usage from any script:
##   EventBus.my_signal.emit(arg1, arg2)
##   EventBus.my_signal.connect(_on_my_signal)

extends Node


# --- Screen / Scene Flow ---
# signal screen_transition_requested(target: String)
# signal scene_loaded(scene_name: String)

# --- Game State ---
# signal game_started()
# signal game_over(won: bool)
# signal game_paused(is_paused: bool)

# --- Player ---
# signal player_spawned(player: Node)
# signal player_died(player_id: int)
# signal player_hp_changed(current: int, max_val: int)

# --- Economy ---
# signal money_changed(new_amount: float)
# signal item_purchased(item_id: String)

# --- UI ---
# signal interact_hint_changed(text: String)
# signal notification_requested(message: String)
