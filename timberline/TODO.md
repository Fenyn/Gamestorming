# Timberline TODO

Rough order. One line each, expand when a feature starts.

- [x] First-person player controller (scenes/player/player.tscn, scripts/player/player.gd; replaces PlaceholderCamera in main.tscn)
- [x] Axe view-model + chop interaction (scripts/player/axe.gd; swing calls receive_chop on hit colliders, felling implements it next)
- [x] Tree felling (Health child on tree.tscn, receive_chop on ConiferTree, FelledTree RigidBody tips away from chopper, emits `tree_felled`; kinematic tip then physics crash; limbs are per-part meshes that bend on landing or snap off via FelledTree.detach_limb, which delimbing reuses; leaves a stump; Fx particle bursts for chops, crack, landing)
- [x] Delimbing felled trees (FelledTree.receive_chop knocks the nearest limb off within reach; last limb emits `tree_delimbed`; debris limbs persist as props)
- [x] Bucking (delimbed FelledTree converts to TrunkPiece; chops build cut progress at the aim point, notch ring marks the cut, 3 damage splits it; pieces <= 1.5m are logs in the "carryable" group; `log_bucked` per split; axe damage scales cut speed for future upgrades)
- [x] Carry system (scripts/player/carry_system.gd; E picks up / drops "carryable" bodies, right-click tosses with fixed momentum; physics hold in front of the camera so heavy pieces lag; carried_mass on Player scales walk speed and jump toward carry_speed_floor at max_carry_mass 90 kg, heavier pieces refuse pickup; axe stows while hauling; HUD interact hint via `interact_hint_changed`; pieces between max_carry_mass and max_drag_mass 350 kg are ground-dragged by the aimed end at half encumbrance, heavier won't budge)
- [ ] Splitting station (chopping block: logs -> firewood)
- [x] Roadside sell bin logic (scripts/stations/sell_bin.gd on sell_bin.tscn; SellZone Area3D sells wood bodies by mass after 0.7s — logs/timber $0.5/kg, branches $0.3/kg, foliage worthless, carried items wait for release; floating +$ popup, `item_sold` -> GameManager money, HUD money panel + green pulse via `money_changed`)
- [ ] Cabin + upgrade catalog (`upgrade_purchased`: better axes, saws, automation steps)
- [ ] Forest plot system (regrowth, plot expansion; TreeScatter already provides the static test forest)
