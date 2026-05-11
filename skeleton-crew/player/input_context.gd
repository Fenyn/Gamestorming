class_name InputContext
extends RefCounted

enum Mode {
	PLAYER,   # Walking the ship: WASD move, E interact, mouse look
	HELM,     # Piloting: mouse yaw/pitch, W/S throttle, A/D strafe, Space/Ctrl vertical
	TURRET,   # Turret aiming: mouse aim, LMB fire
	TERMINAL, # Breaker board / console UI: mouse interacts with 3D UI
	DISABLED, # No input (cutscene, downed, etc.)
}

# WASD + mouse are shared across PLAYER and HELM contexts.
# In PLAYER: WASD = walk, mouse = look.
# In HELM: W/S = throttle fwd/rev, A/D = strafe L/R, mouse = yaw/pitch.
# No separate strafe actions needed — move_left/move_right serve both roles.
# Space/Ctrl = vertical thrust (HELM only, could be jump/crouch for PLAYER later).

const PLAYER_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"interact",
	&"toggle_mag_boots", &"check_wrist", &"toggle_debug",
]

const HELM_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back",  # throttle fwd/rev
	&"move_left", &"move_right",    # strafe L/R (mouse handles yaw)
	&"thrust_up", &"thrust_down",   # vertical thrust (Space/Ctrl)
	&"roll_left", &"roll_right",    # roll (Q/E)
	&"afterburner", &"toggle_flight_assist",
	&"exit_station", &"toggle_debug",
]

const TURRET_ACTIONS: Array[StringName] = [
	&"fire",
	&"exit_station", &"toggle_debug",
]

const TERMINAL_ACTIONS: Array[StringName] = [
	&"exit_station", &"toggle_debug",
]
