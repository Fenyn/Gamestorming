extends Node

# Connection
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal game_started()

# Turn flow
signal turn_started(player_index: int)
signal phase_changed(phase: int)
signal turn_ended(player_index: int)

# Actions
signal card_drawn(player_index: int, card: CardData)
signal unit_summoned(player_index: int, unit_data: UnitData, lane: int)
signal building_placed(player_index: int, building_data: BuildingData, grid_pos: Vector2i)
signal spell_cast(player_index: int, spell_data: SpellData, target_info: int)
signal unit_moved(player_index: int, from_lane: int, to_lane: int)

# Combat
signal unit_attacked(lane: int, attacker_player: int)
signal unit_damaged(lane: int, owner_player: int, damage: int)
signal unit_destroyed(lane: int, owner_player: int, unit_data: UnitData)
signal building_damaged(grid_pos: Vector2i, owner_player: int, damage: int)
signal building_destroyed(grid_pos: Vector2i, owner_player: int)
signal hq_damaged(owner_player: int, damage: int, remaining_hp: int)
signal combat_resolved()
signal unit_selected_for_move(player_index: int, lane: int)

# Spells
signal spell_advanced(player_index: int, track_pos: int)
signal spell_resolved(player_index: int, spell_data: SpellData)

# Resources
signal resources_changed(player_index: int, new_amount: int)

# UI interaction
signal card_selected(card_index: int)
signal card_deselected()
signal spell_pool_selected(spell_id: String)
signal spell_pool_deselected()
signal slot_clicked(slot_type: String, position: Variant)
signal valid_slots_highlighted(slots: Array)
signal slots_unhighlighted()

# Game end
signal game_won(winner_index: int)
signal game_draw()
signal cheat_detected(offender_index: int)
