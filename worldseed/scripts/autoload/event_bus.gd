extends Node

# Plants
signal seed_planted(plot: Node3D, plant_type: String)
signal water_applied(plot: Node3D, amount: float)
signal pollination_window_opened(plot: Node3D)
signal plant_pollinated(plot: Node3D)
signal plant_bloomed(plot: Node3D)
signal plant_harvested(plot: Node3D, plant_type: String)

# Deliveries & resources
signal delivery_received(plant_type: String, axis: String)
signal resource_spent(plant_type: String, purpose: String)

# Bees
signal bee_assigned(bee: Node3D, role: String)
signal bee_unassigned(bee: Node3D)
signal bee_upgraded(upgrade_id: String)

# Power
signal power_changed(supply: float, demand: float)
signal brownout_started()
signal brownout_ended()

# O2 & survival
signal o2_depleted()
signal player_died()
signal autosave_triggered()
signal safe_zone_entered()
signal safe_zone_exited()

# Building
signal ghost_placed(ghost: Node3D, blueprint_id: String)
signal ghost_funded(ghost: Node3D)
signal ghost_assembled(ghost: Node3D)

# Milestones & progression
signal milestone_reached(milestone_id: String)
signal plant_unlocked(plant_type: String)
signal game_won()

# Tick
signal tick_fired(tick_number: int)
