extends Node

# --- Combat Actions ---
signal attack_started(attacker: Node, attack_data: Resource)
signal attack_landed(attacker: Node, defender: Node, attack_data: Resource)
signal attack_blocked(attacker: Node, defender: Node, attack_data: Resource)
signal attack_deflected(attacker: Node, defender: Node, attack_data: Resource)
signal attack_missed(attacker: Node)
signal attack_feinted(attacker: Node)

# --- Shove ---
signal shove_landed(attacker: Node, defender: Node, vs_block: bool)
signal shove_countered(attacker: Node, defender: Node)

# --- Posture ---
signal posture_broken(fighter: Node)
signal deathblow_executed(attacker: Node, defender: Node, damage: int)

# --- Perilous ---
signal perilous_warning(attacker: Node, indicator_color: Color)
signal perilous_countered(attacker: Node, defender: Node, counter_type: StringName)

# --- Stance ---
signal stance_changed(fighter: Node, new_direction: int)

# --- Resources ---
signal hp_changed(fighter: Node, current: int, max_val: int)
signal posture_changed(fighter: Node, current: int, max_val: int)
signal stamina_changed(fighter: Node, current: float, max_val: float)
signal exhaustion_changed(fighter: Node, is_exhausted: bool)

# --- Fighter Lifecycle ---
signal fighter_died(fighter: Node)
signal fighter_spawned(fighter: Node)

# --- Match ---
signal match_started(mode: int)
signal match_ended(winner: Node)
signal round_reset()

# --- Lock-On ---
signal lock_on_changed(fighter: Node, target: Node)
