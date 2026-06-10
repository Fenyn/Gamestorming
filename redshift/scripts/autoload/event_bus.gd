extends Node

signal race_countdown_tick(seconds_left: int)
signal race_started()
signal race_finished(final_time: float, is_new_best: bool)

signal checkpoint_hit(index: int, total: int, split_time: float)

signal race_time_updated(time: float)
signal speed_changed(speed: float)
signal angular_velocity_changed(angular_vel: Vector3)
signal rotation_dampening_changed(enabled: bool)
signal translation_dampening_changed(enabled: bool)
signal afterburner_changed(fuel: float, max_fuel: float, is_burning: bool)
signal input_state_changed(thrust: Vector3, look: Vector2, roll: float)

signal racing_line_toggled(visible: bool)
